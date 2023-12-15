local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local Device = require("Core.NativeClient.WebGPU.Device")

local binary_not = bit.bnot

local BasicTriangleDrawingPipeline = {
	displayName = "Basic Triangle Drawing Pipeline",
}

function BasicTriangleDrawingPipeline:Construct(wgpuDeviceHandle, textureFormatID)
	printf("Creating render pipeline with texture format %d", tonumber(textureFormatID))
	local descriptor = ffi.new("WGPURenderPipelineDescriptor")
	local pipelineDesc = descriptor

	-- Setup basic example shaders (will be replaced later with more useful ones)
	local shaderSource = C_FileSystem.ReadFile("Core/NativeClient/Shaders/BasicTriangleShader.wgsl")

	local shaderDesc = ffi.new("WGPUShaderModuleDescriptor")
	local shaderCodeDesc = ffi.new("WGPUShaderModuleWGSLDescriptor")
	shaderCodeDesc.chain.sType = ffi.C.WGPUSType_ShaderModuleWGSLDescriptor
	shaderDesc.nextInChain = shaderCodeDesc.chain
	shaderCodeDesc.code = shaderSource

	local shaderModule = Device:CreateShaderModule(wgpuDeviceHandle, shaderDesc)

	-- Configure vertex processing pipeline (vertex fetch/vertex shader stages)
	local positionAttrib = ffi.new("WGPUVertexAttribute")
	positionAttrib.shaderLocation = 0 -- Pass as first argument
	positionAttrib.format = ffi.C.WGPUVertexFormat_Float32x3 -- Vector3D (float)
	positionAttrib.offset = 0

	local vertexBufferLayout = ffi.new("WGPUVertexBufferLayout[?]", 3) -- Positions, colors, diffuse UVs
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
	vertexBufferLayout[1].arrayStride = 3 * ffi.sizeof("float") -- sizeof(Vector3D) = color
	vertexBufferLayout[1].stepMode = ffi.C.WGPUVertexStepMode_Vertex

	local diffuseTextureCoordinatesAttribute = ffi.new("WGPUVertexAttribute")
	diffuseTextureCoordinatesAttribute.shaderLocation = 2 -- Pass as third argument
	diffuseTextureCoordinatesAttribute.format = ffi.C.WGPUVertexFormat_Float32x2 -- Vector2D (float) = UV coords
	diffuseTextureCoordinatesAttribute.offset = 0

	vertexBufferLayout[2].attributeCount = 1 -- UV
	vertexBufferLayout[2].attributes = diffuseTextureCoordinatesAttribute
	vertexBufferLayout[2].arrayStride = 2 * ffi.sizeof("float") -- sizeof(Vector2D) = uv
	vertexBufferLayout[2].stepMode = ffi.C.WGPUVertexStepMode_Vertex

	pipelineDesc.vertex.bufferCount = 3 -- positions, colors, uvs
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
	local cameraBindGroupLayout, cameraBindGroupLayoutDescriptor = self:CreateCameraBindGroupLayout(wgpuDeviceHandle)
	local materialBindGroupLayout, materialBindGroupLayoutDescriptor =
		self:CreateMaterialBindGroupLayout(wgpuDeviceHandle)
	self.wgpuCameraBindGroupLayout = cameraBindGroupLayout
	self.wgpuCameraBindGroupLayoutDescriptor = cameraBindGroupLayoutDescriptor
	self.wgpuMaterialBindGroupLayout = materialBindGroupLayout
	self.wgpuMaterialBindGroupLayoutDescriptor = materialBindGroupLayoutDescriptor

	local layoutDesc = ffi.new("WGPUPipelineLayoutDescriptor")
	layoutDesc.bindGroupLayoutCount = 2
	local bindGroupLayouts = ffi.new("WGPUBindGroupLayout[?]", 2)
	bindGroupLayouts[0] = cameraBindGroupLayout
	bindGroupLayouts[1] = materialBindGroupLayout
	layoutDesc.bindGroupLayouts = bindGroupLayouts
	local layout = webgpu.bindings.wgpu_device_create_pipeline_layout(wgpuDeviceHandle, layoutDesc)
	pipelineDesc.layout = layout

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

function BasicTriangleDrawingPipeline:CreateCameraBindGroupLayout(wgpuDeviceHandle)
	local bindGroupLayoutEntry = ffi.new("WGPUBindGroupLayoutEntry")

	bindGroupLayoutEntry.buffer.type = ffi.C.WGPUBufferBindingType_Undefined
	bindGroupLayoutEntry.buffer.hasDynamicOffset = false

	bindGroupLayoutEntry.sampler.type = ffi.C.WGPUSamplerBindingType_Undefined

	bindGroupLayoutEntry.storageTexture.access = ffi.C.WGPUStorageTextureAccess_Undefined
	bindGroupLayoutEntry.storageTexture.format = ffi.C.WGPUTextureFormat_Undefined
	bindGroupLayoutEntry.storageTexture.viewDimension = ffi.C.WGPUTextureViewDimension_Undefined

	bindGroupLayoutEntry.texture.multisampled = false
	bindGroupLayoutEntry.texture.sampleType = ffi.C.WGPUTextureSampleType_Undefined
	bindGroupLayoutEntry.texture.viewDimension = ffi.C.WGPUTextureViewDimension_Undefined

	bindGroupLayoutEntry.binding = 0
	bindGroupLayoutEntry.visibility = bit.bor(ffi.C.WGPUShaderStage_Vertex, ffi.C.WGPUShaderStage_Fragment)

	bindGroupLayoutEntry.buffer.type = ffi.C.WGPUBufferBindingType_Uniform
	bindGroupLayoutEntry.buffer.minBindingSize = ffi.sizeof("scenewide_uniform_t")

	local bindGroupLayoutDescriptor = ffi.new("WGPUBindGroupLayoutDescriptor")
	bindGroupLayoutDescriptor.entryCount = 1
	bindGroupLayoutDescriptor.entries = bindGroupLayoutEntry
	local bindGroupLayout =
		webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDeviceHandle, bindGroupLayoutDescriptor)

	return bindGroupLayout, bindGroupLayoutDescriptor
end

function BasicTriangleDrawingPipeline:CreateMaterialBindGroupLayout(wgpuDeviceHandle)
	local textureBindGroupLayoutEntry = ffi.new("WGPUBindGroupLayoutEntry")
	textureBindGroupLayoutEntry.binding = 0
	textureBindGroupLayoutEntry.visibility = ffi.C.WGPUShaderStage_Fragment

	textureBindGroupLayoutEntry.texture.sampleType = ffi.C.WGPUTextureSampleType_Float
	textureBindGroupLayoutEntry.texture.viewDimension = ffi.C.WGPUTextureViewDimension_2D
	textureBindGroupLayoutEntry.texture.multisampled = false

	local samplerBindGroupLayoutEntry = ffi.new("WGPUBindGroupLayoutEntry")
	samplerBindGroupLayoutEntry.binding = 1
	samplerBindGroupLayoutEntry.visibility = ffi.C.WGPUShaderStage_Fragment
	samplerBindGroupLayoutEntry.sampler.type = ffi.C.WGPUSamplerBindingType_Filtering

	local bindGroupLayoutEntries = ffi.new("WGPUBindGroupLayoutEntry[?]", 2)
	bindGroupLayoutEntries[0] = textureBindGroupLayoutEntry
	bindGroupLayoutEntries[1] = samplerBindGroupLayoutEntry

	local bindGroupLayoutDescriptor = ffi.new("WGPUBindGroupLayoutDescriptor")
	bindGroupLayoutDescriptor.entryCount = 2
	bindGroupLayoutDescriptor.entries = bindGroupLayoutEntries
	local bindGroupLayout =
		webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDeviceHandle, bindGroupLayoutDescriptor)

	return bindGroupLayout, bindGroupLayoutDescriptor
end

BasicTriangleDrawingPipeline.__call = BasicTriangleDrawingPipeline.Construct
setmetatable(BasicTriangleDrawingPipeline, BasicTriangleDrawingPipeline)

return BasicTriangleDrawingPipeline
