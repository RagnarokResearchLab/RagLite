local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local Device = require("Core.NativeClient.WebGPU.Device")

local binary_not = bit.bnot
local new = ffi.new
local sizeof = ffi.sizeof

local BasicTriangleDrawingPipeline = {
	displayName = "Basic Triangle Drawing Pipeline",
	WGSL_SHADER_SOURCE_LOCATION = "Core/NativeClient/Shaders/BasicTriangleShader.wgsl",
}

function BasicTriangleDrawingPipeline:Construct(wgpuDeviceHandle, textureFormatID)
	printf("Creating render pipeline with texture format %d", tonumber(textureFormatID))
	self.wgpuDevice = wgpuDeviceHandle

	local sharedShaderModule = self:CreateShaderModule(wgpuDeviceHandle)
	local renderPipelineDescriptor = new("WGPURenderPipelineDescriptor", {
		vertex = {
			bufferCount = 3, -- Vertex positions, colors, diffuse UVs
			module = sharedShaderModule,
			entryPoint = "vs_main",
			constantCount = 0,
			buffers = self:CreateVertexBufferLayout(),
		},
		primitive = {
			topology = ffi.C.WGPUPrimitiveTopology_TriangleList,
			stripIndexFormat = ffi.C.WGPUIndexFormat_Undefined,
			frontFace = ffi.C.WGPUFrontFace_CCW,
			cullMode = ffi.C.WGPUCullMode_None,
		},
		fragment = new("WGPUFragmentState", {
			module = sharedShaderModule,
			entryPoint = "fs_main",
			constantCount = 0,
			targetCount = 1,
			targets = new("WGPUColorTargetState[?]", 1, {
				new("WGPUColorTargetState", {
					format = textureFormatID,
					blend = new("WGPUBlendState", {
						color = {
							srcFactor = ffi.C.WGPUBlendFactor_SrcAlpha,
							dstFactor = ffi.C.WGPUBlendFactor_OneMinusSrcAlpha,
							operation = ffi.C.WGPUBlendOperation_Add,
						},
					}),
					writeMask = ffi.C.WGPUColorWriteMask_All,
				}),
			}),
		}),
		depthStencil = new("WGPUDepthStencilState", {
			format = ffi.C.WGPUTextureFormat_Depth24Plus,
			depthWriteEnabled = true,
			depthCompare = ffi.C.WGPUCompareFunction_Less,
			stencilReadMask = 0,
			stencilWriteMask = 0,
			depthBias = 0,
			depthBiasSlopeScale = 0,
			depthBiasClamp = 0,
			stencilFront = {
				compare = ffi.C.WGPUCompareFunction_Always,
				failOp = ffi.C.WGPUStencilOperation_Keep,
				depthFailOp = ffi.C.WGPUStencilOperation_Keep,
				passOp = ffi.C.WGPUStencilOperation_Keep,
			},
			stencilBack = {
				compare = ffi.C.WGPUCompareFunction_Always,
				failOp = ffi.C.WGPUStencilOperation_Keep,
				depthFailOp = ffi.C.WGPUStencilOperation_Keep,
				passOp = ffi.C.WGPUStencilOperation_Keep,
			},
		}),
		multisample = {
			count = 1, -- Samples per pixel (1 = currently disabled)
			mask = binary_not(0), -- All bits enabled (bitmask = 0xFFFFFFFF)
			alphaToCoverageEnabled = false,
		},
	})

	-- Configure resource layout for the vertex shader
	local cameraBindGroupLayout, cameraBindGroupLayoutDescriptor = self:CreateCameraBindGroupLayout(wgpuDeviceHandle)
	local materialBindGroupLayout, materialBindGroupLayoutDescriptor =
		self:CreateMaterialBindGroupLayout(wgpuDeviceHandle)
	self.wgpuCameraBindGroupLayout = cameraBindGroupLayout
	self.wgpuCameraBindGroupLayoutDescriptor = cameraBindGroupLayoutDescriptor
	self.wgpuMaterialBindGroupLayout = materialBindGroupLayout
	self.wgpuMaterialBindGroupLayoutDescriptor = materialBindGroupLayoutDescriptor

	local pipelineLayoutDescriptor = new("WGPUPipelineLayoutDescriptor", {
		bindGroupLayoutCount = 2,
		bindGroupLayouts = new("WGPUBindGroupLayout[?]", 2, {
			cameraBindGroupLayout,
			materialBindGroupLayout,
		}),
	})

	renderPipelineDescriptor.layout =
		webgpu.bindings.wgpu_device_create_pipeline_layout(wgpuDeviceHandle, pipelineLayoutDescriptor)

	return webgpu.bindings.wgpu_device_create_render_pipeline(wgpuDeviceHandle, renderPipelineDescriptor)
end

function BasicTriangleDrawingPipeline:CreateShaderModule(wgpuDeviceHandle)
	local shaderCodeDescriptor = new("WGPUShaderModuleWGSLDescriptor", {
		code = C_FileSystem.ReadFile(self.WGSL_SHADER_SOURCE_LOCATION),
		chain = {
			sType = ffi.C.WGPUSType_ShaderModuleWGSLDescriptor,
		},
	})
	local shaderModuleDescriptor = new("WGPUShaderModuleDescriptor", {
		nextInChain = shaderCodeDescriptor.chain,
	})

	return Device:CreateShaderModule(wgpuDeviceHandle, shaderModuleDescriptor)
end

function BasicTriangleDrawingPipeline:CreateVertexBufferLayout()
	local vertexPositionsLayout = new("WGPUVertexBufferLayout", {
		attributeCount = 1, -- Position
		attributes = new("WGPUVertexAttribute", {
			shaderLocation = 0, -- Pass as first argument
			format = ffi.C.WGPUVertexFormat_Float32x3,
			offset = 0,
		}),
		arrayStride = 3 * sizeof("float"), -- sizeof(Vector3D) = position
		stepMode = ffi.C.WGPUVertexStepMode_Vertex,
	})

	local vertexColorsLayout = new("WGPUVertexBufferLayout", {
		attributeCount = 1, -- Color
		attributes = new("WGPUVertexAttribute", {
			shaderLocation = 1, -- Pass as second argument
			format = ffi.C.WGPUVertexFormat_Float32x3, -- Vector3D (float) = RGB color
			offset = 0,
		}),
		arrayStride = 3 * sizeof("float"), -- sizeof(Vector3D) = color
		stepMode = ffi.C.WGPUVertexStepMode_Vertex,
	})

	local diffuseTexCoordsLayout = new("WGPUVertexBufferLayout", {
		attributeCount = 1, -- UV
		attributes = new("WGPUVertexAttribute", {
			shaderLocation = 2, -- Pass as third argument
			format = ffi.C.WGPUVertexFormat_Float32x2, -- Vector2D (float) = UV coords
			offset = 0,
		}),
		arrayStride = 2 * sizeof("float"), -- sizeof(Vector2D) = uv
		stepMode = ffi.C.WGPUVertexStepMode_Vertex,
	})

	return new("WGPUVertexBufferLayout[?]", 3, {
		vertexPositionsLayout,
		vertexColorsLayout,
		diffuseTexCoordsLayout,
	})
end

function BasicTriangleDrawingPipeline:CreateCameraBindGroupLayout(wgpuDeviceHandle)
	local bindGroupLayoutDescriptor = new("WGPUBindGroupLayoutDescriptor", {
		entryCount = 1,
		entries = new("WGPUBindGroupLayoutEntry[?]", 1, {
			new("WGPUBindGroupLayoutEntry", {
				binding = 0,
				visibility = bit.bor(ffi.C.WGPUShaderStage_Vertex, ffi.C.WGPUShaderStage_Fragment),
				buffer = {
					type = ffi.C.WGPUBufferBindingType_Uniform,
					minBindingSize = sizeof("scenewide_uniform_t"),
				},
			}),
		}),
	})

	local bindGroupLayout =
		webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDeviceHandle, bindGroupLayoutDescriptor)

	return bindGroupLayout, bindGroupLayoutDescriptor
end

function BasicTriangleDrawingPipeline:CreateMaterialBindGroupLayout(wgpuDeviceHandle)
	local bindGroupLayoutDescriptor = new("WGPUBindGroupLayoutDescriptor", {
		entryCount = 2,
		entries = new("WGPUBindGroupLayoutEntry[?]", 2, {
			new("WGPUBindGroupLayoutEntry", {
				binding = 0,
				visibility = ffi.C.WGPUShaderStage_Fragment,
				texture = {
					sampleType = ffi.C.WGPUTextureSampleType_Float,
					viewDimension = ffi.C.WGPUTextureViewDimension_2D,
				},
			}),
			new("WGPUBindGroupLayoutEntry", {
				binding = 1,
				visibility = ffi.C.WGPUShaderStage_Fragment,
				sampler = {
					type = ffi.C.WGPUSamplerBindingType_Filtering,
				},
			}),
		}),
	})

	local bindGroupLayout =
		webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDeviceHandle, bindGroupLayoutDescriptor)

	return bindGroupLayout, bindGroupLayoutDescriptor
end

BasicTriangleDrawingPipeline.__call = BasicTriangleDrawingPipeline.Construct
setmetatable(BasicTriangleDrawingPipeline, BasicTriangleDrawingPipeline)

return BasicTriangleDrawingPipeline
