local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local binary_not = bit.bnot

local BasicTriangleDrawingPipeline = {
	displayName = "Basic Triangle Drawing Pipeline",
}

function BasicTriangleDrawingPipeline:Construct(wgpuDeviceHandle, textureFormatID)
	local descriptor = ffi.new("WGPURenderPipelineDescriptor")
	local pipelineDesc = descriptor

	-- Setup basic example shaders (will be replaced later with more useful ones)
	local shaderSource = C_FileSystem.ReadFile("Core/NativeClient/Shaders/BasicTriangleShader.wgsl")

	local shaderDesc = ffi.new("WGPUShaderModuleDescriptor")
	local shaderCodeDesc = ffi.new("WGPUShaderModuleWGSLDescriptor")
	shaderCodeDesc.chain.sType = ffi.C.WGPUSType_ShaderModuleWGSLDescriptor
	shaderDesc.nextInChain = shaderCodeDesc.chain
	shaderCodeDesc.code = shaderSource

	local shaderModule = webgpu.bindings.wgpu_device_create_shader_module(wgpuDeviceHandle, shaderDesc)

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
	colorTarget.format = textureFormatID
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

	-- Configure resource layout for the vertex shader
	local bindingLayout = ffi.new("WGPUBindGroupLayoutEntry")

	bindingLayout.buffer.type = ffi.C.WGPUBufferBindingType_Undefined
	bindingLayout.buffer.hasDynamicOffset = false

	bindingLayout.sampler.type = ffi.C.WGPUSamplerBindingType_Undefined

	bindingLayout.storageTexture.access = ffi.C.WGPUStorageTextureAccess_Undefined
	bindingLayout.storageTexture.format = ffi.C.WGPUTextureFormat_Undefined
	bindingLayout.storageTexture.viewDimension = ffi.C.WGPUTextureViewDimension_Undefined

	bindingLayout.texture.multisampled = false
	bindingLayout.texture.sampleType = ffi.C.WGPUTextureSampleType_Undefined
	bindingLayout.texture.viewDimension = ffi.C.WGPUTextureViewDimension_Undefined

	bindingLayout.binding = 0
	bindingLayout.visibility = bit.bor(ffi.C.WGPUShaderStage_Vertex, ffi.C.WGPUShaderStage_Fragment)

	bindingLayout.buffer.type = ffi.C.WGPUBufferBindingType_Uniform
	bindingLayout.buffer.minBindingSize = ffi.sizeof("scenewide_uniform_t")

	local bindGroupLayoutDesc = ffi.new("WGPUBindGroupLayoutDescriptor")
	bindGroupLayoutDesc.entryCount = 1
	bindGroupLayoutDesc.entries = bindingLayout
	local bindGroupLayout = webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDeviceHandle, bindGroupLayoutDesc)
	self.wgpuBindGroupLayoutDescriptor = bindGroupLayoutDesc

	local layoutDesc = ffi.new("WGPUPipelineLayoutDescriptor")
	layoutDesc.bindGroupLayoutCount = 1
	local bindGroupLayouts = ffi.new("WGPUBindGroupLayout[?]", 1)
	bindGroupLayouts[0] = bindGroupLayout
	layoutDesc.bindGroupLayouts = bindGroupLayouts
	local layout = webgpu.bindings.wgpu_device_create_pipeline_layout(wgpuDeviceHandle, layoutDesc)
	pipelineDesc.layout = layout

	self.wgpuBindGroupLayout = bindGroupLayout

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

	return webgpu.bindings.wgpu_device_create_render_pipeline(wgpuDeviceHandle, descriptor)
end

BasicTriangleDrawingPipeline.__call = BasicTriangleDrawingPipeline.Construct
setmetatable(BasicTriangleDrawingPipeline, BasicTriangleDrawingPipeline)

return BasicTriangleDrawingPipeline
