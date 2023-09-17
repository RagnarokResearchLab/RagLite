local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local Texture = {}

local DEFAULT_TEXTURE_SIZE = 256

function Texture:Construct(wgpuDevice, textureWidthInPixels, textureHeightInPixels)
	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE

	local textureDescriptor = ffi.new("WGPUTextureDescriptor")
	textureDescriptor.dimension = ffi.C.WGPUTextureDimension_2D
	textureDescriptor.size = { textureWidthInPixels, textureHeightInPixels, 1 }
	textureDescriptor.mipLevelCount = 1 -- No need for mip-maps (deferred)
	textureDescriptor.sampleCount = 1 -- MSAA isn't currently supported)
	textureDescriptor.format = ffi.C.WGPUTextureFormat_RGBA8Unorm
	textureDescriptor.usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUTextureUsage_TextureBinding)

	textureDescriptor.viewFormatCount = 0 -- No texture view (for now)

	webgpu.bindings.wgpu_device_create_texture(wgpuDevice, textureDescriptor)

	local instance = {
		wgpuTextureDescriptor = textureDescriptor,
	}

	setmetatable(instance, self)

	return instance
end

Texture.__call = Texture.Construct
setmetatable(Texture, Texture)

return Texture
