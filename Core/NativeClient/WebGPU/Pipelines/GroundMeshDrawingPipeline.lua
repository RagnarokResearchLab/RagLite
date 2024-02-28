local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("wgpu")

local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local Device = require("Core.NativeClient.WebGPU.Device")
local UniformBuffer = require("Core.NativeClient.WebGPU.UniformBuffer")

local binary_not = bit.bnot
local new = ffi.new

local GroundMeshDrawingPipeline = {
	WGSL_SHADER_SOURCE_LOCATION = "Core/NativeClient/WebGPU/Shaders/TerrainGeometryShader.wgsl",
}

function GroundMeshDrawingPipeline:Construct(wgpuDeviceHandle, textureFormatID)
	printf("Creating render pipeline with texture format %d", tonumber(textureFormatID))
	self.wgpuDevice = wgpuDeviceHandle

	local sharedShaderModule = self:CreateShaderModule(wgpuDeviceHandle)
	local renderPipelineDescriptor = new("WGPURenderPipelineDescriptor", {
		vertex = {
			bufferCount = 5, -- Vertex positions, colors, diffuse UVs, normals, lightmap UVs
			module = sharedShaderModule,
			entryPoint = "vs_main",
			constantCount = 0,
			buffers = BasicTriangleDrawingPipeline:CreateVertexBufferLayout(),
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
						alpha = {
							srcFactor = ffi.C.WGPUBlendFactor_One,
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
	local pipelineLayoutDescriptor = new("WGPUPipelineLayoutDescriptor", {
		bindGroupLayoutCount = 3,
		bindGroupLayouts = new("WGPUBindGroupLayout[?]", 3, {
			UniformBuffer.cameraBindGroupLayout,
			UniformBuffer.materialBindGroupLayout,
			UniformBuffer.materialBindGroupLayout, -- Re-used for lightmaps
		}),
	})

	renderPipelineDescriptor.layout =
		webgpu.bindings.wgpu_device_create_pipeline_layout(wgpuDeviceHandle, pipelineLayoutDescriptor)

	local wgpuPipeline = webgpu.bindings.wgpu_device_create_render_pipeline(wgpuDeviceHandle, renderPipelineDescriptor)

	local instance = {
		wgpuPipeline = wgpuPipeline,
	}

	local inheritanceLookupMetatable = {
		__index = self,
	}
	setmetatable(instance, inheritanceLookupMetatable)

	return instance
end

function GroundMeshDrawingPipeline:CreateShaderModule(wgpuDeviceHandle)
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

class("GroundMeshDrawingPipeline", GroundMeshDrawingPipeline)

return GroundMeshDrawingPipeline
