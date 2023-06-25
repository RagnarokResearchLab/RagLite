local bit = require("bit")
local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("webgpu")
local validation = require("validation")

local gpu = require("Core.NativeClient.gpu")

local assert = assert
local ipairs = ipairs

local binary_not = bit.bnot
local ffi_new = ffi.new
local table_insert = table.insert

local Renderer = {
	clearColorRGBA = { 0, 0.5, 1, 1.0 },
	pipelines = {},
}

function Renderer:CreateGraphicsContext(nativeWindowHandle)
	validation.validateStruct(nativeWindowHandle, "nativeWindowHandle")

	local instance, instanceDescriptor = gpu.createInstance()
	local adapter = gpu.requestAdapter(instance, nativeWindowHandle)
	local logicalDevice, deviceDescriptor = gpu.requestLogicalDevice(adapter)

	local context = {
		window = nativeWindowHandle,
		instance = instance,
		instanceDescriptor = instanceDescriptor,
		adapter = adapter,
		device = logicalDevice,
		deviceDescriptor = deviceDescriptor,
	}

	-- In order to support window resizing, we'll need to re-create this on the fly (later)
	context.swapChain = self:CreateSwapchain(context)

	return context
end

function Renderer:CreateSwapchain(context)
	local swapChainDescriptor = ffi.new("WGPUSwapChainDescriptor")

	-- The underlying framebuffer may be different if DPI scaling is applied, but let's ignore that for now
	local contentWidthInPixels = ffi.new("int[1]")
	local contentHeightInPixels = ffi.new("int[1]")
	glfw.bindings.glfw_get_window_size(context.window, contentWidthInPixels, contentHeightInPixels)

	swapChainDescriptor.width = contentWidthInPixels[0]
	swapChainDescriptor.height = contentHeightInPixels[0]

	local surface = glfw.bindings.glfw_get_wgpu_surface(context.instance, context.window)
	local textureFormat = webgpu.bindings.wgpu_surface_get_preferred_format(surface, context.adapter)

	swapChainDescriptor.format = textureFormat
	swapChainDescriptor.usage = ffi.C.WGPUTextureUsage_RenderAttachment
	swapChainDescriptor.presentMode = ffi.C.WGPUPresentMode_Fifo

	return webgpu.bindings.wgpu_device_create_swap_chain(context.device, surface, swapChainDescriptor)
end

function Renderer:CreatePipelineConfigurations(graphicsContext)
	-- This is just a placeholder; eventually there should be real pipelines here
	local examplePipeline = Renderer:CreateBasicTriangleDrawingPipeline(graphicsContext)
	table_insert(self.pipelines, examplePipeline)
end

function Renderer:CreateBasicTriangleDrawingPipeline(graphicsContext)
	local surface = glfw.bindings.glfw_get_wgpu_surface(graphicsContext.instance, graphicsContext.window)
	-- print(surface)
	local descriptor = ffi.new("WGPURenderPipelineDescriptor")
	local pipelineDesc = descriptor

	-- Setup basic example shaders (will be replaced later with more useful ones)
	local shaderSource = [[
@vertex
fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4f {
	var p = vec2f(0.0, 0.0);
	if (in_vertex_index == 0u) {
		p = vec2f(-0.5, -0.5);
	} else if (in_vertex_index == 1u) {
		p = vec2f(0.5, -0.5);
	} else {
		p = vec2f(0.0, 0.5);
	}
	return vec4f(p, 0.0, 1.0);
}

@fragment
fn fs_main() -> @location(0) vec4f {
	return vec4f(1.0, 0.4, 1.0, 0.3);
}

	]]
	--C_FileSystem.ReadFile("Core/NativeClient/Shaders/BasicTriangleShader.wgsl")

	local shaderDesc = ffi.new("WGPUShaderModuleDescriptor")
	shaderDesc.hintCount = 0
	shaderDesc.hints = ffi.NULL
	local shaderCodeDesc = ffi.new("WGPUShaderModuleWGSLDescriptor")
	shaderCodeDesc.chain.next = ffi.NULL
	shaderCodeDesc.chain.sType = ffi.C.WGPUSType_ShaderModuleWGSLDescriptor
	shaderDesc.nextInChain = shaderCodeDesc.chain
	shaderCodeDesc.code = shaderSource

	local shaderModule = webgpu.bindings.wgpu_device_create_shader_module(graphicsContext.device, shaderDesc)

	-- Configure vertex processing pipeline (vertex fetch/vertex shader stages)
	pipelineDesc.vertex.bufferCount = 0
	pipelineDesc.vertex.buffers = ffi.NULL
	pipelineDesc.vertex.module = shaderModule
	pipelineDesc.vertex.entryPoint = "vs_main"
	pipelineDesc.vertex.constantCount = 0
	pipelineDesc.vertex.constants = ffi.NULL

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
	fragmentState.constants = ffi.NULL

	pipelineDesc.fragment = fragmentState

	-- Configure alpha blending pipeline (blending stage)
	local blendState = ffi.new("WGPUBlendState")

	blendState.color.srcFactor = ffi.C.WGPUBlendFactor_SrcAlpha
	blendState.color.dstFactor = ffi.C.WGPUBlendFactor_OneMinusSrcAlpha
	blendState.color.operation = ffi.C.WGPUBlendOperation_Add

	blendState.alpha.srcFactor = ffi.C.WGPUBlendFactor_Zero
	blendState.alpha.dstFactor = ffi.C.WGPUBlendFactor_One
	blendState.alpha.operation = ffi.C.WGPUBlendOperation_Add

	local colorTarget = ffi.new("WGPUColorTargetState")
	colorTarget.format = webgpu.bindings.wgpu_surface_get_preferred_format(surface, graphicsContext.adapter)
	colorTarget.blend = blendState
	colorTarget.writeMask = ffi.C.WGPUColorWriteMask_All

	fragmentState.targetCount = 1
	fragmentState.targets = colorTarget

	pipelineDesc.depthStencil = ffi.NULL

	-- Configure multisampling (here: disabled - we don't map fragments to more than one sample)
	local samplesPerPixel = 1
	local bitmaskAllBitsEnabled = binary_not(0)
	pipelineDesc.multisample.count = samplesPerPixel
	pipelineDesc.multisample.mask = bitmaskAllBitsEnabled
	pipelineDesc.multisample.alphaToCoverageEnabled = false

	return webgpu.bindings.wgpu_device_create_render_pipeline(graphicsContext.device, descriptor)
end

function Renderer:RenderNextFrame(graphicsContext)
	local logicalDevice = graphicsContext.device
	local swapChain = graphicsContext.swapChain
	local nextTextureView = webgpu.bindings.wgpu_swap_chain_get_current_texture_view(swapChain)

	-- Since resizing isn't yet supported, fail loudly if somehow that is actually done (i.e., not prevented by GLFW)
	assert(nextTextureView, "Cannot acquire next swap chain texture (window surface has changed?)")

	local commandEncoderDescriptor = ffi_new("WGPUCommandEncoderDescriptor")
	local commandEncoder = webgpu.bindings.wgpu_device_create_command_encoder(logicalDevice, commandEncoderDescriptor)

	local renderPassDescriptor = ffi_new("WGPURenderPassDescriptor")

	-- Clearing is a built-in mechanism of the render pass
	local renderPassColorAttachment = ffi_new("WGPURenderPassColorAttachment")
	renderPassColorAttachment.view = nextTextureView
	renderPassColorAttachment.resolveTarget = ffi.NULL
	renderPassColorAttachment.loadOp = ffi.C.WGPULoadOp_Clear
	renderPassColorAttachment.storeOp = ffi.C.WGPUStoreOp_Store
	renderPassColorAttachment.clearValue = ffi_new("WGPUColor", self.clearColorRGBA)

	renderPassDescriptor.colorAttachmentCount = 1
	renderPassDescriptor.colorAttachments = renderPassColorAttachment
	renderPassDescriptor.depthStencilAttachment = ffi.NULL
	renderPassDescriptor.timestampWriteCount = 0
	renderPassDescriptor.timestampWrites = ffi.NULL

	local renderPass = webgpu.bindings.wgpu_command_encoder_begin_render_pass(commandEncoder, renderPassDescriptor)

	for index, pipeline in ipairs(self.pipelines) do
		webgpu.bindings.wgpu_render_pass_encoder_set_pipeline(renderPass, pipeline)
		local vertexCount = 3
		local instanceCount = 1
		local firstVertexIndex = 0
		local firstInstanceIndex = 0
		webgpu.bindings.wgpu_render_pass_encoder_draw(
			renderPass,
			vertexCount,
			instanceCount,
			firstVertexIndex,
			firstInstanceIndex
		)
	end

	webgpu.bindings.wgpu_render_pass_encoder_end(renderPass)

	local commandBufferDescriptor = ffi_new("WGPUCommandBufferDescriptor")
	local commandBuffer = webgpu.bindings.wgpu_command_encoder_finish(commandEncoder, commandBufferDescriptor)

	local queue = webgpu.bindings.wgpu_device_get_queue(logicalDevice)

	-- The WebGPU API expects an array here, but currently this renderer only supports a single buffer (to keep things simple)
	local commandBuffers = ffi_new("WGPUCommandBuffer[1]", commandBuffer)
	webgpu.bindings.wgpu_queue_submit(queue, 1, commandBuffers)

	-- webgpu.bindings.wgpu_instance_process_events(graphicsContext.instance)
	webgpu.bindings.wgpu_swap_chain_present(swapChain)
end

return Renderer
