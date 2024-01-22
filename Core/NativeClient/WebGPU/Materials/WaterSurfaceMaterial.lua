local WaterPlaneDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WaterPlaneDrawingPipeline")
local GPU = require("Core.NativeClient.WebGPU.GPU")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")
local Texture = require("Core.NativeClient.WebGPU.Texture")
local UniformBuffer = require("Core.NativeClient.WebGPU.UniformBuffer")

local ffi = require("ffi")
local webgpu = require("webgpu")

local WaterSurfaceMaterial = {
	pipeline = WaterPlaneDrawingPipeline,
	diffuseColor = {
		red = 1,
		green = 1,
		blue = 1,
	},
	opacity = 144 / 255, -- Source: Borf
}

function WaterSurfaceMaterial:Construct(...)
	return self.super.Construct(self, ...)
end

function WaterSurfaceMaterial:AssignDiffuseTextureArray(textureArray)
	self.materialPropertiesUniform = UniformBuffer:CreateWaterPropertiesUniform(self.wgpuDevice)
	self.diffuseTextureBindGroup = self:CreateMaterialPropertiesBindGroup(textureArray)
	self.diffuseTextureArray = textureArray
end

function WaterSurfaceMaterial:CreateMaterialPropertiesBindGroup(textureArray)
	local wgpuDevice = self.wgpuDevice

	printf("[WaterSurfaceMaterial] Creating new bind group for texture array of size %d", #textureArray)
	assert(#textureArray == GPU.MAX_TEXTURE_ARRAY_SIZE, "Incomplete texture array encountered")

	-- Create readonly view that should be accessed by a sampler
	local textureViewDescriptor = new("WGPUTextureViewDescriptor", {
		aspect = ffi.C.WGPUTextureAspect_All,
		baseArrayLayer = 0,
		arrayLayerCount = 1,
		baseMipLevel = 0,
		mipLevelCount = 1,
		dimension = ffi.C.WGPUTextureViewDimension_2D,
		format = Texture.DEFAULT_TEXTURE_FORMAT,
	})
	local textureViews = ffi.new("WGPUTextureView[?]", GPU.MAX_TEXTURE_ARRAY_SIZE)
	-- Should be replaced with views for the different water textures and not the same one
	for index = 1, GPU.MAX_TEXTURE_ARRAY_SIZE, 1 do
		local wgpuTexture = textureArray[index].wgpuTexture
		local textureView = webgpu.bindings.wgpu_texture_create_view(wgpuTexture, textureViewDescriptor)
		textureViews[index - 1] = textureView
	end

	-- Assign texture views and samplers so that they can be bound to the pipeline (in the render loop)
	local textureViewExtras = new("WGPUBindGroupEntryExtras", {
		textureViewCount = GPU.MAX_TEXTURE_ARRAY_SIZE,
		textureViews = textureViews,
		chain = {
			sType = ffi.C.WGPUSType_BindGroupEntryExtras,
		},
	})
	local textureSamplers = ffi.new("WGPUSampler[?]", GPU.MAX_TEXTURE_ARRAY_SIZE)
	-- There's no reason to use different samplers here, nor to allocate more than one (wasteful)
	for index = 1, GPU.MAX_TEXTURE_ARRAY_SIZE, 1 do
		textureSamplers[index - 1] = Texture.sharedTrilinearSampler
	end
	local textureSamplerExtras = new("WGPUBindGroupEntryExtras", {
		samplerCount = GPU.MAX_TEXTURE_ARRAY_SIZE,
		samplers = textureSamplers,
		chain = {
			sType = ffi.C.WGPUSType_BindGroupEntryExtras,
		},
	})
	local bindGroupEntries = new("WGPUBindGroupEntry[?]", 3, {
		new("WGPUBindGroupEntry", {
			binding = 0,
			nextInChain = textureViewExtras.chain, -- Required to use texture arrays (native extension)
		}),
		new("WGPUBindGroupEntry", {
			binding = 1,
			nextInChain = textureSamplerExtras.chain, -- Required to use texture arrays (native extension)
		}),
		new("WGPUBindGroupEntry", {
			binding = 2,
			buffer = self.materialPropertiesUniform.buffer,
			offset = 0,
			size = ffi.sizeof("water_uniform_t"),
		}),
	})

	local textureBindGroupDescriptor = new("WGPUBindGroupDescriptor")
	textureBindGroupDescriptor.layout = UniformBuffer.waterMaterialBindGroupLayout

	local wgpuMaterialBindGroupLayoutDescriptor = UniformBuffer.waterMaterialBindGroupLayoutDescriptor
	textureBindGroupDescriptor.entryCount = wgpuMaterialBindGroupLayoutDescriptor.entryCount
	textureBindGroupDescriptor.entries = bindGroupEntries

	return webgpu.bindings.wgpu_device_create_bind_group(wgpuDevice, textureBindGroupDescriptor)
end

class("WaterSurfaceMaterial", WaterSurfaceMaterial)
extend(WaterSurfaceMaterial, InvisibleBaseMaterial)

return WaterSurfaceMaterial
