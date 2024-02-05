local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local Device = require("Core.NativeClient.WebGPU.Device")
local Queue = require("Core.NativeClient.WebGPU.Queue")
local Texture = require("Core.NativeClient.WebGPU.Texture")
local UniformBuffer = require("Core.NativeClient.WebGPU.UniformBuffer")

local uuid = require("uuid")
local ffi = require("ffi")
local webgpu = require("webgpu")

local InvisibleBaseMaterial = {
	diffuseColor = {
		red = 1,
		green = 1,
		blue = 1,
	},
	opacity = 0.05, -- Not actually zero to avoid a debugging nightmare if this is accidentally used
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

function InvisibleBaseMaterial:Compile(wgpuDevice, surfaceTextureFormat)
	printf("Compiling material: %s", classname(self))
	self.surfaceRenderingPipeline = self.pipeline:Construct(wgpuDevice, surfaceTextureFormat)
	self.offlineRenderingPipeline = self.pipeline:Construct(wgpuDevice, ffi.C.WGPUTextureFormat_RGBA8UnormSrgb)
	self.wgpuDevice = wgpuDevice
	self.textureFormat = surfaceTextureFormat
end

function InvisibleBaseMaterial:AssignDiffuseTexture(texture, wgpuTexture)
	self.materialPropertiesUniform = UniformBuffer:CreateMaterialPropertiesUniform(self.wgpuDevice)
	self.diffuseTextureBindGroup = self:CreateMaterialPropertiesBindGroup(texture, wgpuTexture)
	self.diffuseTexture = texture
end

function InvisibleBaseMaterial:AssignLightmapTexture(texture, wgpuTexture)
	error("Lightmap textures aren't yet supported by this material", 0)
end

function InvisibleBaseMaterial:UpdateMaterialPropertiesUniform()
	-- Should only send if the data has actually changed? (optimize later)
	self.materialPropertiesUniform.data.diffuseRed = self.diffuseColor.red
	self.materialPropertiesUniform.data.diffuseGreen = self.diffuseColor.green
	self.materialPropertiesUniform.data.diffuseBlue = self.diffuseColor.blue
	self.materialPropertiesUniform.data.materialOpacity = self.opacity

	Queue:WriteBuffer(
		Device:GetQueue(self.wgpuDevice),
		self.materialPropertiesUniform.buffer,
		0,
		self.materialPropertiesUniform.data,
		ffi.sizeof(self.materialPropertiesUniform.data)
	)
end

function InvisibleBaseMaterial:CreateMaterialPropertiesBindGroup(texture, wgpuTexture)
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
	local bindGroupEntries = new("WGPUBindGroupEntry[?]", 3, {
		new("WGPUBindGroupEntry", {
			binding = 0,
			textureView = textureView,
		}),
		new("WGPUBindGroupEntry", {
			binding = 1,
			sampler = Texture.sharedTrilinearSampler,
		}),
		new("WGPUBindGroupEntry", {
			binding = 2,
			buffer = self.materialPropertiesUniform.buffer,
			offset = 0,
			size = ffi.sizeof("material_uniform_t"),
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
