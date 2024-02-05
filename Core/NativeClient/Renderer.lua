local bit = require("bit")
local console = require("console")
local etrace = require("etrace")
local ffi = require("ffi")
local interop = require("interop")
local oop = require("oop")
local rml = require("rml")
local uv = require("uv")
local transform = require("transform")
local validation = require("validation")
local webgpu = require("wgpu")

local GPU = require("Core.NativeClient.WebGPU.GPU")
local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WidgetDrawingPipeline")

local Buffer = require("Core.NativeClient.WebGPU.Buffer")
local CommandEncoder = require("Core.NativeClient.WebGPU.CommandEncoder")
local DepthStencilTexture = require("Core.NativeClient.WebGPU.RenderTargets.DepthStencilTexture")
local Device = require("Core.NativeClient.WebGPU.Device")
local Queue = require("Core.NativeClient.WebGPU.Queue")
local RenderPassEncoder = require("Core.NativeClient.WebGPU.RenderPassEncoder")
local ScreenshotCaptureTexture = require("Core.NativeClient.WebGPU.RenderTargets.ScreenshotCaptureTexture")
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
local printf = printf
local format = string.format
local filesize = string.filesize
local table_insert = table.insert

local Color = require("Core.NativeClient.DebugDraw.Color")
local DEFAULT_AMBIENT_COLOR = { red = 1, green = 1, blue = 1, intensity = 1 }
local DEFAULT_SUNLIGHT_COLOR = DEFAULT_AMBIENT_COLOR
local DEFAULT_SUNLIGHT_DIRECTION = { x = 1, y = -1, z = 1 }

local Renderer = {
	clearColorRGBA = { Color.BLACK.red, Color.BLACK.green, Color.BLACK.blue, 0 },
	userInterfaceTexturesToMaterial = {},
	meshes = {},
	ambientLight = {
		red = DEFAULT_AMBIENT_COLOR.red,
		green = DEFAULT_AMBIENT_COLOR.green,
		blue = DEFAULT_AMBIENT_COLOR.blue,
		intensity = DEFAULT_AMBIENT_COLOR.intensity,
	},
	directionalLight = {
		red = DEFAULT_SUNLIGHT_COLOR.red,
		green = DEFAULT_SUNLIGHT_COLOR.green,
		blue = DEFAULT_SUNLIGHT_COLOR.blue,
		intensity = DEFAULT_SUNLIGHT_COLOR.intensity,
		rayDirection = {
			x = DEFAULT_SUNLIGHT_DIRECTION.x,
			y = DEFAULT_SUNLIGHT_DIRECTION.y,
			z = DEFAULT_SUNLIGHT_DIRECTION.z,
		},
	},
	DEBUG_DISCARDED_BACKGROUND_PIXELS = false, -- This is really slow (disk I/O); don't enable unless necessary
	SCREENSHOT_OUTPUT_DIRECTORY = "Screenshots",
	numWidgetTransformsUsedThisFrame = 0,
	errorStrings = {
		INVALID_VERTEX_BUFFER = "Cannot upload geometry with invalid vertex buffer",
		INVALID_INDEX_BUFFER = "Cannot upload geometry with invalid index buffer",
		INVALID_COLOR_BUFFER = "Cannot upload geometry with invalid color buffer",
		INVALID_UV_BUFFER = "Cannot upload geometry with invalid diffuse texture coordinates buffer",
		INVALID_LIGHTMAP_UV_BUFFER = "Cannot upload geometry with invalid lightmap texture coordinates buffer",
		INVALID_NORMAL_BUFFER = "Cannot upload geometry with invalid normal buffer",
		INCOMPLETE_COLOR_BUFFER = "Cannot upload geometry with missing or incomplete vertex colors",
		INCOMPLETE_UV_BUFFER = "Cannot upload geometry with missing or incomplete diffuse texture coordinates ",
		INCOMPLETE_LIGHTMAP_UV_BUFFER = "Cannot upload geometry with missing or incomplete lightmap texture coordinates ",
		INVALID_MATERIAL = "Invalid material assigned to mesh",
		INCOMPLETE_NORMAL_BUFFER = "Cannot upload geometry with missing or incomplete surface normals ",
		TEXTURE_ACQUISITION_FAILED = "Failed to acquire surface texture; skipping the current frame. Reason:\n%s",
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
	Renderer:CompileMaterials(self.backingSurface.textureFormat)

	Renderer:CreateUniformBuffers()

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

	local viewportWidth, viewportHeight = self.backingSurface:GetViewportSize()
	self.screenshotTexture = ScreenshotCaptureTexture(device, viewportWidth, viewportHeight)

	printf("Creating depth buffer with texture dimensions %d x %d", viewportWidth, viewportHeight)
	self.depthStencilTexture = DepthStencilTexture(device, viewportWidth, viewportHeight)

	self.backingSurface:UpdateConfiguration()
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
	local nextTextureView, failureReason = self.backingSurface:AcquireTextureView()
	if not nextTextureView then
		-- Recoverable error, but this frame is probably beyond saving as reconfiguring the surface takes time
		printf(transform.yellow(Renderer.errorStrings.TEXTURE_ACQUISITION_FAILED), failureReason)
		self.backingSurface:UpdateConfiguration()
		return 0, 0, 0, 0
	end

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
			if self.isCapturingScreenshot then
				RenderPassEncoder:SetPipeline(renderPass, material.offlineRenderingPipeline.wgpuPipeline)
			else
				RenderPassEncoder:SetPipeline(renderPass, material.surfaceRenderingPipeline.wgpuPipeline)
			end
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
		if self.isCapturingScreenshot then
			RenderPassEncoder:SetPipeline(uiRenderPass, UserInterfaceMaterial.offlineRenderingPipeline.wgpuPipeline)
		else
			RenderPassEncoder:SetPipeline(uiRenderPass, UserInterfaceMaterial.surfaceRenderingPipeline.wgpuPipeline)
		end
		self.numWidgetTransformsUsedThisFrame = 0
		rml.bindings.rml_context_update(self.rmlContext)
		-- NO MORE CHANGES here before rendering the updated state!
		rml.bindings.rml_context_render(self.rmlContext)

		self:ProcessUserInterfaceRenderCommands(uiRenderPass)

		RenderPassEncoder:End(uiRenderPass)
	end
	local uiRenderPassTime = uv.hrtime() - uiRenderPassStartTime

	local commandSubmitStartTime = uv.hrtime()
	CommandEncoder:Submit(commandEncoder, self.wgpuDevice)
	local commandSubmissionTime = uv.hrtime() - commandSubmitStartTime

	if self.isCapturingScreenshot then
		local rgbaImageBytes, width, height = self.screenshotTexture:DownloadPixelBuffer(self.wgpuDevice)
		-- This assumes the buffer read is blocking (which is suboptimal); streamline later, via events
		self:SaveCapturedScreenshot(rgbaImageBytes, width, height)
		self.isCapturingScreenshot = false
	end

	self.backingSurface:PresentNextFrame()

	local totalFrameTime = worldRenderPassTime + uiRenderPassTime + commandSubmissionTime
	return totalFrameTime, worldRenderPassTime, uiRenderPassTime, commandSubmissionTime
end

function Renderer:SaveCapturedScreenshot(rgbaImageBytes, width, height)
	console.startTimer("[Renderer] SaveCapturedScreenshot")

	local screenshotFileName = format("RagLite_Screenshot_%s.jpg", os.date("%Y%m%d%H%M%S"))
	C_FileSystem.MakeDirectoryTree(Renderer.SCREENSHOT_OUTPUT_DIRECTORY)
	local screenshotFilePath = path.join(Renderer.SCREENSHOT_OUTPUT_DIRECTORY, screenshotFileName)

	local imageFileContents = C_ImageProcessing.EncodeJPG(rgbaImageBytes, width, height)

	C_FileSystem.WriteFile(screenshotFilePath, imageFileContents)
	printf(
		"Screenshot taken: %s (raw size: %s, encoded size: %s)",
		screenshotFileName,
		string.filesize(#rgbaImageBytes),
		string.filesize(#imageFileContents)
	)

	console.stopTimer("[Renderer] SaveCapturedScreenshot")
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
	local surfaceColorAttachment = new("WGPURenderPassColorAttachment", {
		view = nextTextureView,
		loadOp = ffi.C.WGPULoadOp_Clear,
		storeOp = ffi.C.WGPUStoreOp_Store,
		clearValue = new("WGPUColor", self.clearColorRGBA),
	})

	local screenshotCaptureAttachment = self.screenshotTexture.colorAttachment
	local colorAttachment = self.isCapturingScreenshot and screenshotCaptureAttachment or surfaceColorAttachment

	-- Clearing is a built-in mechanism of the render pass
	colorAttachment.loadOp = ffi.C.WGPULoadOp_Clear
	colorAttachment.clearValue = self.clearColorRGBA

	local renderPassDescriptor = new("WGPURenderPassDescriptor", {
		colorAttachmentCount = 1,
		colorAttachments = colorAttachment,
		depthStencilAttachment = self.depthStencilTexture.colorAttachment,
	})

	return CommandEncoder:BeginRenderPass(commandEncoder, renderPassDescriptor)
end

function Renderer:BeginUserInterfaceRenderPass(commandEncoder, nextTextureView)
	local surfaceColorAttachment = new("WGPURenderPassColorAttachment", {
		view = nextTextureView,
		loadOp = ffi.C.WGPULoadOp_Load,
		storeOp = ffi.C.WGPUStoreOp_Store,
		clearValue = new("WGPUColor", self.clearColorRGBA),
	})

	local screenshotCaptureAttachment = self.screenshotTexture.colorAttachment
	local colorAttachment = self.isCapturingScreenshot and screenshotCaptureAttachment or surfaceColorAttachment
	colorAttachment.loadOp = ffi.C.WGPULoadOp_Load -- The UI should be rendered on top of the 3D world
	local renderPassDescriptor = new("WGPURenderPassDescriptor", {
		colorAttachmentCount = 1,
		colorAttachments = colorAttachment,
		-- Depth/stencil testing is omitted since it isn't needed for UI rendering
	})

	return CommandEncoder:BeginRenderPass(commandEncoder, renderPassDescriptor)
end

function Renderer:DrawMesh(renderPass, mesh)
	local isCGND = type(mesh.vertexPositions) == "cdata"

	local vertexBufferSize = (isCGND and mesh.numVertexPositions or #mesh.vertexPositions) * ffi.sizeof("float")
	local colorBufferSize = (isCGND and mesh.numVertexColors or #mesh.vertexColors) * ffi.sizeof("float")
	local indexBufferSize = (isCGND and mesh.numTriangleConnections	or #mesh.triangleConnections) * ffi.sizeof("uint32_t")
	local diffuseTexCoordsBufferSize = (isCGND and mesh.numDiffuseTextureCoords or #mesh.diffuseTextureCoords) * ffi.sizeof("float")
		or GPU.MAX_VERTEX_COUNT
	local surfaceNormalsBufferSize = (isCGND and mesh.numSurfaceNormals or #mesh.surfaceNormals) * ffi.sizeof("float")

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

	if rawget(mesh.material, "lightmapTexture") then
		-- This binding slot is usually reserved for instance transforms, but they aren't needed for the terrain
		RenderPassEncoder:SetBindGroup(renderPass, 2, mesh.material.lightmapTextureBindGroup, 0, nil)
		local lightmapTexCoordsBufferSize = (isCGND and mesh.numLightmapTextureCoords or #mesh.lightmapTextureCoords) * ffi.sizeof("float")
			or GPU.MAX_VERTEX_COUNT
		RenderPassEncoder:SetVertexBuffer(renderPass, 4, mesh.lightmapTexCoordsBuffer, 0, lightmapTexCoordsBufferSize)
	end

	local instanceCount = 1
	local firstVertexIndex = 0
	local firstInstanceIndex = 0
	local indexBufferOffset = 0
	RenderPassEncoder:DrawIndexed(
		renderPass,
		isCGND and mesh.numTriangleConnections or #mesh.triangleConnections,
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

function Renderer:UploadMeshGeometry(mesh)
	local positions = mesh.vertexPositions
	local colors = mesh.vertexColors
	local indices = mesh.triangleConnections
	local normals = mesh.surfaceNormals

	local isCGND = type(positions) == "cdata"

	local vertexCount = isCGND and mesh.numVertexPositions or #positions / 3
	local indexCount = isCGND and mesh.numTriangleConnections or #indices
	local numVertexColors = isCGND and mesh.numVertexColors or #colors / 3
	local normalCount = isCGND and mesh.numSurfaceNormals or #normals / 3

	if vertexCount == 0 or indexCount == 0 then
		printf("Skipping geometry upload for mesh %s (%s)", mesh.uniqueID, mesh.displayName)
		return
	end
	printf("Uploading geometry for mesh %s (%s)", mesh.uniqueID, mesh.displayName)

	self:ValidateGeometry(mesh)

	local vertexBufferSize = vertexCount * 3 * ffi.sizeof("float")
	printf("Uploading geometry: %d vertex positions (%s)", vertexCount, filesize(vertexBufferSize))
	local vertexBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, positions)

	local vertexColorsBufferSize = numVertexColors * 3 * ffi.sizeof("float")
	printf("Uploading geometry: %d vertex colors (%s)", numVertexColors, filesize(vertexColorsBufferSize))
	local vertexColorsBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, colors)

	local triangleIndexBufferSize = indexCount * ffi.sizeof("uint32_t") -- TBD this seems sketchy, review on main
	printf("Uploading geometry: %d triangle indices (%s)", indexCount, filesize(triangleIndexBufferSize))
	local triangleIndicesBuffer = Buffer:CreateIndexBuffer(self.wgpuDevice, indices)

	local diffuseTextureCoordsCount = isCGND and mesh.numDiffuseTextureCoords or #mesh.diffuseTextureCoords / 2
	local diffuseTextureCoordsBufferSize = diffuseTextureCoordsCount * 2 * ffi.sizeof("float")
	printf(
		"Uploading geometry: %d diffuse texture coordinates (%s)",
		diffuseTextureCoordsCount,
		filesize(diffuseTextureCoordsBufferSize)
	)
	local diffuseTextureCoordinatesBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, mesh.diffuseTextureCoords)

	local normalBufferSize = normalCount * ffi.sizeof("float")
	printf("Uploading geometry: %d surface normals (%s)", normalCount, filesize(normalBufferSize))
	local surfaceNormalsBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, mesh.surfaceNormals)

	if rawget(mesh, "lightmapTextureCoords") then
		local lightmapTextureCoordsCount = isCGND and mesh.numLightmapTextureCoords	or #mesh.lightmapTextureCoords / 2
		local lightmapTextureCoordsBufferSize = lightmapTextureCoordsCount * 2 * ffi.sizeof("float")
		printf(
			"Uploading geometry: %d lightmap texture coordinates (%s)",
			lightmapTextureCoordsCount,
			filesize(lightmapTextureCoordsBufferSize)
		)
		local lightmapTextureCoordinatesBuffer = Buffer:CreateVertexBuffer(self.wgpuDevice, mesh.lightmapTextureCoords)

		mesh.lightmapTexCoordsBuffer = lightmapTextureCoordinatesBuffer
	end

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

	local isCGND = type(positions) == "cdata"

	local vertexCount = isCGND and mesh.numVertexPositions or #positions / 3
	local indexCount = isCGND and mesh.numTriangleConnections or #indices / 3
	local numVertexColors = isCGND and mesh.numVertexColors or #colors / 3
	local numSurfaceNormals = isCGND and mesh.numSurfaceNormals or #normals / 3 -- TODO normalCount

	if (vertexCount * 3 % 3) ~= 0 then
		error(self.errorStrings.INVALID_VERTEX_BUFFER, 0)
	end

	if (numVertexColors * 3) % 3 ~= 0 then
		error(self.errorStrings.INVALID_COLOR_BUFFER, 0)
	end

	if (indexCount * 3) % 3 ~= 0 then
		error(self.errorStrings.INVALID_INDEX_BUFFER, 0)
	end

	if (numSurfaceNormals * 3) % 3 ~= 0 then
		error(self.errorStrings.INVALID_NORMAL_BUFFER, 0)
	end

	if vertexCount ~= numVertexColors then
		error(self.errorStrings.INCOMPLETE_COLOR_BUFFER, 0)
	end

	if vertexCount ~= numSurfaceNormals then
		error(self.errorStrings.INCOMPLETE_NORMAL_BUFFER, 0)
	end

	if mesh.diffuseTextureCoords then
		local diffuseTextureCoordsCount = isCGND and mesh.numDiffuseTextureCoords or #mesh.diffuseTextureCoords / 2

		-- local diffuseTextureCoordsCount = #mesh.diffuseTextureCoords / 2
		if (diffuseTextureCoordsCount * 2) % 2 ~= 0 then
			error(self.errorStrings.INVALID_UV_BUFFER, 0)
		end

		if vertexCount ~= diffuseTextureCoordsCount then
			error(self.errorStrings.INCOMPLETE_UV_BUFFER, 0)
		end
	end

	if rawget(mesh, "lightmapTextureCoords") then
		local lightmapTextureCoordsCount = isCGND and mesh.numLightmapTextureCoords	or #mesh.lightmapTextureCoords / 2

		-- local lightmapTextureCoordsCount = #mesh.lightmapTextureCoords / 2
		if (lightmapTextureCoordsCount * 2) % 2 ~= 0 then
			error(self.errorStrings.INVALID_LIGHTMAP_UV_BUFFER, 0)
		end

		if vertexCount ~= lightmapTextureCoordsCount then
			error(self.errorStrings.INCOMPLETE_LIGHTMAP_UV_BUFFER, 0)
		end
	end
end

function Renderer:DestroyMeshGeometry(mesh)
	-- Needs streamlining (later)
	Buffer:Destroy(rawget(mesh, "vertexBuffer"))
	Buffer:Destroy(rawget(mesh, "colorBuffer"))
	Buffer:Destroy(rawget(mesh, "indexBuffer"))
	Buffer:Destroy(rawget(mesh, "diffuseTexCoordsBuffer"))
	Buffer:Destroy(rawget(mesh, "lightmapTexCoordsBuffer"))
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
	perSceneUniformData.directionalLightDirectionX = self.directionalLight.rayDirection.x
	perSceneUniformData.directionalLightDirectionY = self.directionalLight.rayDirection.y
	perSceneUniformData.directionalLightDirectionZ = self.directionalLight.rayDirection.z
	perSceneUniformData.directionalLightRed = self.directionalLight.red
	perSceneUniformData.directionalLightGreen = self.directionalLight.green
	perSceneUniformData.directionalLightBlue = self.directionalLight.blue
	perSceneUniformData.directionalLightIntensity = self.directionalLight.intensity
	assert(self.directionalLight.intensity == 1, "The directional light must always be at full intensity")
	perSceneUniformData.cameraWorldPosition.x = cameraWorldPosition.x
	perSceneUniformData.cameraWorldPosition.y = cameraWorldPosition.y
	perSceneUniformData.cameraWorldPosition.z = cameraWorldPosition.z

	if not self.fogParameters then
		-- Disabling the effect in a roundabout way to avoid a new uniform just for this
		perSceneUniformData.fogNearLimit = 10
		perSceneUniformData.fogFarLimit = 1
	else
		local viewDistance = C_Camera.farPlaneDistanceInWorldUnits - C_Camera.nearPlaneDistanceInWorldUnits
		perSceneUniformData.fogNearLimit = self.fogParameters.near * viewDistance
		perSceneUniformData.fogFarLimit = self.fogParameters.far * viewDistance
		perSceneUniformData.fogColorRed = self.fogParameters.color.red
		perSceneUniformData.fogColorGreen = self.fogParameters.color.green
		perSceneUniformData.fogColorBlue = self.fogParameters.color.blue
	end

	Queue:WriteBuffer(
		Device:GetQueue(self.wgpuDevice),
		self.cameraViewportUniform.buffer,
		0,
		perSceneUniformData,
		ffi.sizeof(perSceneUniformData)
	)
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

function Renderer:CreateTextureFromImage(rgbaImageBytes, width, height)
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

		-- Process diffuse texture(s)
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

		-- Process lightmap texture
		local image = rawget(mesh, "lightmapTextureImage")
		if image then
			self:DebugDumpTextures(mesh, format("lightmap-texture-%s-in.png", scene.mapID))
			local wgpuTextureHandle = self:CreateTextureFromImage(image.rgbaImageBytes, image.width, image.height)
			self:DebugDumpTextures(mesh, format("lightmap-texture-%s-out.png", scene.mapID))
			mesh.material:AssignLightmapTexture(wgpuTextureHandle)
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

	if scene.directionalLight then
		self.directionalLight = scene.directionalLight
	else
		self.directionalLight.red = DEFAULT_SUNLIGHT_COLOR.red
		self.directionalLight.green = DEFAULT_SUNLIGHT_COLOR.green
		self.directionalLight.blue = DEFAULT_SUNLIGHT_COLOR.blue
		self.directionalLight.intensity = DEFAULT_SUNLIGHT_COLOR.intensity
		self.directionalLight.rayDirection = DEFAULT_SUNLIGHT_DIRECTION
	end

	self.fogParameters = scene.fogParameters
end

function Renderer:DebugDumpTextures(mesh, fileName)
	if not Renderer.DEBUG_DISCARDED_BACKGROUND_PIXELS then
		return
	end

	if not mesh then
		return
	end

	local diffuseTextureImage = mesh.diffuseTextureImage
	C_FileSystem.MakeDirectoryTree("Exports")
	local pngBytes = C_ImageProcessing.EncodePNG(
		diffuseTextureImage.rgbaImageBytes,
		diffuseTextureImage.width,
		diffuseTextureImage.height
	)
	C_FileSystem.WriteFile(path.join("Exports", fileName), pngBytes)

	local lightmapTextureImage = rawget(mesh, "lightmapTextureImage")
	if not lightmapTextureImage then
		return
	end

	C_FileSystem.MakeDirectoryTree("Exports")
	pngBytes = C_ImageProcessing.EncodePNG(
		lightmapTextureImage.rgbaImageBytes,
		lightmapTextureImage.width,
		lightmapTextureImage.height
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

	self.directionalLight.red = DEFAULT_SUNLIGHT_COLOR.red
	self.directionalLight.green = DEFAULT_SUNLIGHT_COLOR.green
	self.directionalLight.blue = DEFAULT_SUNLIGHT_COLOR.blue
	self.directionalLight.intensity = DEFAULT_SUNLIGHT_COLOR.intensity
	self.directionalLight.rayDirection.x = DEFAULT_SUNLIGHT_DIRECTION.x
	self.directionalLight.rayDirection.y = DEFAULT_SUNLIGHT_DIRECTION.y
	self.directionalLight.rayDirection.z = DEFAULT_SUNLIGHT_DIRECTION.z

	self.fogParameters = nil
end

return Renderer
