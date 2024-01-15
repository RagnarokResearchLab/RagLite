local bit = require("bit")
local etrace = require("etrace")
local ffi = require("ffi")
local interop = require("interop")
local rml = require("rml")
local validation = require("validation")
local webgpu = require("webgpu")

local GPU = require("Core.NativeClient.WebGPU.GPU")
local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")
local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.WidgetDrawingPipeline")

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
local format = string.format
local filesize = string.filesize

local Color = require("Core.NativeClient.DebugDraw.Color")

local Renderer = {
	cdefs = [[
		// Total struct size must align to 16 byte boundary
		// See https://gpuweb.github.io/gpuweb/wgsl/#address-space-layout-constraints
		// Layouts must match the structs defined in the shaders
		typedef struct PerSceneData {
			Matrix4D view;
			Matrix4D perspectiveProjection;
			float color[4];
			float viewportWidth;
			float viewportHeight;
			// Padding needs to be updated whenever the struct changes!
			uint8_t padding[6];
		} scenewide_uniform_t;
		typedef struct PerMeshData {
			float translation[2]; // 8
			float padding[6]; // 32
			// Total size must be at least minUniformBufferOffsetAlignment bytes large (with 16 byte alignment)
		} mesh_uniform_t;
	]],
	clearColorRGBA = { Color.GREY.red, Color.GREY.green, Color.GREY.blue, 0 },
	renderPipelines = {},
	userInterfaceTextureBindGroups = {},
	meshes = {},
	DEBUG_DISCARDED_BACKGROUND_PIXELS = false, -- This is really slow (disk I/O); don't enable unless necessary
	numWidgetTransformsUsedThisFrame = 0,
	errorStrings = {
		INVALID_VERTEX_BUFFER = "Cannot upload geometry with invalid vertex buffer",
		INVALID_INDEX_BUFFER = "Cannot upload geometry with invalid index buffer",
		INVALID_COLOR_BUFFER = "Cannot upload geometry with invalid color buffer",
		INVALID_UV_BUFFER = "Cannot upload geometry with invalid diffuse texture coordinates buffer",
		INCOMPLETE_COLOR_BUFFER = "Cannot upload geometry with missing or incomplete vertex colors",
		INCOMPLETE_UV_BUFFER = "Cannot upload geometry with missing or incomplete diffuse texture coordinates ",
	},
}

ffi.cdef(Renderer.cdefs)

assert(
	ffi.sizeof("scenewide_uniform_t") % 16 == 0,
	"Structs in uniform address space must be aligned to a 16 byte boundary (as per the WebGPU specification)"
)
assert(
	ffi.sizeof("mesh_uniform_t") % 16 == 0,
	"Structs in uniform address space must be aligned to a 16 byte boundary (as per the WebGPU specification)"
)

function Renderer:InitializeWithGLFW(nativeWindowHandle)
	Renderer:CreateGraphicsContext(nativeWindowHandle)
	Renderer:CreatePipelineConfigurations()
	Renderer:CreateUniformBuffers()
	Renderer:EnableDepthBuffer()

	-- Default texture that is multiplicatively neutral (use with untextured geometry to keep things simple)
	Renderer:CreateDummyTexture()
	-- Untextured geometry still needs to bind a UV buffer since we only have a single pipeline (hacky...)
	Renderer:CreateDummyTextureCoordinatesBuffer()

	Renderer:CreateUserInterface()
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
	self.meshGeometryRenderingPipeline =
		BasicTriangleDrawingPipeline(self.wgpuDevice, self.backingSurface.preferredTextureFormat)
	self.userInterfaceRenderingPipeline =
		WidgetDrawingPipeline(self.wgpuDevice, self.backingSurface.preferredTextureFormat)
end

function Renderer:CreateUserInterface()
	local ROBOTO_FILE_PATH = path.join("Core", "NativeClient", "Assets", "Fonts", "Roboto-Regular.ttf")
	local RML_TEST_FILE_PATH = path.join("Tests", "Fixtures", "test.rml")

	local glfwSystemInterface = rml.bindings.rml_create_glfw_system_interface()
	self.rmlCommandQueue = interop.bindings.queue_create()
	local wgpuRenderInterface = rml.bindings.rml_create_wgpu_render_interface(self.wgpuDevice, self.rmlCommandQueue)
	rml.bindings.rml_set_system_interface(glfwSystemInterface)
	rml.bindings.rml_set_render_interface(wgpuRenderInterface)
	self.rmlRenderInterface = wgpuRenderInterface

	assert(rml.bindings.rml_initialise(), "Failed to initialise RML library context")
	assert(
		rml.bindings.rml_load_font_face(ROBOTO_FILE_PATH, true),
		"Failed to load default font face " .. ROBOTO_FILE_PATH
	)

	local viewportWidth, viewportHeight = self.backingSurface:GetViewportSize()
	local rmlContext = rml.bindings.rml_context_create("default", viewportWidth, viewportHeight)
	assert(rmlContext, "Failed to create RML library context")
	self.rmlContext = rmlContext

	local document = rml.bindings.rml_context_load_document(rmlContext, RML_TEST_FILE_PATH)
	assert(document ~= ffi.NULL, "Failed to load default RML document " .. RML_TEST_FILE_PATH)
	rml.bindings.rml_document_show(document)
end

function Renderer:RenderNextFrame()
	etrace.clear()
	local nextTextureView = self.backingSurface:AcquireTextureView()

	local commandEncoderDescriptor = ffi_new("WGPUCommandEncoderDescriptor")
	local commandEncoder = Device:CreateCommandEncoder(self.wgpuDevice, commandEncoderDescriptor)

	do
		local renderPass = self:BeginRenderPass(commandEncoder, nextTextureView)
		self:ResetScissorRectangle(renderPass)
		self:UpdateScenewideUniformBuffer()

		RenderPassEncoder:SetPipeline(renderPass, self.meshGeometryRenderingPipeline)
		for _, mesh in ipairs(self.meshes) do
			self:DrawMesh(renderPass, mesh)
		end

		RenderPassEncoder:End(renderPass)
	end

	do
		local uiRenderPass = self:BeginUserInterfaceRenderPass(commandEncoder, nextTextureView)
		RenderPassEncoder:SetPipeline(uiRenderPass, self.userInterfaceRenderingPipeline)

		self.numWidgetTransformsUsedThisFrame = 0
		rml.bindings.rml_context_update(self.rmlContext)
		-- NO MORE CHANGES here before rendering the updated state!
		rml.bindings.rml_context_render(self.rmlContext)

		self:ProcessUserInterfaceRenderCommands(uiRenderPass)

		RenderPassEncoder:End(uiRenderPass)
	end

	self:SubmitCommandBuffer(commandEncoder)
	self.backingSurface:PresentNextFrame()
end

local rmlEventNames = {
	[ffi.C.ERROR_EVENT] = "UNKNOWN_RENDER_COMMAND",
	[ffi.C.GEOMETRY_RENDER_EVENT] = "GEOMETRY_RENDER_EVENT",
	[ffi.C.GEOMETRY_COMPILE_EVENT] = "GEOMETRY_COMPILE_EVENT",
	[ffi.C.COMPILATION_RENDER_EVENT] = "COMPILATION_RENDER_EVENT",
	[ffi.C.COMPILATION_RELEASE_EVENT] = "COMPILATION_RELEASE_EVENT",
	[ffi.C.SCISSORTEST_STATUS_EVENT] = "SCISSORTEST_STATUS_EVENT",
	[ffi.C.SCISSORTEST_REGION_EVENT] = "SCISSORTEST_REGION_EVENT",
	[ffi.C.TEXTURE_LOAD_EVENT] = "TEXTURE_LOAD_EVENT",
	[ffi.C.TEXTURE_GENERATION_EVENT] = "TEXTURE_GENERATION_EVENT",
	[ffi.C.TEXTURE_RELEASE_EVENT] = "TEXTURE_RELEASE_EVENT",
	[ffi.C.TRANSFORMATION_UPDATE_EVENT] = "TRANSFORMATION_UPDATE_EVENT",
}

function Renderer:ProcessUserInterfaceRenderCommands(uiRenderPass)
	local eventCount
	repeat
		eventCount = tonumber(interop.bindings.queue_size(self.rmlCommandQueue))
		if eventCount > 0 then
			local eventInfo = interop.bindings.queue_pop_event(self.rmlCommandQueue)
			local event = ffi.cast("error_event_t*", eventInfo)
			local eventName = rmlEventNames[event.type] or rmlEventNames[ffi.C.ERROR_EVENT]
			local eventHandler = self[eventName]
			eventHandler(self, eventName, eventInfo, uiRenderPass)
		end
	until eventCount == 0
end

function Renderer:UNKNOWN_RENDER_COMMAND(eventID, payload)
	-- This should never happen: If RML updates the render interface this Renderer too needs an update
	error("UNKNOWN_RENDER_COMMAND")
end

function Renderer:GEOMETRY_RENDER_EVENT(eventID, payload)
	-- This should never happen: ALL geometry has to be compiled for the render interface to work
	error("GEOMETRY_RENDER_EVENT")
end

function Renderer:GEOMETRY_COMPILE_EVENT(eventID, payload)
	-- NOOP since all the required work is done inside the render interface (C++ layer of the runtime)
end

function Renderer:COMPILATION_RENDER_EVENT(eventID, payload, uiRenderPass)
	local geometry = payload.compilation_render_details.compiled_geometry
	local offsetU = payload.compilation_render_details.translate_u
	local offsetV = payload.compilation_render_details.translate_v
	self:DrawWidget(uiRenderPass, geometry, offsetU, offsetV)
end

function Renderer:COMPILATION_RELEASE_EVENT(eventID, payload)
	error("COMPILATION_RELEASE_EVENT") -- NYI (the memory leak doesn't matter, for now)
end

function Renderer:SCISSORTEST_STATUS_EVENT(eventID, payload, uiRenderPass)
	if payload.scissortest_status_details.enabled_flag then
		return -- There'll be another event to actually set the scissor region
	end

	self:ResetScissorRectangle(uiRenderPass)
end

function Renderer:ResetScissorRectangle(uiRenderPass)
	local viewportWidth, viewportHeight = self.backingSurface:GetViewportSize()
	webgpu.bindings.wgpu_render_pass_encoder_set_scissor_rect(uiRenderPass, 0, 0, viewportWidth, viewportHeight)
end

function Renderer:SCISSORTEST_REGION_EVENT(eventID, payload, uiRenderPass)
	local region = payload.scissortest_region_details
	-- Might want to skip this if the rectangle hasn't changed? (Needs benchmarking)
	webgpu.bindings.wgpu_render_pass_encoder_set_scissor_rect(
		uiRenderPass,
		math.max(region.u, 0),
		math.max(region.v, 0),
		region.width,
		region.height
	)
end

function Renderer:TEXTURE_LOAD_EVENT(eventID, payload)
	error("TEXTURE_LOAD_EVENT") -- NYI (CSS textures aren't currently supported, nor used)
end

function Renderer:TEXTURE_GENERATION_EVENT(eventID, payload)
	local wgpuTexture = ffi.cast("WGPUTexture", payload.texture_generation_details.texture)
	local bindGroup = Texture:CreateBindGroupForPipeline(wgpuTexture, WidgetDrawingPipeline)

	local wgpuTexturePointer = tonumber(ffi.cast("intptr_t", wgpuTexture))
	self.userInterfaceTextureBindGroups[wgpuTexturePointer] = bindGroup
end

function Renderer:TEXTURE_RELEASE_EVENT(eventID, payload)
	error("TEXTURE_RELEASE_EVENT") -- NYI (the memory leak doesn't matter, for now)
end

function Renderer:TRANSFORMATION_UPDATE_EVENT(eventID, payload)
	error("TRANSFORMATION_UPDATE_EVENT") -- NYI (CSS transforms aren't currently supported, nor used)
end

function Renderer:BeginRenderPass(commandEncoder, nextTextureView)
	-- Clearing is a built-in mechanism of the render pass
	local renderPassColorAttachment = ffi_new("WGPURenderPassColorAttachment", {
		view = nextTextureView,
		loadOp = ffi.C.WGPULoadOp_Clear,
		storeOp = ffi.C.WGPUStoreOp_Store,
		clearValue = ffi_new("WGPUColor", self.clearColorRGBA),
	})

	-- Enable Z buffering in the fragment stage
	local depthStencilAttachment = ffi.new("WGPURenderPassDepthStencilAttachment", {
		view = self.depthTextureView,
		depthClearValue = 1.0, -- The initial value of the depth buffer, meaning "far"
		depthLoadOp = ffi.C.WGPULoadOp_Clear,
		depthStoreOp = ffi.C.WGPUStoreOp_Store, -- Enable depth write (should disable for UI later?)
		depthReadOnly = false,
		-- Stencil setup; mandatory but unused
		stencilClearValue = 0,
		stencilLoadOp = ffi.C.WGPULoadOp_Clear,
		stencilStoreOp = ffi.C.WGPUStoreOp_Store,
		stencilReadOnly = true,
	})

	local renderPassDescriptor = ffi_new("WGPURenderPassDescriptor", {
		colorAttachmentCount = 1,
		colorAttachments = renderPassColorAttachment,
		depthStencilAttachment = depthStencilAttachment,
	})

	return CommandEncoder:BeginRenderPass(commandEncoder, renderPassDescriptor)
end

function Renderer:BeginUserInterfaceRenderPass(commandEncoder, nextTextureView)
	local renderPassColorAttachment = ffi_new("WGPURenderPassColorAttachment", {
		view = nextTextureView,
		loadOp = ffi.C.WGPULoadOp_Load, -- Preserve existing framebuffer content
		storeOp = ffi.C.WGPUStoreOp_Store,
		clearValue = ffi_new("WGPUColor", self.clearColorRGBA),
	})

	local renderPassDescriptor = ffi_new("WGPURenderPassDescriptor", {
		colorAttachmentCount = 1,
		colorAttachments = renderPassColorAttachment,
		-- Depth/stencil testing is omitted since it isn't needed for UI rendering
	})

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

	RenderPassEncoder:SetBindGroup(renderPass, 0, self.uniforms.perScene.bindGroup, 0, nil)

	if not mesh.diffuseTexture then
		-- The pipeline layout is kept identical (for simplicity's sake... ironic, considering how complicated this already is)
		RenderPassEncoder:SetBindGroup(renderPass, 1, self.dummyTexture.wgpuBindGroup, 0, nil)
	else
		RenderPassEncoder:SetBindGroup(renderPass, 1, mesh.diffuseTexture.wgpuBindGroup, 0, nil)
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

function Renderer:DrawWidget(renderPass, compiledWidgetGeometry, offsetU, offsetV)
	local SIZEOF_RML_VERTEX = 20
	local vertexBufferSize = compiledWidgetGeometry.num_vertices * SIZEOF_RML_VERTEX
	local indexBufferSize = compiledWidgetGeometry.num_indices * ffi.sizeof("int")

	assert(
		self.numWidgetTransformsUsedThisFrame < WidgetDrawingPipeline.MAX_WIDGET_COUNT,
		"No available slots for widget transforms in the preallocated uniform buffer"
	)

	-- UpdateObjectTransform(u, v)
	local perMeshUniformData = self.uniforms.perMesh.data
	local widgetTranslationStartOffset = ffi.sizeof("mesh_uniform_t") * self.numWidgetTransformsUsedThisFrame
	perMeshUniformData[widgetTranslationStartOffset].translation = ffi.new("float[2]", { offsetU, offsetV })
	self.numWidgetTransformsUsedThisFrame = self.numWidgetTransformsUsedThisFrame + 1

	Queue:WriteBuffer(
		Device:GetQueue(self.wgpuDevice),
		self.uniforms.perMesh.buffer,
		widgetTranslationStartOffset,
		perMeshUniformData[widgetTranslationStartOffset],
		ffi.sizeof("mesh_uniform_t")
	)

	RenderPassEncoder:SetVertexBuffer(renderPass, 0, compiledWidgetGeometry.vertex_buffer, 0, vertexBufferSize)
	RenderPassEncoder:SetIndexBuffer(
		renderPass,
		compiledWidgetGeometry.index_buffer,
		ffi.C.WGPUIndexFormat_Uint32,
		0,
		indexBufferSize
	)

	RenderPassEncoder:SetBindGroup(renderPass, 0, self.uniforms.perScene.bindGroup, 0, nil)

	if compiledWidgetGeometry.texture == ffi.NULL then
		RenderPassEncoder:SetBindGroup(renderPass, 1, self.dummyTexture.wgpuBindGroup, 0, nil)
	else
		local wgpuTexture = ffi.cast("WGPUTexture", compiledWidgetGeometry.texture)
		local wgpuTexturePointer = tonumber(ffi.cast("intptr_t", wgpuTexture))
		local textureBindGroup = self.userInterfaceTextureBindGroups[wgpuTexturePointer]
		assert(textureBindGroup, "No relevant bind group found for RML texture: " .. tostring(wgpuTexture))
		RenderPassEncoder:SetBindGroup(renderPass, 1, textureBindGroup, 0, nil)
	end

	local dynamicUniformBufferOffset = ffi.new("uint32_t[1]")
	dynamicUniformBufferOffset[0] = widgetTranslationStartOffset
	RenderPassEncoder:SetBindGroup(renderPass, 2, self.uniforms.perMesh.bindGroup, 1, dynamicUniformBufferOffset)

	local instanceCount = 1
	local firstVertexIndex = 0
	local firstInstanceIndex = 0
	local indexBufferOffset = 0
	RenderPassEncoder:DrawIndexed(
		renderPass,
		compiledWidgetGeometry.num_indices,
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
	local indexCount = #indices
	local numVertexColors = #colors / 3

	if vertexCount == 0 or indexCount == 0 then
		return
	end

	self:ValidateGeometry(mesh)

	local vertexBufferSize = #positions * ffi.sizeof("float")
	printf("Uploading geometry: %d vertex positions (%s)", vertexCount, filesize(vertexBufferSize))
	local vertexBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, positions)

	local vertexColorsBufferSize = #colors * ffi.sizeof("float")
	printf("Uploading geometry: %d vertex colors (%s)", numVertexColors, filesize(vertexColorsBufferSize))
	local vertexColorsBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, colors)

	local triangleIndexBufferSize = #indices * ffi.sizeof("uint16_t")
	printf("Uploading geometry: %d triangle indices (%s)", indexCount, filesize(triangleIndexBufferSize))
	local triangleIndicesBuffer = Buffer:CreateIndexBuffer(self.wgpuDevice, indices)

	local diffuseTextureCoordinatesBuffer = self.dummyTexCoordsBuffer
	if mesh.diffuseTextureCoords then
		local diffuseTextureCoordsCount = #mesh.diffuseTextureCoords / 2
		local diffuseTextureCoordsBufferSize = #mesh.diffuseTextureCoords * ffi.sizeof("float")
		printf(
			"Uploading geometry: %d diffuse texture coordinates (%s)",
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

function Renderer:ValidateGeometry(mesh)
	local positions = mesh.vertexPositions
	local colors = mesh.vertexColors
	local indices = mesh.triangleConnections

	local vertexCount = #positions / 3
	local indexCount = #indices
	local numVertexColors = #colors / 3

	if #positions % 3 ~= 0 then
		error(self.errorStrings.INVALID_VERTEX_BUFFER, 0)
	end

	if #colors % 3 ~= 0 then
		error(self.errorStrings.INVALID_COLOR_BUFFER, 0)
	end

	if indexCount % 3 ~= 0 then
		error(self.errorStrings.INVALID_INDEX_BUFFER, 0)
	end

	if vertexCount ~= numVertexColors then
		error(self.errorStrings.INCOMPLETE_COLOR_BUFFER, 0)
	end

	if not mesh.diffuseTextureCoords then
		return
	end

	local diffuseTextureCoordsCount = #mesh.diffuseTextureCoords / 2
	if (diffuseTextureCoordsCount * 2) % 2 ~= 0 then
		error(self.errorStrings.INVALID_UV_BUFFER, 0)
	end

	if vertexCount ~= diffuseTextureCoordsCount then
		error(self.errorStrings.INCOMPLETE_UV_BUFFER, 0)
	end
end

function Renderer:DestroyMeshGeometry(mesh)
	Buffer:Destroy(mesh.vertexBuffer)
	Buffer:Destroy(mesh.colorBuffer)
	Buffer:Destroy(mesh.indexBuffer)
	if mesh.diffuseTexCoordsBuffer ~= self.dummyTexCoordsBuffer then
		-- Don't destroy this, it might still be used by other meshes
		Buffer:Destroy(mesh.diffuseTexCoordsBuffer)
	end

	self.meshes = {}
end

function Renderer:UploadTextureImage(texture)
	if not texture then
		return
	end

	texture:CopyImageBytesToGPU(texture.rgbaImageBytes)
end

function Renderer:CreateUniformBuffers()
	local scenewideUniformBuffer = Device:CreateBuffer(
		self.wgpuDevice,
		ffi.new("WGPUBufferDescriptor", {
			size = ffi.sizeof("scenewide_uniform_t"),
			usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Uniform),
			mappedAtCreation = false,
		})
	)
	local cameraBindGroupDescriptor = ffi.new("WGPUBindGroupDescriptor", {
		layout = BasicTriangleDrawingPipeline.wgpuCameraBindGroupLayout,
		entryCount = BasicTriangleDrawingPipeline.wgpuCameraBindGroupLayoutDescriptor.entryCount,
		entries = ffi.new("WGPUBindGroupEntry", {
			binding = 0,
			buffer = scenewideUniformBuffer,
			offset = 0,
			size = ffi.sizeof("scenewide_uniform_t"),
		}),
	})

	local meshSpecificUniformBuffer = Device:CreateBuffer(
		self.wgpuDevice,
		ffi.new("WGPUBufferDescriptor", {
			size = ffi.sizeof("mesh_uniform_t") * WidgetDrawingPipeline.MAX_WIDGET_COUNT,
			usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Uniform),
			mappedAtCreation = false,
		})
	)
	local transformBindGroupDescriptor = ffi.new("WGPUBindGroupDescriptor", {
		-- This probably doesn't need to be pipeline-specific (can reuse for per-mesh transforms later)?
		layout = WidgetDrawingPipeline.wgpuTransformBindGroupLayout,
		entryCount = WidgetDrawingPipeline.wgpuTransformBindGroupLayoutDescriptor.entryCount,
		entries = ffi.new("WGPUBindGroupEntry", {
			binding = 0,
			buffer = meshSpecificUniformBuffer,
			offset = 0,
			size = ffi.sizeof("mesh_uniform_t"), -- Only bind one part as it's dynamically offset
		}),
	})

	self.uniforms = {
		perScene = {
			bindGroupDescriptor = cameraBindGroupDescriptor,
			bindGroup = Device:CreateBindGroup(self.wgpuDevice, cameraBindGroupDescriptor),
			buffer = scenewideUniformBuffer,
			data = ffi.new("scenewide_uniform_t"),
		},
		-- Should create the per-material buffer here, as well?
		perMesh = {
			bindGroupDescriptor = transformBindGroupDescriptor,
			bindGroup = Device:CreateBindGroup(self.wgpuDevice, transformBindGroupDescriptor),
			buffer = meshSpecificUniformBuffer,
			data = ffi.new("mesh_uniform_t[?]", WidgetDrawingPipeline.MAX_WIDGET_COUNT),
		},
	}
end

function Renderer:UpdateScenewideUniformBuffer()
	local aspectRatio = self.backingSurface:GetAspectRatio()
	local viewportWidth, viewportHeight = self.backingSurface:GetViewportSize()

	local perSceneUniformData = self.uniforms.perScene.data

	local cameraWorldPosition = C_Camera.GetWorldPosition()
	local cameraTarget = C_Camera.GetTargetPosition()
	local upVectorHint = Vector3D(0, 1, 0)
	local perspective = C_Camera.GetPerspective()
	perSceneUniformData.view = C_Camera.CreateOrbitalView(cameraWorldPosition, cameraTarget, upVectorHint)
	perSceneUniformData.viewportWidth = viewportWidth
	perSceneUniformData.viewportHeight = viewportHeight
	perSceneUniformData.perspectiveProjection =
		C_Camera.CreatePerspectiveProjection(perspective.fov, aspectRatio, perspective.nearZ, perspective.farZ)
	perSceneUniformData.color = ffi.new("float[4]", { 1.0, 1.0, 1.0, 1.0 })

	Queue:WriteBuffer(
		Device:GetQueue(self.wgpuDevice),
		self.uniforms.perScene.buffer,
		0,
		perSceneUniformData,
		ffi.sizeof(perSceneUniformData)
	)
end

function Renderer:EnableDepthBuffer()
	-- Create the depth texture
	local viewportWidth, viewportHeight = self.backingSurface:GetViewportSize()
	printf("Creating depth buffer with texture dimensions %d x %d", viewportWidth, viewportHeight)
	local depthTextureDesc = ffi.new("WGPUTextureDescriptor", {
		dimension = ffi.C.WGPUTextureDimension_2D,
		format = ffi.C.WGPUTextureFormat_Depth24Plus,
		mipLevelCount = 1,
		sampleCount = 1,
		size = {
			viewportWidth,
			viewportHeight,
			1,
		},
		usage = ffi.C.WGPUTextureUsage_RenderAttachment,
		viewFormatCount = 1,
		viewFormats = ffi.new("WGPUTextureFormat[1]", ffi.C.WGPUTextureFormat_Depth24Plus),
	})
	local depthTexture = Device:CreateTexture(self.wgpuDevice, depthTextureDesc)

	-- Create the view of the depth texture manipulated by the rasterizer
	local depthTextureViewDesc = ffi.new("WGPUTextureViewDescriptor", {
		aspect = ffi.C.WGPUTextureAspect_DepthOnly,
		baseArrayLayer = 0,
		arrayLayerCount = 1,
		baseMipLevel = 0,
		mipLevelCount = 1,
		dimension = ffi.C.WGPUTextureViewDimension_2D,
		format = ffi.C.WGPUTextureFormat_Depth24Plus,
	})
	local depthTextureView = Texture:CreateTextureView(depthTexture, depthTextureViewDesc)

	self.depthTextureView = depthTextureView
end

function Renderer:CreateDebugTexture()
	local textureFilePath = path.join("Core", "NativeClient", "Assets", "DebugTexture256.png")
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

-- Should probably move this to the runtime for efficiency (needs benchmarking)
-- Also... should use string buffers everywhere, but currently the API still uses strings
local function discardTransparentPixels(rgbaImageBytes, width, height, discardRanges)
	local OFFSET_RED = 0
	local OFFSET_GREEN = 1
	local OFFSET_BLUE = 2
	local OFFSET_ALPHA = 3

	local DISCARD_MIN_RED = discardRanges.red.from
	local DISCARD_MAX_RED = discardRanges.red.to
	local DISCARD_MIN_GREEN = discardRanges.green.from
	local DISCARD_MAX_GREEN = discardRanges.green.to
	local DISCARD_MIN_BLUE = discardRanges.blue.from
	local DISCARD_MAX_BLUE = discardRanges.blue.to

	local rgbaImageBuffer = buffer.new(width * height * 4):put(rgbaImageBytes)
	local pixelArray, bufferSize = rgbaImageBuffer:ref()
	assert(bufferSize == width * height * 4)

	for pixelStartOffset = 0, width * height * 4, 4 do
		local red = pixelArray[pixelStartOffset + OFFSET_RED]
		local green = pixelArray[pixelStartOffset + OFFSET_GREEN]
		local blue = pixelArray[pixelStartOffset + OFFSET_BLUE]

		local isRedWithinDiscardedRange = (red >= DISCARD_MIN_RED and red <= DISCARD_MAX_RED)
		local isGreenWithinDiscardedRange = (green >= DISCARD_MIN_GREEN and green <= DISCARD_MAX_GREEN)
		local isBlueWithinDiscardedRange = (blue >= DISCARD_MIN_BLUE and blue <= DISCARD_MAX_BLUE)
		local shouldDiscardPixel = isRedWithinDiscardedRange
			and isGreenWithinDiscardedRange
			and isBlueWithinDiscardedRange

		if shouldDiscardPixel then
			pixelArray[pixelStartOffset + OFFSET_ALPHA] = 0
		end
	end

	return rgbaImageBuffer:tostring()
end

function Renderer:CreateTextureImage(rgbaImageBytes, width, height)
	local inclusiveTransparentPixelRanges = {
		red = { from = 254, to = 255 },
		green = { from = 0, to = 3 },
		blue = { from = 254, to = 255 },
	}
	-- This is currently NOT in-place and so incurs unnecessary copy overhead (optimize later)
	rgbaImageBytes = discardTransparentPixels(rgbaImageBytes, width, height, inclusiveTransparentPixelRanges)

	local texture = Texture(self.wgpuDevice, rgbaImageBytes, width, height)
	Renderer:UploadTextureImage(texture)

	return texture
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

function Renderer:LoadSceneObjects(scene)
	printf("Loading scene objects for [[%s]]", scene.displayName)
	for index, mesh in ipairs(scene.meshes) do
		self:UploadMeshGeometry(mesh)

		if mesh.diffuseTexture then
			self:DebugDumpTextures(mesh, format("diffuse-texture-%s-%03d-in.png", scene.mapID, index))
			mesh.diffuseTexture = self:CreateTextureImage(
				mesh.diffuseTexture.rgbaImageBytes,
				mesh.diffuseTexture.width,
				mesh.diffuseTexture.height
			)
			self:DebugDumpTextures(mesh, format("diffuse-texture-%s-%03d-out.png", scene.mapID, index))
			self:UploadTextureImage(mesh.diffuseTexture)
		end
	end
end

function Renderer:DebugDumpTextures(mesh, fileName)
	if not Renderer.DEBUG_DISCARDED_BACKGROUND_PIXELS then
		return
	end

	if not mesh then
		return
	end

	local diffuseTexture = mesh.diffuseTexture
	if not diffuseTexture then
		return
	end

	C_FileSystem.MakeDirectoryTree("Exports")
	local pngBytes =
		C_ImageProcessing.EncodePNG(diffuseTexture.rgbaImageBytes, diffuseTexture.width, diffuseTexture.height)
	C_FileSystem.WriteFile(path.join("Exports", fileName), pngBytes)
end

function Renderer:ResetScene()
	printf("Unloading %d meshes", #self.meshes)
	for index, mesh in ipairs(self.meshes) do
		-- Should also free textures here? (deferred until the Resources API is in)
		self:DestroyMeshGeometry(mesh)
	end
end

return Renderer
