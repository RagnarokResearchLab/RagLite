local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local ffi_cast = ffi.cast

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

local RGBA_OFFSET_RED = 0
local RGBA_OFFSET_GREEN = 1
local RGBA_OFFSET_BLUE = 2
local RGBA_OFFSET_ALPHA = 3

function Texture:GenerateSimpleGradientImage(textureWidthInPixels, textureHeightInPixels)
	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE

	local pixelCount = textureWidthInPixels * textureHeightInPixels
	local pixels = ffi.new("uint8_t[?]", 4 * pixelCount)

	for u = 0, textureWidthInPixels - 1 do
		for v = 0, textureHeightInPixels - 1 do
			local index = 4 * (v * textureWidthInPixels + u)

			pixels[index + RGBA_OFFSET_RED] = ffi_cast("uint8_t", u)
			pixels[index + RGBA_OFFSET_GREEN] = ffi_cast("uint8_t", v)
			pixels[index + RGBA_OFFSET_BLUE] = ffi_cast("uint8_t", 128)
			pixels[index + RGBA_OFFSET_ALPHA] = ffi_cast("uint8_t", 255)
		end
	end

	return pixels
end

Texture.__call = Texture.Construct
setmetatable(Texture, Texture)

return Texture
