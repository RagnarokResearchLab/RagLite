local bit = require("bit")
local etrace = require("etrace")
local ffi = require("ffi")
local interop = require("interop")
local oop = require("oop")
local rml = require("rml")
local uv = require("uv")
local validation = require("validation")
local webgpu = require("webgpu")

local GPU = require("Core.NativeClient.WebGPU.GPU")
local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WidgetDrawingPipeline")

local Buffer = require("Core.NativeClient.WebGPU.Buffer")
local CommandEncoder = require("Core.NativeClient.WebGPU.CommandEncoder")
local Device = require("Core.NativeClient.WebGPU.Device")
local Queue = require("Core.NativeClient.WebGPU.Queue")
local RenderPassEncoder = require("Core.NativeClient.WebGPU.RenderPassEncoder")
local Surface = require("Core.NativeClient.WebGPU.Surface")
local Texture = require("Core.NativeClient.WebGPU.Texture")
local UniformBuffer = require("Core.NativeClient.WebGPU.UniformBuffer")
local GroundMeshMaterial = require("Core.NativeClient.WebGPU.Materials.GroundMeshMaterial")
local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.Materials.UnlitMeshMaterial")
local UserInterfaceMaterial = require("Core.NativeClient.WebGPU.Materials.UserInterfaceMaterial")
local WaterSurfaceMaterial = require("Core.NativeClient.WebGPU.Materials.WaterSurfaceMaterial")

local Vector3D = require("Core.VectorMath.Vector3D")
local C_Camera = require("Core.NativeClient.C_Camera")

local assert = assert
local ipairs = ipairs
local rawget = rawget

local instanceof = oop.instanceof
local new = ffi.new
local format = string.format
local filesize = string.filesize
local table_insert = table.insert

local Color = require("Core.NativeClient.DebugDraw.Color")
local DEFAULT_AMBIENT_COLOR = { red = 1, green = 1, blue = 1, intensity = 1 }

local Renderer = {
	clearColorRGBA = { Color.GREY.red, Color.GREY.green, Color.GREY.blue, 0 },
	userInterfaceTexturesToMaterial = {},
	meshes = {},
	ambientLight = {
		red = DEFAULT_AMBIENT_COLOR.red,
		green = DEFAULT_AMBIENT_COLOR.green,
		blue = DEFAULT_AMBIENT_COLOR.blue,
		intensity = DEFAULT_AMBIENT_COLOR.intensity,
	},
	DEBUG_DISCARDED_BACKGROUND_PIXELS = false, -- This is really slow (disk I/O); don't enable unless necessary
	numWidgetTransformsUsedThisFrame = 0,
	errorStrings = {
		INVALID_VERTEX_BUFFER = "Cannot upload geometry with invalid vertex buffer",
		INVALID_INDEX_BUFFER = "Cannot upload geometry with invalid index buffer",
		INVALID_COLOR_BUFFER = "Cannot upload geometry with invalid color buffer",
		INVALID_UV_BUFFER = "Cannot upload geometry with invalid diffuse texture coordinates buffer",
		INVALID_NORMAL_BUFFER = "Cannot upload geometry with invalid normal buffer",
		INCOMPLETE_COLOR_BUFFER = "Cannot upload geometry with missing or incomplete vertex colors",
		INCOMPLETE_UV_BUFFER = "Cannot upload geometry with missing or incomplete diffuse texture coordinates ",
		INVALID_MATERIAL = "Invalid material assigned to mesh",
		INCOMPLETE_NORMAL_BUFFER = "Cannot upload geometry with missing or incomplete surface normals ",
	},
	supportedMaterials = {
		-- The order doesn't really matter, as long as it's consistently used
		UnlitMeshMaterial,
		GroundMeshMaterial,
		WaterSurfaceMaterial,
		-- Reverse lookup table built in (no problem as it's skipped by ipairs)
		[UnlitMeshMaterial] = 1,
		[GroundMeshMaterial] = 2,
		[WaterSurfaceMaterial] = 3,
	},
}

function Renderer:InitializeWithGLFW(nativeWindowHandle)
	Renderer:CreateGraphicsContext(nativeWindowHandle)

	-- Need to compute the preferred texture format first
	self.backingSurface:UpdateConfiguration()
	Renderer:CompileMaterials(self.backingSurface.preferredTextureFormat)

	Renderer:CreateUniformBuffers()
	Renderer:EnableDepthBuffer()

	-- Default texture that is multiplicatively neutral (use with untextured geometry to keep things simple)
	Renderer:CreateDummyTexture()

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

function Renderer:CompileMaterials(outputTextureFormat)
	-- Since there's (probably) no need for fancy sampling techniques, just re-use one for all materials
	Texture:CreateSharedTrilinearSampler(self.wgpuDevice)

	-- Camera and viewport uniforms shouldn't be owned by any one material, but all pipeline layouts depend on them
	UniformBuffer:CreateCameraBindGroupLayout(self.wgpuDevice)
	self.cameraViewportUniform = UniformBuffer:CreateCameraAndViewportUniform(self.wgpuDevice)

	-- Material uniforms are indeed owned by the various materials, but there's only a few shared layouts
	UniformBuffer:CreateMaterialBindGroupLayouts(self.wgpuDevice)

	UnlitMeshMaterial:Compile(self.wgpuDevice, outputTextureFormat)
	GroundMeshMaterial:Compile(self.wgpuDevice, outputTextureFormat)
	WaterSurfaceMaterial:Compile(self.wgpuDevice, outputTextureFormat)
	UserInterfaceMaterial:Compile(self.wgpuDevice, outputTextureFormat)
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
local function assertMeshHasMaterial(mesh)
	if not rawget(mesh, "material") then
		local errorMessage =
			format("%s %s (%s)", Renderer.errorStrings.INVALID_MATERIAL, mesh.uniqueID, mesh.displayName)
		error(errorMessage, 0)
	end
end

function Renderer:SortMeshesByMaterial(meshes)
	local meshesSortedByMaterial = {}

	for materialIndex, material in ipairs(Renderer.supportedMaterials) do
		meshesSortedByMaterial[materialIndex] = {}
	end

	for index, mesh in ipairs(meshes) do
		assertMeshHasMaterial(mesh) -- Should do this when creating the geometry, probably?

		-- This might look scary in a hot loop, but there really won't be all that many materials
		for materialIndex, material in ipairs(Renderer.supportedMaterials) do
			if instanceof(mesh.material, material) then
				table_insert(meshesSortedByMaterial[materialIndex], mesh)
			end
		end
	end

	return meshesSortedByMaterial
end

function Renderer:RenderNextFrame(deltaTime)
	etrace.clear()

	-- Blocking call in VSYNC present mode, so timing this isn't particularly helpful
	local nextTextureView = self.backingSurface:AcquireTextureView()

	local commandEncoderDescriptor = new("WGPUCommandEncoderDescriptor")
	local commandEncoder = Device:CreateCommandEncoder(self.wgpuDevice, commandEncoderDescriptor)

	local worldRenderPassStartTime = uv.hrtime()
	do
		local renderPass = self:BeginRenderPass(commandEncoder, nextTextureView)
		self:ResetScissorRectangle(renderPass)

		self:UpdateScenewideUniformBuffer(deltaTime)
		RenderPassEncoder:SetBindGroup(renderPass, 0, self.cameraViewportUniform.bindGroup, 0, nil)

		local meshesByMaterial = self:SortMeshesByMaterial(self.meshes)
		for materialIndex, meshes in pairs(meshesByMaterial) do
			local material = self.supportedMaterials[materialIndex]
			-- Should skip this if there aren't any meshes (wasteful to switch for no reason)?
			RenderPassEncoder:SetPipeline(renderPass, material.assignedRenderingPipeline.wgpuPipeline)
			for _, mesh in ipairs(meshes) do
				for index, animation in ipairs(mesh.keyframeAnimations) do
					animation:UpdateWithDeltaTime(deltaTime / 10E5)
				end
				self:DrawMesh(renderPass, mesh)
				mesh:OnUpdate(deltaTime / 10E5)
			end
		end

		RenderPassEncoder:End(renderPass)
	end
	local worldRenderPassTime = uv.hrtime() - worldRenderPassStartTime
	local uiRenderPassStartTime = uv.hrtime()
	do
		local uiRenderPass = self:BeginUserInterfaceRenderPass(commandEncoder, nextTextureView)
		RenderPassEncoder:SetBindGroup(uiRenderPass, 0, self.cameraViewportUniform.bindGroup, 0, nil)
		RenderPassEncoder:SetPipeline(uiRenderPass, UserInterfaceMaterial.assignedRenderingPipeline.wgpuPipeline)

		self.numWidgetTransformsUsedThisFrame = 0
		rml.bindings.rml_context_update(self.rmlContext)
		-- NO MORE CHANGES here before rendering the updated state!
		rml.bindings.rml_context_render(self.rmlContext)

		self:ProcessUserInterfaceRenderCommands(uiRenderPass)

		RenderPassEncoder:End(uiRenderPass)
	end
	local uiRenderPassTime = uv.hrtime() - uiRenderPassStartTime

	local commandSubmitStartTime = uv.hrtime()
	self:SubmitCommandBuffer(commandEncoder)
	local commandSubmissionTime = uv.hrtime() - commandSubmitStartTime

	self.backingSurface:PresentNextFrame()

	local totalFrameTime = worldRenderPassTime + uiRenderPassTime + commandSubmissionTime
	return totalFrameTime, worldRenderPassTime, uiRenderPassTime, commandSubmissionTime
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
	local wgpuTexturePointer = tonumber(ffi.cast("intptr_t", wgpuTexture))
	local materialInstance =
		UserInterfaceMaterial("GeneratedUserInterfaceTextureMaterial" .. format("%p", wgpuTexturePointer))
	materialInstance:AssignDiffuseTexture(nil, wgpuTexture) -- Hacky, fix later (streamline Texture constructors)
	self.userInterfaceTexturesToMaterial[wgpuTexturePointer] = materialInstance
end

function Renderer:TEXTURE_RELEASE_EVENT(eventID, payload)
	error("TEXTURE_RELEASE_EVENT") -- NYI (the memory leak doesn't matter, for now)
end

function Renderer:TRANSFORMATION_UPDATE_EVENT(eventID, payload)
	error("TRANSFORMATION_UPDATE_EVENT") -- NYI (CSS transforms aren't currently supported, nor used)
end

function Renderer:BeginRenderPass(commandEncoder, nextTextureView)
	-- Clearing is a built-in mechanism of the render pass
	local renderPassColorAttachment = new("WGPURenderPassColorAttachment", {
		view = nextTextureView,
		loadOp = ffi.C.WGPULoadOp_Clear,
		storeOp = ffi.C.WGPUStoreOp_Store,
		clearValue = new("WGPUColor", self.clearColorRGBA),
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

	local renderPassDescriptor = new("WGPURenderPassDescriptor", {
		colorAttachmentCount = 1,
		colorAttachments = renderPassColorAttachment,
		depthStencilAttachment = depthStencilAttachment,
	})

	return CommandEncoder:BeginRenderPass(commandEncoder, renderPassDescriptor)
end

function Renderer:BeginUserInterfaceRenderPass(commandEncoder, nextTextureView)
	local renderPassColorAttachment = new("WGPURenderPassColorAttachment", {
		view = nextTextureView,
		loadOp = ffi.C.WGPULoadOp_Load, -- Preserve existing framebuffer content
		storeOp = ffi.C.WGPUStoreOp_Store,
		clearValue = new("WGPUColor", self.clearColorRGBA),
	})

	local renderPassDescriptor = new("WGPURenderPassDescriptor", {
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
	local diffuseTexCoordsBufferSize = #mesh.diffuseTextureCoords * ffi.sizeof("float") or GPU.MAX_VERTEX_COUNT
	local surfaceNormalsBufferSize = #mesh.surfaceNormals * ffi.sizeof("float")

	RenderPassEncoder:SetVertexBuffer(renderPass, 0, mesh.vertexBuffer, 0, vertexBufferSize)
	RenderPassEncoder:SetVertexBuffer(renderPass, 1, mesh.colorBuffer, 0, colorBufferSize)
	RenderPassEncoder:SetVertexBuffer(renderPass, 2, mesh.diffuseTexCoordsBuffer, 0, diffuseTexCoordsBufferSize)
	RenderPassEncoder:SetVertexBuffer(renderPass, 3, mesh.surfaceNormalsBuffer, 0, surfaceNormalsBufferSize)
	RenderPassEncoder:SetIndexBuffer(renderPass, mesh.indexBuffer, ffi.C.WGPUIndexFormat_Uint32, 0, indexBufferSize)

	if rawget(mesh.material, "diffuseTexture") then
		RenderPassEncoder:SetBindGroup(renderPass, 1, mesh.material.diffuseTextureBindGroup, 0, nil)
		mesh.material:UpdateMaterialPropertiesUniform()
	elseif rawget(mesh.material, "diffuseTextureArray") then -- Identical, for now - but that's likely to change
		RenderPassEncoder:SetBindGroup(renderPass, 1, mesh.material.diffuseTextureBindGroup, 0, nil)
		mesh.material:UpdateMaterialPropertiesUniform()
	else
		RenderPassEncoder:SetBindGroup(renderPass, 1, self.dummyTextureMaterial.diffuseTextureBindGroup, 0, nil)
		self.dummyTextureMaterial:UpdateMaterialPropertiesUniform() -- Wasteful, should only do it once?
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

	if compiledWidgetGeometry.texture == ffi.NULL then
		RenderPassEncoder:SetBindGroup(renderPass, 1, self.dummyTextureMaterial.diffuseTextureBindGroup, 0, nil)
	else
		local wgpuTexture = ffi.cast("WGPUTexture", compiledWidgetGeometry.texture)
		local wgpuTexturePointer = tonumber(ffi.cast("intptr_t", wgpuTexture))
		local materialInstance = self.userInterfaceTexturesToMaterial[wgpuTexturePointer]
		local textureBindGroup = materialInstance.diffuseTextureBindGroup
		assert(textureBindGroup, "No relevant bind group found for RML texture: " .. tostring(wgpuTexture))

		-- This seems to cause issues if multiple meshes use the same texture (=material instance) - fix later
		-- The material data is only written once per pass, so a dynamic uniform buffer would have to be used
		materialInstance:UpdateMaterialPropertiesUniform()
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
	local commandBufferDescriptor = new("WGPUCommandBufferDescriptor")
	local commandBuffer = CommandEncoder:Finish(commandEncoder, commandBufferDescriptor)

	-- The WebGPU API expects an array here, but currently this renderer only supports a single buffer (to keep things simple)
	local queue = Device:GetQueue(self.wgpuDevice)
	local commandBuffers = new("WGPUCommandBuffer[1]", commandBuffer)
	Queue:Submit(queue, 1, commandBuffers)
end

function Renderer:UploadMeshGeometry(mesh)
	local positions = mesh.vertexPositions
	local colors = mesh.vertexColors
	local indices = mesh.triangleConnections
	local normals = mesh.surfaceNormals

	local vertexCount = #positions / 3
	local indexCount = #indices
	local numVertexColors = #colors / 3
	local normalCount = #normals / 3

	if vertexCount == 0 or indexCount == 0 then
		printf("Skipping geometry upload for mesh %s (%s)", mesh.uniqueID, mesh.displayName)
		return
	end
	printf("Uploading geometry for mesh %s (%s)", mesh.uniqueID, mesh.displayName)

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

	local diffuseTextureCoordsCount = #mesh.diffuseTextureCoords / 2
	local diffuseTextureCoordsBufferSize = #mesh.diffuseTextureCoords * ffi.sizeof("float")
	printf(
		"Uploading geometry: %d diffuse texture coordinates (%s)",
		diffuseTextureCoordsCount,
		filesize(diffuseTextureCoordsBufferSize)
	)
	local diffuseTextureCoordinatesBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, mesh.diffuseTextureCoords)

	local normalBufferSize = normalCount * ffi.sizeof("float")
	printf("Uploading geometry: %d surface normals (%s)", normalCount, filesize(normalBufferSize))
	local surfaceNormalsBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, mesh.surfaceNormals)

	mesh.vertexBuffer = vertexBuffer
	mesh.colorBuffer = vertexColorsBuffer
	mesh.indexBuffer = triangleIndicesBuffer
	mesh.diffuseTexCoordsBuffer = diffuseTextureCoordinatesBuffer
	mesh.surfaceNormalsBuffer = surfaceNormalsBuffer

	table.insert(self.meshes, mesh)
end

function Renderer:ValidateGeometry(mesh)
	local positions = mesh.vertexPositions
	local colors = mesh.vertexColors
	local indices = mesh.triangleConnections
	local normals = mesh.surfaceNormals

	local vertexCount = #positions / 3
	local indexCount = #indices
	local numVertexColors = #colors / 3
	local numSurfaceNormals = #normals / 3

	if #positions % 3 ~= 0 then
		error(self.errorStrings.INVALID_VERTEX_BUFFER, 0)
	end

	if #colors % 3 ~= 0 then
		error(self.errorStrings.INVALID_COLOR_BUFFER, 0)
	end

	if indexCount % 3 ~= 0 then
		error(self.errorStrings.INVALID_INDEX_BUFFER, 0)
	end

	if #normals % 3 ~= 0 then
		error(self.errorStrings.INVALID_NORMAL_BUFFER, 0)
	end

	if vertexCount ~= numVertexColors then
		error(self.errorStrings.INCOMPLETE_COLOR_BUFFER, 0)
	end

	if vertexCount ~= numSurfaceNormals then
		error(self.errorStrings.INCOMPLETE_NORMAL_BUFFER, 0)
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
	-- Needs streamlining (later)
	Buffer:Destroy(rawget(mesh, "vertexBuffer"))
	Buffer:Destroy(rawget(mesh, "colorBuffer"))
	Buffer:Destroy(rawget(mesh, "indexBuffer"))
	Buffer:Destroy(rawget(mesh, "diffuseTexCoordsBuffer"))
	Buffer:Destroy(rawget(mesh, "surfaceNormalsBuffer"))

	self.meshes = {}
end

function Renderer:UploadTextureImage(texture)
	if not texture then
		return
	end

	texture:CopyImageBytesToGPU(texture.rgbaImageBytes)
end

function Renderer:CreateUniformBuffers()
	local meshSpecificUniformBuffer = Device:CreateBuffer(
		self.wgpuDevice,
		ffi.new("WGPUBufferDescriptor", {
			size = ffi.sizeof("mesh_uniform_t") * WidgetDrawingPipeline.MAX_WIDGET_COUNT,
			usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Uniform),
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
		-- Should create the per-material buffer here, as well?
		perMesh = {
			bindGroupDescriptor = transformBindGroupDescriptor,
			bindGroup = Device:CreateBindGroup(self.wgpuDevice, transformBindGroupDescriptor),
			buffer = meshSpecificUniformBuffer,
			data = ffi.new("mesh_uniform_t[?]", WidgetDrawingPipeline.MAX_WIDGET_COUNT),
		},
	}
end

function Renderer:UpdateScenewideUniformBuffer(deltaTime)
	local aspectRatio = self.backingSurface:GetAspectRatio()
	local viewportWidth, viewportHeight = self.backingSurface:GetViewportSize()

	local perSceneUniformData = self.cameraViewportUniform.data

	local cameraWorldPosition = C_Camera.GetWorldPosition()
	local cameraTarget = C_Camera.GetTargetPosition()
	local upVectorHint = Vector3D(0, 1, 0)
	local perspective = C_Camera.GetPerspective()
	perSceneUniformData.view = C_Camera.CreateOrbitalView(cameraWorldPosition, cameraTarget, upVectorHint)
	perSceneUniformData.viewportWidth = viewportWidth
	perSceneUniformData.viewportHeight = viewportHeight
	perSceneUniformData.perspectiveProjection =
		C_Camera.CreatePerspectiveProjection(perspective.fov, aspectRatio, perspective.nearZ, perspective.farZ)
	assert(self.ambientLight.intensity == 1, "The ambient light must always be at full intensity")
	perSceneUniformData.ambientLightRed = self.ambientLight.red
	perSceneUniformData.ambientLightGreen = self.ambientLight.green
	perSceneUniformData.ambientLightBlue = self.ambientLight.blue
	perSceneUniformData.ambientLightIntensity = self.ambientLight.intensity
	perSceneUniformData.deltaTime = deltaTime

	Queue:WriteBuffer(
		Device:GetQueue(self.wgpuDevice),
		self.cameraViewportUniform.buffer,
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
	-- Can't use this dummy texture for nonstandard materials? For now it seems OK, may need to fix later
	local dummyTextureMaterial = UnlitMeshMaterial("DummyTextureMaterial")
	dummyTextureMaterial:AssignDiffuseTexture(blankTexture)
	Renderer:UploadTextureImage(blankTexture)

	self.dummyTextureMaterial = dummyTextureMaterial
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

function Renderer:CreateTextureFromImage(rgbaImageBytes, width, height)
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

function Renderer:LoadSceneObjects(scene)
	printf("Loading scene objects for [[%s]]", scene.displayName)
	for index, mesh in ipairs(scene.meshes) do
		self:UploadMeshGeometry(mesh)

		local textureImage = rawget(mesh, "diffuseTextureImage")
		local textureImages = rawget(mesh, "diffuseTextureImages") or {}
		if textureImage then
			textureImages = { textureImage }
		end

		local diffuseTextures = {}
		for textureIndex = 1, #textureImages, 1 do
			local image = textureImages[textureIndex]
			self:DebugDumpTextures(mesh, format("diffuse-texture-%s-%03d-in.png", scene.mapID, textureIndex))
			local wgpuTextureHandle = self:CreateTextureFromImage(image.rgbaImageBytes, image.width, image.height)
			table_insert(diffuseTextures, wgpuTextureHandle)
			self:DebugDumpTextures(mesh, format("diffuse-texture-%s-%03d-out.png", scene.mapID, textureIndex))
		end

		if #diffuseTextures == 1 then -- Regular material
			mesh.material:AssignDiffuseTexture(diffuseTextures[1])
		elseif #diffuseTextures > 1 then -- Water material (using texture array)
			mesh.material:AssignDiffuseTextureArray(diffuseTextures)
		end
	end

	if scene.ambientLight then
		self.ambientLight = scene.ambientLight
	else
		self.ambientLight.red = DEFAULT_AMBIENT_COLOR.red
		self.ambientLight.green = DEFAULT_AMBIENT_COLOR.green
		self.ambientLight.blue = DEFAULT_AMBIENT_COLOR.blue
		self.ambientLight.intensity = DEFAULT_AMBIENT_COLOR.intensity
	end
end

function Renderer:DebugDumpTextures(mesh, fileName)
	if not Renderer.DEBUG_DISCARDED_BACKGROUND_PIXELS then
		return
	end

	if not mesh then
		return
	end

	local diffuseTextureImage = mesh.diffuseTextureImage
	if not diffuseTextureImage then
		return
	end

	C_FileSystem.MakeDirectoryTree("Exports")
	local pngBytes = C_ImageProcessing.EncodePNG(
		diffuseTextureImage.rgbaImageBytes,
		diffuseTextureImage.width,
		diffuseTextureImage.height
	)
	C_FileSystem.WriteFile(path.join("Exports", fileName), pngBytes)
end

function Renderer:ResetScene()
	printf("Unloading %d meshes", #self.meshes)
	for index, mesh in ipairs(self.meshes) do
		-- Should also free textures here? (deferred until the Resources API is in)
		self:DestroyMeshGeometry(mesh)
	end

	self.ambientLight.red = DEFAULT_AMBIENT_COLOR.red
	self.ambientLight.green = DEFAULT_AMBIENT_COLOR.green
	self.ambientLight.blue = DEFAULT_AMBIENT_COLOR.blue
	self.ambientLight.intensity = DEFAULT_AMBIENT_COLOR.intensity
end

return Renderer
