local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local Texture = require("Core.NativeClient.WebGPU.Texture")
local UniformBuffer = require("Core.NativeClient.WebGPU.UniformBuffer")

local uuid = require("uuid")
local ffi = require("ffi")
local webgpu = require("webgpu")

local InvisibleBaseMaterial = {
	-- No mesh is expected to actually use the material, but all others should default to this pipeline
	pipeline = BasicTriangleDrawingPipeline,
}

function InvisibleBaseMaterial:Construct(name)
	local globallyUniqueID = uuid.create()
	local instance = {
		displayName = name or globallyUniqueID,
		uniqueID = globallyUniqueID,
	}

	local inheritanceLookupMetatable = {
		__index = self,
	}
	setmetatable(instance, inheritanceLookupMetatable)

	return instance
end

function InvisibleBaseMaterial:Compile(wgpuDevice, textureFormat)
	printf("Compiling material: %s", classname(self))
	self.assignedRenderingPipeline = self.pipeline:Construct(wgpuDevice, textureFormat)
	self.wgpuDevice = wgpuDevice
	self.textureFormat = textureFormat
end

function InvisibleBaseMaterial:AssignDiffuseTexture(texture)
	self.diffuseTextureBindGroup = self:CreateDiffuseTextureBindGroup(texture)
	self.diffuseTexture = texture
end

function InvisibleBaseMaterial:CreateDiffuseTextureBindGroup(texture, wgpuTexture)
	local wgpuDevice = self.wgpuDevice
	wgpuTexture = wgpuTexture or texture.wgpuTexture -- Ugly hack; needs streamlining (for UI textures)

	printf("[InvisibleBaseMaterial] Creating new bind group for texture %p", wgpuTexture)

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
	local textureView = webgpu.bindings.wgpu_texture_create_view(wgpuTexture, textureViewDescriptor)

	-- Assign texture view and sampler so that they can be bound to the pipeline (in the render loop)
	local bindGroupEntries = new("WGPUBindGroupEntry[?]", 2, {
		new("WGPUBindGroupEntry", {
			binding = 0,
			textureView = textureView,
		}),
		new("WGPUBindGroupEntry", {
			binding = 1,
			sampler = Texture.sharedTrilinearSampler,
		}),
	})

	local textureBindGroupDescriptor = new("WGPUBindGroupDescriptor")
	textureBindGroupDescriptor.layout = UniformBuffer.materialBindGroupLayout

	local wgpuMaterialBindGroupLayoutDescriptor = UniformBuffer.materialBindGroupLayoutDescriptor
	textureBindGroupDescriptor.entryCount = wgpuMaterialBindGroupLayoutDescriptor.entryCount
	textureBindGroupDescriptor.entries = bindGroupEntries

	return webgpu.bindings.wgpu_device_create_bind_group(wgpuDevice, textureBindGroupDescriptor)
end

class("InvisibleBaseMaterial", InvisibleBaseMaterial)

return InvisibleBaseMaterial
