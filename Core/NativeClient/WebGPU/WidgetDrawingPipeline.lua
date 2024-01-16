local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local Device = require("Core.NativeClient.WebGPU.Device")

local binary_not = bit.bnot
local new = ffi.new
local sizeof = ffi.sizeof

local WidgetDrawingPipeline = {
	displayName = "Basic Triangle Drawing Pipeline",
	WGSL_SHADER_SOURCE_LOCATION = "Core/NativeClient/Shaders/UserInterfaceShader.wgsl",
	MAX_WIDGET_COUNT = 2048, -- The default maxUniformBufferBindingSize allows for this many without optimizing further/removing padding/using other buffer types or even hardware instacing for the UI
}

function WidgetDrawingPipeline:Construct(wgpuDeviceHandle, textureFormatID)
	printf("Creating render pipeline with texture format %d", tonumber(textureFormatID))
	self.wgpuDevice = wgpuDeviceHandle

	local sharedShaderModule = self:CreateShaderModule(wgpuDeviceHandle)
	local renderPipelineDescriptor = new("WGPURenderPipelineDescriptor", {
		vertex = {
			bufferCount = 1, -- Interleaved (Rml::Vertex format)
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
		multisample = {
			count = 1, -- Samples per pixel (1 = currently disabled)
			mask = binary_not(0), -- All bits enabled (bitmask = 0xFFFFFFFF)
			alphaToCoverageEnabled = false,
		},
	})

	-- Configure resource layout for the vertex shader
	local cameraBindGroupLayout, cameraBindGroupLayoutDescriptor = self:CreateCameraBindGroupLayout(wgpuDeviceHandle)
	local transformBindGroupLayout, transformBindGroupLayoutDescriptor =
		self:CreateTransformBindGroupLayout(wgpuDeviceHandle)
	local materialBindGroupLayout, materialBindGroupLayoutDescriptor =
		self:CreateMaterialBindGroupLayout(wgpuDeviceHandle)
	self.wgpuCameraBindGroupLayout = cameraBindGroupLayout
	self.wgpuCameraBindGroupLayoutDescriptor = cameraBindGroupLayoutDescriptor
	self.wgpuTransformBindGroupLayout = transformBindGroupLayout
	self.wgpuTransformBindGroupLayoutDescriptor = transformBindGroupLayoutDescriptor
	self.wgpuMaterialBindGroupLayout = materialBindGroupLayout
	self.wgpuMaterialBindGroupLayoutDescriptor = materialBindGroupLayoutDescriptor

	local pipelineLayoutDescriptor = new("WGPUPipelineLayoutDescriptor", {
		bindGroupLayoutCount = 3,
		bindGroupLayouts = new("WGPUBindGroupLayout[?]", 3, {
			cameraBindGroupLayout,
			materialBindGroupLayout,
			transformBindGroupLayout,
		}),
	})

	renderPipelineDescriptor.layout =
		webgpu.bindings.wgpu_device_create_pipeline_layout(wgpuDeviceHandle, pipelineLayoutDescriptor)

	return webgpu.bindings.wgpu_device_create_render_pipeline(wgpuDeviceHandle, renderPipelineDescriptor)
end

function WidgetDrawingPipeline:CreateShaderModule(wgpuDeviceHandle)
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

function WidgetDrawingPipeline:CreateVertexBufferLayout()
	local vertexPositionsLayout = new("WGPUVertexBufferLayout", {
		attributeCount = 3, -- Position, color, uvs
		attributes = new("WGPUVertexAttribute[?]", 3, {
			{
				shaderLocation = 0,
				format = ffi.C.WGPUVertexFormat_Float32x2,
				offset = 0,
			},
			{
				shaderLocation = 1,
				format = ffi.C.WGPUVertexFormat_Uint32,
				offset = 2 * ffi.sizeof("float"),
			},
			{
				shaderLocation = 2,
				format = ffi.C.WGPUVertexFormat_Float32x2,
				offset = 2 * ffi.sizeof("float") + 1 * ffi.sizeof("uint32_t"),
			},
		}),
		arrayStride = 20, -- sizeof(Rml::Vertex)
		stepMode = ffi.C.WGPUVertexStepMode_Vertex,
	})

	return new("WGPUVertexBufferLayout[?]", 1, {
		vertexPositionsLayout,
	})
end

function WidgetDrawingPipeline:CreateCameraBindGroupLayout(wgpuDeviceHandle)
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

function WidgetDrawingPipeline:CreateMaterialBindGroupLayout(wgpuDeviceHandle)
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

function WidgetDrawingPipeline:CreateTransformBindGroupLayout(wgpuDeviceHandle)
	local bindGroupLayoutDescriptor = new("WGPUBindGroupLayoutDescriptor", {
		entryCount = 1,
		entries = new("WGPUBindGroupLayoutEntry[?]", 2, {
			new("WGPUBindGroupLayoutEntry", {
				binding = 0,
				visibility = bit.bor(ffi.C.WGPUShaderStage_Vertex, ffi.C.WGPUShaderStage_Fragment),
				buffer = {
					type = ffi.C.WGPUBufferBindingType_Uniform,
					hasDynamicOffset = true, -- Required to access transform slots in the preallocated buffer
					minBindingSize = sizeof("mesh_uniform_t"), -- Only bind a part as it's offset for each object
				},
				sampler = {
					type = ffi.C.WGPUSamplerBindingType_Undefined,
				},
				storageTexture = {
					access = ffi.C.WGPUStorageTextureAccess_Undefined,
					format = ffi.C.WGPUTextureFormat_Undefined,
					viewDimension = ffi.C.WGPUTextureViewDimension_Undefined,
				},
				texture = {
					sampleType = ffi.C.WGPUTextureSampleType_Undefined,
					viewDimension = ffi.C.WGPUTextureViewDimension_Undefined,
				},
			}),
		}),
	})

	local bindGroupLayout =
		webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDeviceHandle, bindGroupLayoutDescriptor)

	return bindGroupLayout, bindGroupLayoutDescriptor
end

WidgetDrawingPipeline.__call = WidgetDrawingPipeline.Construct
setmetatable(WidgetDrawingPipeline, WidgetDrawingPipeline)

return WidgetDrawingPipeline
