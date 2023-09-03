local bit = require("bit")
local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("webgpu")
local uv = require("uv")
local validation = require("validation")

local GPU = require("Core.NativeClient.WebGPU.GPU")
local Buffer = require("Core.NativeClient.WebGPU.Buffer")
local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")

local _ = require("Core.VectorMath.Matrix4D") -- Only needed for the cdefs right now
local Vector3D = require("Core.VectorMath.Vector3D")
local C_Camera = require("Core.NativeClient.C_Camera")

local assert = assert
local ipairs = ipairs

local ffi_new = ffi.new

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
	clearColorRGBA = { 0.05, 0.05, 0.05, 1.0 },
	renderPipelines = {},
	sceneObjects = {},
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
	self.wgpuSurface = glfw.bindings.glfw_get_wgpu_surface(instance, nativeWindowHandle)
	self.viewportWidth, self.viewportHeight = self:GetViewportSize(nativeWindowHandle)

	-- In order to support window resizing, we'll need to re-create this on the fly (later)
	self:CreateSwapchain()
end

function Renderer:CreateSwapchain()
	local swapChainDescriptor = ffi.new("WGPUSwapChainDescriptor")

	-- The underlying framebuffer may be different if DPI scaling is applied, but let's ignore that for now
	swapChainDescriptor.width = self.viewportWidth
	swapChainDescriptor.height = self.viewportHeight

	local textureFormat = webgpu.bindings.wgpu_surface_get_preferred_format(self.wgpuSurface, self.wgpuAdapter)
	self.swapChainTextureFormatID = tonumber(textureFormat)

	printf("Creating swap chain with preferred texture format: %d", self.swapChainTextureFormatID)
	assert(textureFormat == ffi.C.WGPUTextureFormat_BGRA8UnormSrgb, "Only sRGB texture formats are currently supported")

	swapChainDescriptor.format = textureFormat
	swapChainDescriptor.usage = ffi.C.WGPUTextureUsage_RenderAttachment
	swapChainDescriptor.presentMode = ffi.C.WGPUPresentMode_Fifo

	self.wgpuSwapchain =
		webgpu.bindings.wgpu_device_create_swapchain(self.wgpuDevice, self.wgpuSurface, swapChainDescriptor)
	self.wgpuSwapchainDescriptor = swapChainDescriptor
end

function Renderer:CreatePipelineConfigurations()
	-- This is just a placeholder; eventually there should be real pipelines here
	local pipeline = BasicTriangleDrawingPipeline(self.wgpuDevice, self.swapChainTextureFormatID)
	self.renderPipelines[pipeline] = BasicTriangleDrawingPipeline
end

function Renderer:RenderNextFrame()
	local nextTextureView = webgpu.bindings.wgpu_swapchain_get_current_texture_view(self.wgpuSwapchain)

	-- Since resizing isn't yet supported, fail loudly if somehow that is actually done (i.e., not prevented by GLFW)
	assert(nextTextureView, "Cannot acquire next swap chain texture (window surface has changed?)")

	local commandEncoderDescriptor = ffi_new("WGPUCommandEncoderDescriptor")
	local commandEncoder = webgpu.bindings.wgpu_device_create_command_encoder(self.wgpuDevice, commandEncoderDescriptor)

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

	local renderPass = webgpu.bindings.wgpu_command_encoder_begin_render_pass(commandEncoder, renderPassDescriptor)

	self:UpdateUniformBuffer()

	for wgpuRenderPipeline, pipelineConfiguration in pairs(self.renderPipelines) do
		webgpu.bindings.wgpu_render_pass_encoder_set_pipeline(renderPass, wgpuRenderPipeline)

		for _, bufferInfo in ipairs(self.sceneObjects) do
			webgpu.bindings.wgpu_render_pass_encoder_set_vertex_buffer(
				renderPass,
				0,
				bufferInfo.vertexPositionsBuffer,
				0,
				bufferInfo.vertexPositionsBufferSize
			)
			webgpu.bindings.wgpu_render_pass_encoder_set_vertex_buffer(
				renderPass,
				1,
				bufferInfo.vertexColorsBuffer,
				0,
				bufferInfo.vertexColorsBufferSize
			)
			webgpu.bindings.wgpu_render_pass_encoder_set_index_buffer(
				renderPass,
				bufferInfo.triangleIndicesBuffer,
				ffi.C.WGPUIndexFormat_Uint16,
				0,
				bufferInfo.triangleIndexBufferSize
			)

			-- TBD Only update the fields that have actually changed (i.e., time but not color)?
			local currentTime = uv.hrtime() / 10E9
			self.perSceneUniformData.time = currentTime
			webgpu.bindings.wgpu_queue_write_buffer(
				webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice),
				self.uniformBuffer,
				0,
				self.perSceneUniformData,
				ffi.sizeof(self.perSceneUniformData)
			)

			-- webgpu.bindings.wgpu_queue_write_buffer(webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice), self.uniformBuffer, 0, globalClockSeconds, ffi.sizeof("float"))
			webgpu.bindings.wgpu_render_pass_encoder_set_bind_group(renderPass, 0, self.bindGroup, 0, nil)

			local instanceCount = 1
			local firstVertexIndex = 0
			local firstInstanceIndex = 0
			local indexBufferOffset = 0
			webgpu.bindings.wgpu_render_pass_encoder_draw_indexed(
				renderPass,
				bufferInfo.triangleIndicesCount,
				instanceCount,
				firstVertexIndex,
				firstInstanceIndex,
				indexBufferOffset
			)
		end
	end

	webgpu.bindings.wgpu_render_pass_encoder_end(renderPass)

	local commandBufferDescriptor = ffi_new("WGPUCommandBufferDescriptor")
	local commandBuffer = webgpu.bindings.wgpu_command_encoder_finish(commandEncoder, commandBufferDescriptor)

	local queue = webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice)

	-- The WebGPU API expects an array here, but currently this renderer only supports a single buffer (to keep things simple)
	local commandBuffers = ffi_new("WGPUCommandBuffer[1]", commandBuffer)
	webgpu.bindings.wgpu_queue_submit(queue, 1, commandBuffers)

	webgpu.bindings.wgpu_swapchain_present(self.wgpuSwapchain)
end

-- local binary_and = bit.band
-- local binary_negation = bit.bnot

function Renderer:UploadGeometry(vertexArray, triangleIndices, colorsRGB)
	local nanosecondsBeforeUpload = uv.hrtime()

	local vertexPositionsBufferSize = Buffer.GetAlignedSize(#vertexArray * ffi.sizeof("float"))
	local vertexCount = #vertexArray / 3 -- sizeof(Vector3D)
	local numVertexColorValues = #colorsRGB / 3

	assert(vertexCount == numVertexColorValues, "Cannot upload geometry with missing or incomplete vertex colors")

	local bufferDescriptor = ffi.new("WGPUBufferDescriptor")
	bufferDescriptor.size = vertexPositionsBufferSize
	bufferDescriptor.usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Vertex)
	bufferDescriptor.mappedAtCreation = false

	local vertexPositionsBuffer = webgpu.bindings.wgpu_device_create_buffer(self.wgpuDevice, bufferDescriptor)
	printf(
		"Uploading geometry: %d vertex positions (total buffer size: %s)",
		vertexCount,
		string.filesize(vertexPositionsBufferSize)
	)
	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice),
		vertexPositionsBuffer,
		0,
		ffi.new("float[?]", vertexPositionsBufferSize, vertexArray),
		vertexPositionsBufferSize
	)

	local vertexColorsBufferSize = Buffer.GetAlignedSize(#colorsRGB * ffi.sizeof("float")) -- sizeof (ColorRGB)
	bufferDescriptor.size = vertexColorsBufferSize
	local vertexColorsBuffer = webgpu.bindings.wgpu_device_create_buffer(self.wgpuDevice, bufferDescriptor)
	printf(
		"Uploading geometry: %d vertex colors (total buffer size: %s)",
		numVertexColorValues,
		string.filesize(vertexColorsBufferSize)
	)
	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice),
		vertexColorsBuffer,
		0,
		ffi.new("float[?]", vertexColorsBufferSize, colorsRGB),
		vertexColorsBufferSize
	)

	-- TODO A writeBuffer operation must copy a number of bytes that is a multiple of 4. To ensure so we can switch bufferDesc.size for (bufferDesc.size + 3) & ~4.
	bufferDescriptor.usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Index)
	local triangleIndicesBuffer = webgpu.bindings.wgpu_device_create_buffer(self.wgpuDevice, bufferDescriptor)
	local triangleIndicesCount = #triangleIndices
	local triangleIndexBufferSize = Buffer.GetAlignedSize(#triangleIndices * ffi.sizeof("uint16_t"))
	bufferDescriptor.size = triangleIndexBufferSize
	printf(
		"Uploading geometry: %d triangle indices (total buffer size: %s)",
		triangleIndicesCount,
		string.filesize(triangleIndexBufferSize)
	)
	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice),
		triangleIndicesBuffer,
		0,
		ffi.new("uint16_t[?]", triangleIndexBufferSize, triangleIndices),
		triangleIndexBufferSize
	)

	table.insert(self.sceneObjects, {
		vertexPositionsBuffer = vertexPositionsBuffer,
		vertexPositionsBufferSize = vertexPositionsBufferSize,
		vertexCount = vertexCount, -- Obsolete if using draw_indexed?
		vertexColorsBuffer = vertexColorsBuffer,
		vertexColorsBufferSize = vertexColorsBufferSize,
		triangleIndicesBuffer = triangleIndicesBuffer,
		triangleIndexBufferSize = triangleIndexBufferSize,
		triangleIndicesCount = triangleIndicesCount,
	})

	local nanosecondsAfterUpload = uv.hrtime()
	local uploadTimeInMilliseconds = (nanosecondsAfterUpload - nanosecondsBeforeUpload) / 10E5
	printf("Geometry upload took %.2f ms", uploadTimeInMilliseconds)
end

function Renderer:CreateUniformBuffer()
	local bufferDescriptor = ffi.new("WGPUBufferDescriptor")
	bufferDescriptor.size = ffi.sizeof("scenewide_uniform_t")
	bufferDescriptor.usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Uniform)
	bufferDescriptor.mappedAtCreation = false

	local uniformBuffer = webgpu.bindings.wgpu_device_create_buffer(self.wgpuDevice, bufferDescriptor)

	self.perSceneUniformData = ffi.new("scenewide_uniform_t")

	local binding = ffi.new("WGPUBindGroupEntry")

	binding.binding = 0
	binding.buffer = uniformBuffer
	binding.offset = 0
	binding.size = ffi.sizeof(self.perSceneUniformData)

	local bindGroupDesc = ffi.new("WGPUBindGroupDescriptor")
	bindGroupDesc.layout = BasicTriangleDrawingPipeline.wgpuBindGroupLayout
	bindGroupDesc.entryCount = BasicTriangleDrawingPipeline.wgpuBindGroupLayoutDescriptor.entryCount
	bindGroupDesc.entries = binding
	local bindGroup = webgpu.bindings.wgpu_device_create_bind_group(self.wgpuDevice, bindGroupDesc)
	self.bindGroup = bindGroup

	self.uniformBuffer = uniformBuffer
end

function Renderer:UpdateUniformBuffer()
	local aspectRatio = self.viewportWidth / self.viewportHeight

	local currentTime = uv.hrtime() / 10E9
	local perSceneUniformData = self.perSceneUniformData

	local cameraWorldPosition = C_Camera.GetWorldPosition()
	local targetWorldPosition = Vector3D(0, 0, 0)
	local upVectorHint = Vector3D(0, 1, 0)
	local perspective = C_Camera.GetPerspective()
	perSceneUniformData.view = C_Camera.CreateOrbitalView(cameraWorldPosition, targetWorldPosition, upVectorHint)
	perSceneUniformData.perspectiveProjection =
		C_Camera.CreatePerspectiveProjection(perspective.fov, aspectRatio, perspective.nearZ, perspective.farZ)
	perSceneUniformData.time = ffi.new("float", currentTime)
	perSceneUniformData.color = ffi.new("float[4]", { 1.0, 1.0, 1.0, 1.0 })

	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice),
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
	depthTextureDesc.size = {
		ffi.cast("unsigned int", self.viewportWidth),
		ffi.cast("unsigned int", self.viewportHeight),
		1,
	}
	depthTextureDesc.usage = ffi.C.WGPUTextureUsage_RenderAttachment
	depthTextureDesc.viewFormatCount = 1
	depthTextureDesc.viewFormats = ffi.new("WGPUTextureFormat[1]", ffi.C.WGPUTextureFormat_Depth24Plus)
	local depthTexture = webgpu.bindings.wgpu_device_create_texture(self.wgpuDevice, depthTextureDesc)

	-- Create the view of the depth texture manipulated by the rasterizer
	local depthTextureViewDesc = ffi.new("WGPUTextureViewDescriptor")
	depthTextureViewDesc.aspect = ffi.C.WGPUTextureAspect_DepthOnly
	depthTextureViewDesc.baseArrayLayer = 0
	depthTextureViewDesc.arrayLayerCount = 1
	depthTextureViewDesc.baseMipLevel = 0
	depthTextureViewDesc.mipLevelCount = 1
	depthTextureViewDesc.dimension = ffi.C.WGPUTextureViewDimension_2D
	depthTextureViewDesc.format = ffi.C.WGPUTextureFormat_Depth24Plus
	local depthTextureView = webgpu.bindings.wgpu_texture_create_view(depthTexture, depthTextureViewDesc)

	self.depthTextureView = depthTextureView
end

function Renderer:GetViewportSize(nativeWindowHandle)
	-- Should probably differentiate between window and frame buffer here for high-DPI (later)
	local contentWidthInPixels = ffi.new("int[1]")
	local contentHeightInPixels = ffi.new("int[1]")
	glfw.bindings.glfw_get_window_size(nativeWindowHandle, contentWidthInPixels, contentHeightInPixels)

	return tonumber(contentWidthInPixels[0]), tonumber(contentHeightInPixels[0])
end

return Renderer
