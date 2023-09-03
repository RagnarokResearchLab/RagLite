local bit = require("bit")
local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("webgpu")
local uv = require("uv")
local validation = require("validation")

local gpu = require("Core.NativeClient.gpu")

local Buffer = require("Core.NativeClient.WebGPU.Buffer")

local _ = require("Core.VectorMath.Matrix4D") -- Only needed for the cdefs right now
local Vector3D = require("Core.VectorMath.Vector3D")
local C_Camera = require("Core.NativeClient.C_Camera")

local assert = assert
local ipairs = ipairs

local binary_not = bit.bnot
local ffi_new = ffi.new
local table_insert = table.insert

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
	pipelines = {},
	sceneObjects = {},
}

ffi.cdef(Renderer.cdefs)

assert(
	ffi.sizeof("scenewide_uniform_t") % 16 == 0,
	"Structs in uniform address space must be aligned to a 16 byte boundary (as per the WebGPU specification)"
)

function Renderer:CreateGraphicsContext(nativeWindowHandle)
	validation.validateStruct(nativeWindowHandle, "nativeWindowHandle")

	local instance, instanceDescriptor = gpu.createInstance()
	local adapter = gpu.requestAdapter(instance, nativeWindowHandle)
	local device, deviceDescriptor = gpu.requestLogicalDevice(adapter)

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

	printf("Creating swap chain with preferred texture format: %d", tonumber(textureFormat))
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
	local examplePipeline = Renderer:CreateBasicTriangleDrawingPipeline()
	table_insert(self.pipelines, examplePipeline)
end

function Renderer:CreateBasicTriangleDrawingPipeline()
	local descriptor = ffi.new("WGPURenderPipelineDescriptor")
	local pipelineDesc = descriptor

	-- Setup basic example shaders (will be replaced later with more useful ones)
	local shaderSource = C_FileSystem.ReadFile("Core/NativeClient/Shaders/BasicTriangleShader.wgsl")

	local shaderDesc = ffi.new("WGPUShaderModuleDescriptor")
	local shaderCodeDesc = ffi.new("WGPUShaderModuleWGSLDescriptor")
	shaderCodeDesc.chain.sType = ffi.C.WGPUSType_ShaderModuleWGSLDescriptor
	shaderDesc.nextInChain = shaderCodeDesc.chain
	shaderCodeDesc.code = shaderSource

	-- timer.start("Compiling shaders")
	local shaderModule = webgpu.bindings.wgpu_device_create_shader_module(self.wgpuDevice, shaderDesc)
	-- timer.stop("Compiling shaders")

	-- Configure vertex processing pipeline (vertex fetch/vertex shader stages)
	local positionAttrib = ffi.new("WGPUVertexAttribute")
	positionAttrib.shaderLocation = 0 -- Pass as first argument
	positionAttrib.format = ffi.C.WGPUVertexFormat_Float32x3 -- Vector3D (float)
	positionAttrib.offset = 0

	local vertexBufferLayout = ffi.new("WGPUVertexBufferLayout[?]", 2) -- Positions, colors
	vertexBufferLayout[0].attributeCount = 1 -- Position
	vertexBufferLayout[0].attributes = positionAttrib
	vertexBufferLayout[0].arrayStride = 3 * ffi.sizeof("float") -- sizeof(Vector3D) = position
	vertexBufferLayout[0].stepMode = ffi.C.WGPUVertexStepMode_Vertex

	local colorAttrib = ffi.new("WGPUVertexAttribute")
	colorAttrib.shaderLocation = 1 -- Pass as second argument
	colorAttrib.format = ffi.C.WGPUVertexFormat_Float32x3 -- Vector3D (float) = RGB color
	colorAttrib.offset = 0

	vertexBufferLayout[1].attributeCount = 1 -- Color
	vertexBufferLayout[1].attributes = colorAttrib
	vertexBufferLayout[1].arrayStride = 3 * ffi.sizeof("float") -- sizeof(Vector23) = color
	vertexBufferLayout[1].stepMode = ffi.C.WGPUVertexStepMode_Vertex

	pipelineDesc.vertex.bufferCount = 2 -- positions, colors
	pipelineDesc.vertex.module = shaderModule
	pipelineDesc.vertex.entryPoint = "vs_main"
	pipelineDesc.vertex.constantCount = 0
	pipelineDesc.vertex.buffers = vertexBufferLayout

	-- Configure primitive generation pipeline (primitive assembly/rasterization stages)
	pipelineDesc.primitive.topology = ffi.C.WGPUPrimitiveTopology_TriangleList
	pipelineDesc.primitive.stripIndexFormat = ffi.C.WGPUIndexFormat_Undefined
	pipelineDesc.primitive.frontFace = ffi.C.WGPUFrontFace_CCW
	pipelineDesc.primitive.cullMode = ffi.C.WGPUCullMode_None

	-- Configure pixel generation pipeline (fragment shader stage)
	local fragmentState = ffi.new("WGPUFragmentState")
	fragmentState.module = shaderModule
	fragmentState.entryPoint = "fs_main"
	fragmentState.constantCount = 0

	pipelineDesc.fragment = fragmentState

	-- Configure alpha blending pipeline (blending stage)
	local blendState = ffi.new("WGPUBlendState")
	local colorTarget = ffi.new("WGPUColorTargetState")
	colorTarget.format = webgpu.bindings.wgpu_surface_get_preferred_format(self.wgpuSurface, self.wgpuAdapter)
	colorTarget.blend = blendState
	colorTarget.writeMask = ffi.C.WGPUColorWriteMask_All

	fragmentState.targetCount = 1
	fragmentState.targets = colorTarget

	blendState.color.srcFactor = ffi.C.WGPUBlendFactor_SrcAlpha
	blendState.color.dstFactor = ffi.C.WGPUBlendFactor_OneMinusSrcAlpha
	blendState.color.operation = ffi.C.WGPUBlendOperation_Add

	-- Configure multisampling (here: disabled - we don't map fragments to more than one sample)
	local samplesPerPixel = 1
	local bitmaskAllBitsEnabled = binary_not(0)
	pipelineDesc.multisample.count = samplesPerPixel
	pipelineDesc.multisample.mask = bitmaskAllBitsEnabled
	pipelineDesc.multisample.alphaToCoverageEnabled = false

	-- Configure resource layout for the vertex shader (global clock, provided as uniform)
	local bindingLayout = ffi.new("WGPUBindGroupLayoutEntry")

	-- bindingLayout.buffer.nextInChain = nullptr
	bindingLayout.buffer.type = ffi.C.WGPUBufferBindingType_Undefined
	bindingLayout.buffer.hasDynamicOffset = false

	-- bindingLayout.sampler.nextInChain = nullptr
	bindingLayout.sampler.type = ffi.C.WGPUSamplerBindingType_Undefined

	-- bindingLayout.storageTexture.nextInChain = nullptr
	bindingLayout.storageTexture.access = ffi.C.WGPUStorageTextureAccess_Undefined
	bindingLayout.storageTexture.format = ffi.C.WGPUTextureFormat_Undefined
	bindingLayout.storageTexture.viewDimension = ffi.C.WGPUTextureViewDimension_Undefined

	-- bindingLayout.texture.nextInChain = nullptr
	bindingLayout.texture.multisampled = false
	bindingLayout.texture.sampleType = ffi.C.WGPUTextureSampleType_Undefined
	bindingLayout.texture.viewDimension = ffi.C.WGPUTextureViewDimension_Undefined

	bindingLayout.binding = 0
	bindingLayout.visibility = bit.bor(ffi.C.WGPUShaderStage_Vertex, ffi.C.WGPUShaderStage_Fragment)

	bindingLayout.buffer.type = ffi.C.WGPUBufferBindingType_Uniform
	bindingLayout.buffer.minBindingSize = ffi.sizeof("scenewide_uniform_t")

	local bindGroupLayoutDesc = ffi.new("WGPUBindGroupLayoutDescriptor")
	-- bindGroupLayoutDesc.nextInChain = nullptr
	bindGroupLayoutDesc.entryCount = 1
	bindGroupLayoutDesc.entries = bindingLayout
	local bindGroupLayout = webgpu.bindings.wgpu_device_create_bind_group_layout(self.wgpuDevice, bindGroupLayoutDesc)
	self.bindGroupLayoutDesc = bindGroupLayoutDesc

	local layoutDesc = ffi.new("WGPUPipelineLayoutDescriptor")
	-- layoutDesc.nextInChain = nullptr
	layoutDesc.bindGroupLayoutCount = 1
	local bindGroupLayouts = ffi.new("WGPUBindGroupLayout[?]", 1)
	bindGroupLayouts[0] = bindGroupLayout
	layoutDesc.bindGroupLayouts = bindGroupLayouts
	local layout = webgpu.bindings.wgpu_device_create_pipeline_layout(self.wgpuDevice, layoutDesc)
	pipelineDesc.layout = layout

	self.bindGroupLayout = bindGroupLayout

	-- Configure depth testing (Z buffer)
	local depthStencilState = ffi.new("WGPUDepthStencilState")
	depthStencilState.format = ffi.C.WGPUTextureFormat_Depth24Plus
	depthStencilState.depthWriteEnabled = true
	depthStencilState.depthCompare = ffi.C.WGPUCompareFunction_Less
	depthStencilState.stencilReadMask = 0
	depthStencilState.stencilWriteMask = 0
	depthStencilState.depthBias = 0
	depthStencilState.depthBiasSlopeScale = 0
	depthStencilState.depthBiasClamp = 0

	depthStencilState.stencilFront.compare = ffi.C.WGPUCompareFunction_Always
	depthStencilState.stencilFront.failOp = ffi.C.WGPUStencilOperation_Keep
	depthStencilState.stencilFront.depthFailOp = ffi.C.WGPUStencilOperation_Keep
	depthStencilState.stencilFront.passOp = ffi.C.WGPUStencilOperation_Keep

	depthStencilState.stencilBack.compare = ffi.C.WGPUCompareFunction_Always
	depthStencilState.stencilBack.failOp = ffi.C.WGPUStencilOperation_Keep
	depthStencilState.stencilBack.depthFailOp = ffi.C.WGPUStencilOperation_Keep
	depthStencilState.stencilBack.passOp = ffi.C.WGPUStencilOperation_Keep
	pipelineDesc.depthStencil = depthStencilState

	return webgpu.bindings.wgpu_device_create_render_pipeline(self.wgpuDevice, descriptor)
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

	for index, pipeline in ipairs(self.pipelines) do
		webgpu.bindings.wgpu_render_pass_encoder_set_pipeline(renderPass, pipeline)

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
	bindGroupDesc.layout = self.bindGroupLayout
	bindGroupDesc.entryCount = self.bindGroupLayoutDesc.entryCount
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
