local etrace = require("Core.RuntimeExtensions.etrace")

local bit = require("bit")
local ffi = require("ffi")
local uv = require("uv")
local validation = require("validation")

local GPU = require("Core.NativeClient.WebGPU.GPU")
local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")

local Buffer = require("Core.NativeClient.WebGPU.Buffer")
local CommandEncoder = require("Core.NativeClient.WebGPU.CommandEncoder")
local Device = require("Core.NativeClient.WebGPU.Device")
local Queue = require("Core.NativeClient.WebGPU.Queue")
local RenderPassEncoder = require("Core.NativeClient.WebGPU.RenderPassEncoder")
local Surface = require("Core.NativeClient.WebGPU.Surface")
local Texture = require("Core.NativeClient.WebGPU.Texture")

local _ = require("Core.VectorMath.Matrix4D") -- Only needed for the cdefs right now
local Vector3D = require("Core.VectorMath.Vector3D")
local C_Camera = require("Core.NativeClient.C_Camera")

local assert = assert
local ipairs = ipairs

local ffi_new = ffi.new
local filesize = string.filesize

local Color = require("Core.NativeClient.DebugDraw.Color")

local Renderer = {
	cdefs = [[
		// Must match the struct defined in the shader
		typedef struct PerSceneData {
			Matrix4D view;
			Matrix4D perspectiveProjection;
			float color[4];
			float time;
			// Total struct size must align to 16 byte boundary
			// See https://gpuweb.github.io/gpuweb/wgsl/#address-space-layout-constraints
			float padding[3]; // Needs to be updateds whenever the struct changes!
		} scenewide_uniform_t;
	]],
	clearColorRGBA = { Color.GREY.red, Color.GREY.green, Color.GREY.blue, 0 },
	renderPipelines = {},
	meshes = {},
}

ffi.cdef(Renderer.cdefs)

assert(
	ffi.sizeof("scenewide_uniform_t") % 16 == 0,
	"Structs in uniform address space must be aligned to a 16 byte boundary (as per the WebGPU specification)"
)

function Renderer:InitializeWithGLFW(nativeWindowHandle)
	Renderer:CreateGraphicsContext(nativeWindowHandle)
	Renderer:CreatePipelineConfigurations()
	Renderer:CreateUniformBuffer()
	Renderer:EnableDepthBuffer()

	-- Default texture that is multiplicatively neutral (use with untextured geometry to keep things simple)
	Renderer:CreateDummyTexture()
	-- Untextured geometry still needs to bind a UV buffer since we only have a single pipeline (hacky...)
	Renderer:CreateDummyTextureCoordinatesBuffer()
end

function Renderer:CreateGraphicsContext(nativeWindowHandle)
	validation.validateStruct(nativeWindowHandle, "nativeWindowHandle")

	local instance, instanceDescriptor = GPU:CreateInstance()
	local adapter = GPU:RequestAdapter(instance, nativeWindowHandle)
	local device, deviceDescriptor = GPU:RequestLogicalDevice(adapter)

	-- GC anchors for cdata (must be kept alive for the entire lifetime of the app)
	self.wgpuInstance = instance
	self.wgpuInstanceDescriptor = instanceDescriptor
	self.wgpuAdapter = adapter
	self.wgpuDevice = device
	self.wgpuDeviceDescriptor = deviceDescriptor

	-- Updates to the backing window should be pushed via events, so only store the result here
	self.backingSurface = Surface(instance, adapter, device, nativeWindowHandle)
end

function Renderer:CreatePipelineConfigurations()
	-- Need to compute the preferred texture format first
	self.backingSurface:UpdateConfiguration()

	-- This is just a placeholder; eventually there should be real pipelines here
	local pipeline = BasicTriangleDrawingPipeline(self.wgpuDevice, self.backingSurface.preferredTextureFormat)
	self.renderPipelines[pipeline] = BasicTriangleDrawingPipeline
end

function Renderer:RenderNextFrame()
	etrace.clear()
	local nextTextureView = self.backingSurface:AcquireTextureView()

	local commandEncoderDescriptor = ffi_new("WGPUCommandEncoderDescriptor")
	local commandEncoder = Device:CreateCommandEncoder(self.wgpuDevice, commandEncoderDescriptor)
	local renderPass = self:BeginRenderPass(commandEncoder, nextTextureView)

	self:UpdateUniformBuffer()

	for wgpuRenderPipeline, pipelineConfiguration in pairs(self.renderPipelines) do
		RenderPassEncoder:SetPipeline(renderPass, wgpuRenderPipeline)

		for _, mesh in ipairs(self.meshes) do
			self:DrawMesh(renderPass, mesh)
		end
	end

	RenderPassEncoder:End(renderPass)
	self:SubmitCommandBuffer(commandEncoder)
	self.backingSurface:PresentNextFrame()
end

function Renderer:BeginRenderPass(commandEncoder, nextTextureView)
	local renderPassDescriptor = ffi_new("WGPURenderPassDescriptor")

	-- Clearing is a built-in mechanism of the render pass
	local renderPassColorAttachment = ffi_new("WGPURenderPassColorAttachment")
	renderPassColorAttachment.view = nextTextureView
	renderPassColorAttachment.loadOp = ffi.C.WGPULoadOp_Clear
	renderPassColorAttachment.storeOp = ffi.C.WGPUStoreOp_Store
	renderPassColorAttachment.clearValue = ffi_new("WGPUColor", self.clearColorRGBA)

	renderPassDescriptor.colorAttachmentCount = 1
	renderPassDescriptor.colorAttachments = renderPassColorAttachment

	-- Enable Z buffering in the fragment stage
	local depthStencilAttachment = ffi.new("WGPURenderPassDepthStencilAttachment")
	depthStencilAttachment.view = self.depthTextureView
	-- The initial value of the depth buffer, meaning "far"
	depthStencilAttachment.depthClearValue = 1.0
	depthStencilAttachment.depthLoadOp = ffi.C.WGPULoadOp_Clear
	depthStencilAttachment.depthStoreOp = ffi.C.WGPUStoreOp_Store -- Enable depth write (should disable for UI later?)
	depthStencilAttachment.depthReadOnly = false

	-- Stencil setup, mandatory but unused
	depthStencilAttachment.stencilClearValue = 0
	depthStencilAttachment.stencilLoadOp = ffi.C.WGPULoadOp_Clear
	depthStencilAttachment.stencilStoreOp = ffi.C.WGPUStoreOp_Store
	depthStencilAttachment.stencilReadOnly = true

	renderPassDescriptor.depthStencilAttachment = depthStencilAttachment

	return CommandEncoder:BeginRenderPass(commandEncoder, renderPassDescriptor)
end

function Renderer:DrawMesh(renderPass, mesh)
	local vertexBufferSize = #mesh.vertexPositions * ffi.sizeof("float")
	local colorBufferSize = #mesh.vertexColors * ffi.sizeof("float")
	local indexBufferSize = #mesh.triangleConnections * ffi.sizeof("uint32_t")
	local diffuseTexCoordsBufferSize = mesh.diffuseTextureCoords and (#mesh.diffuseTextureCoords * ffi.sizeof("float"))
		or GPU.MAX_VERTEX_COUNT

	RenderPassEncoder:SetVertexBuffer(renderPass, 0, mesh.vertexBuffer, 0, vertexBufferSize)
	RenderPassEncoder:SetVertexBuffer(renderPass, 1, mesh.colorBuffer, 0, colorBufferSize)
	RenderPassEncoder:SetVertexBuffer(renderPass, 2, mesh.diffuseTexCoordsBuffer, 0, diffuseTexCoordsBufferSize)
	RenderPassEncoder:SetIndexBuffer(renderPass, mesh.indexBuffer, ffi.C.WGPUIndexFormat_Uint32, 0, indexBufferSize)

	RenderPassEncoder:SetBindGroup(renderPass, 0, self.bindGroup, 0, nil)

	if not mesh.texture then
		-- The pipeline layout is kept identical (for simplicity's sake... ironic, considering how complicated this already is)
		RenderPassEncoder:SetBindGroup(renderPass, 1, self.dummyTexture.wgpuBindGroup, 0, nil)
	else
		RenderPassEncoder:SetBindGroup(renderPass, 1, mesh.texture.wgpuBindGroup, 0, nil)
	end

	local instanceCount = 1
	local firstVertexIndex = 0
	local firstInstanceIndex = 0
	local indexBufferOffset = 0
	RenderPassEncoder:DrawIndexed(
		renderPass,
		#mesh.triangleConnections,
		instanceCount,
		firstVertexIndex,
		firstInstanceIndex,
		indexBufferOffset
	)
end

function Renderer:SubmitCommandBuffer(commandEncoder)
	local commandBufferDescriptor = ffi_new("WGPUCommandBufferDescriptor")
	local commandBuffer = CommandEncoder:Finish(commandEncoder, commandBufferDescriptor)

	-- The WebGPU API expects an array here, but currently this renderer only supports a single buffer (to keep things simple)
	local queue = Device:GetQueue(self.wgpuDevice)
	local commandBuffers = ffi_new("WGPUCommandBuffer[1]", commandBuffer)
	Queue:Submit(queue, 1, commandBuffers)
end

function Renderer:UploadMeshGeometry(mesh)
	local positions = mesh.vertexPositions
	local colors = mesh.vertexColors
	local indices = mesh.triangleConnections

	local vertexCount = #positions / 3
	local triangleIndicesCount = #indices
	local numVertexColors = #colors / 3
	assert(vertexCount == numVertexColors, "Cannot upload geometry with missing or incomplete vertex colors")
	assert(triangleIndicesCount % 3 == 0, "Cannot upload geometry with incomplete triangles")

	local vertexBufferSize = #positions * ffi.sizeof("float")
	printf("Uploading geometry: %d vertex positions (%s)", vertexCount, filesize(vertexBufferSize))
	local vertexBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, positions)

	local vertexColorsBufferSize = #colors * ffi.sizeof("float")
	printf("Uploading geometry: %d vertex colors (%s)", numVertexColors, filesize(vertexColorsBufferSize))
	local vertexColorsBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, colors)

	local triangleIndexBufferSize = #indices * ffi.sizeof("uint16_t")
	printf("Uploading geometry: %d triangle indices (%s)", triangleIndicesCount, filesize(triangleIndexBufferSize))
	local triangleIndicesBuffer = Buffer:CreateIndexBuffer(self.wgpuDevice, indices)

	local diffuseTextureCoordinatesBuffer = self.dummyTexCoordsBuffer
	if mesh.diffuseTextureCoords then
		local diffuseTextureCoordsCount = #mesh.diffuseTextureCoords
		assert(
			diffuseTextureCoordsCount == vertexCount * 2,
			"Cannot upload geometry with incomplete diffuse texture coords"
		)

		local diffuseTextureCoordsBufferSize = #mesh.diffuseTextureCoords * ffi.sizeof("float")
		printf(
			"Uploading geometry: %d diffuse UVs (%s)",
			diffuseTextureCoordsCount,
			filesize(diffuseTextureCoordsBufferSize)
		)
		diffuseTextureCoordinatesBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, mesh.diffuseTextureCoords)
	end

	mesh.vertexBuffer = vertexBuffer
	mesh.colorBuffer = vertexColorsBuffer
	mesh.indexBuffer = triangleIndicesBuffer
	mesh.diffuseTexCoordsBuffer = diffuseTextureCoordinatesBuffer

	table.insert(self.meshes, mesh)
end

function Renderer:UploadTextureImage(texture)
	if not texture then
		return
	end

	texture:CopyImageBytesToGPU(texture.rgbaImageBytes)
end

function Renderer:CreateUniformBuffer()
	local bufferDescriptor = ffi.new("WGPUBufferDescriptor")
	bufferDescriptor.size = ffi.sizeof("scenewide_uniform_t")
	bufferDescriptor.usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Uniform)
	bufferDescriptor.mappedAtCreation = false

	local uniformBuffer = Device:CreateBuffer(self.wgpuDevice, bufferDescriptor)

	self.perSceneUniformData = ffi.new("scenewide_uniform_t")

	local binding = ffi.new("WGPUBindGroupEntry")

	binding.binding = 0
	binding.buffer = uniformBuffer
	binding.offset = 0
	binding.size = ffi.sizeof(self.perSceneUniformData)

	local cameraBindGroupDescriptor = ffi.new("WGPUBindGroupDescriptor")
	cameraBindGroupDescriptor.layout = BasicTriangleDrawingPipeline.wgpuCameraBindGroupLayout
	cameraBindGroupDescriptor.entryCount = BasicTriangleDrawingPipeline.wgpuCameraBindGroupLayoutDescriptor.entryCount
	cameraBindGroupDescriptor.entries = binding
	local bindGroup = Device:CreateBindGroup(self.wgpuDevice, cameraBindGroupDescriptor)
	self.bindGroup = bindGroup

	self.uniformBuffer = uniformBuffer
end

function Renderer:UpdateUniformBuffer()
	local aspectRatio = self.backingSurface:GetAspectRatio()

	local currentTime = uv.hrtime() / 10E9
	local perSceneUniformData = self.perSceneUniformData

	local cameraWorldPosition = C_Camera.GetWorldPosition()
	local cameraTarget = C_Camera.GetTargetPosition()
	local upVectorHint = Vector3D(0, 1, 0)
	local perspective = C_Camera.GetPerspective()
	perSceneUniformData.view = C_Camera.CreateOrbitalView(cameraWorldPosition, cameraTarget, upVectorHint)
	perSceneUniformData.perspectiveProjection =
		C_Camera.CreatePerspectiveProjection(perspective.fov, aspectRatio, perspective.nearZ, perspective.farZ)
	perSceneUniformData.time = ffi.new("float", currentTime)
	perSceneUniformData.color = ffi.new("float[4]", { 1.0, 1.0, 1.0, 1.0 })

	Queue:WriteBuffer(
		Device:GetQueue(self.wgpuDevice),
		self.uniformBuffer,
		0,
		perSceneUniformData,
		ffi.sizeof(perSceneUniformData)
	)
end

function Renderer:EnableDepthBuffer()
	-- Create the depth texture
	local depthTextureDesc = ffi.new("WGPUTextureDescriptor")
	depthTextureDesc.dimension = ffi.C.WGPUTextureDimension_2D
	depthTextureDesc.format = ffi.C.WGPUTextureFormat_Depth24Plus
	depthTextureDesc.mipLevelCount = 1
	depthTextureDesc.sampleCount = 1
	local viewportWidth, viewportHeight = self.backingSurface:GetViewportSize()
	depthTextureDesc.size = {
		viewportWidth,
		viewportHeight,
		1,
	}
	printf("Creating depth buffer with texture dimensions %d x %d", viewportWidth, viewportHeight)
	depthTextureDesc.usage = ffi.C.WGPUTextureUsage_RenderAttachment
	depthTextureDesc.viewFormatCount = 1
	depthTextureDesc.viewFormats = ffi.new("WGPUTextureFormat[1]", ffi.C.WGPUTextureFormat_Depth24Plus)
	local depthTexture = Device:CreateTexture(self.wgpuDevice, depthTextureDesc)

	-- Create the view of the depth texture manipulated by the rasterizer
	local depthTextureViewDesc = ffi.new("WGPUTextureViewDescriptor")
	depthTextureViewDesc.aspect = ffi.C.WGPUTextureAspect_DepthOnly
	depthTextureViewDesc.baseArrayLayer = 0
	depthTextureViewDesc.arrayLayerCount = 1
	depthTextureViewDesc.baseMipLevel = 0
	depthTextureViewDesc.mipLevelCount = 1
	depthTextureViewDesc.dimension = ffi.C.WGPUTextureViewDimension_2D
	depthTextureViewDesc.format = ffi.C.WGPUTextureFormat_Depth24Plus
	local depthTextureView = Texture:CreateTextureView(depthTexture, depthTextureViewDesc)

	self.depthTextureView = depthTextureView
end

function Renderer:CreateDebugTexture()
	local textureFilePath = path.join("Core", "NativeClient", "DebugDraw", "DebugTexture256.png")
	local pngFileContents = C_FileSystem.ReadFile(textureFilePath)
	local rgbaImageBytes = C_ImageProcessing.DecodeFileContents(pngFileContents)
	local debugTexture = Texture(self.wgpuDevice, rgbaImageBytes, 256, 256)

	return debugTexture
end

function Renderer:CreateBlankTexture()
	local rgbaImageBytes = Texture:GenerateBlankImage() -- GC anchor
	local blankTexture = Texture(self.wgpuDevice, rgbaImageBytes, 256, 256)

	return blankTexture
end

function Renderer:CreateDummyTexture()
	-- 1x1 white so the pipeline layout doesn't need to be modified (ugly hack, but it's probably the simplest approach)
	local blankTexture = Renderer:CreateBlankTexture()
	self.dummyTexture = blankTexture -- Should probably use materials here?
	Renderer:UploadTextureImage(blankTexture)
end

require("table.new")

function Renderer:CreateDummyTextureCoordinatesBuffer()
	local maxAllowedVerticesPerMesh = GPU.MAX_VERTEX_COUNT -- A bit wasteful, but it's a one-of anyway...
	local bufferSize = maxAllowedVerticesPerMesh * ffi.sizeof("float") * 2 -- One UV set per vertex
	printf("Creating default UV buffer with %d entries (%s)", maxAllowedVerticesPerMesh, string.filesize(bufferSize))

	local dummyCoords = table.new(maxAllowedVerticesPerMesh, 0)
	local buffer = Buffer:CreateVertexBuffer(self.wgpuDevice, dummyCoords)
	self.dummyTexCoordsBuffer = buffer
end

return Renderer
