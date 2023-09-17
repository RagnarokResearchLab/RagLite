local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local ffi_cast = ffi.cast

local Texture = {}

local DEFAULT_TEXTURE_SIZE = 256

function Texture:Construct(wgpuDevice, rgbaImageBytes, textureWidthInPixels, textureHeightInPixels)
	assert(rgbaImageBytes, "Failed to create 2D texture (no image data was provided)")

	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE

	local textureDescriptor = ffi.new("WGPUTextureDescriptor")
	textureDescriptor.dimension = ffi.C.WGPUTextureDimension_2D
	textureDescriptor.size = { textureWidthInPixels, textureHeightInPixels, 1 }
	textureDescriptor.mipLevelCount = 1 -- No need for mip-maps (deferred)
	textureDescriptor.sampleCount = 1 -- MSAA isn't currently supported)
	textureDescriptor.format = ffi.C.WGPUTextureFormat_RGBA8Unorm -- TBD: WGPUTextureFormat_BGRA8UnormSrgb ?
	textureDescriptor.usage = bit.bor(ffi.C.WGPUTextureUsage_CopyDst, ffi.C.WGPUTextureUsage_TextureBinding)

	textureDescriptor.viewFormatCount = 0 -- No texture view (for now)

	local wgpuTextureHandle = webgpu.bindings.wgpu_device_create_texture(wgpuDevice, textureDescriptor)

	local instance = {
		wgpuDevice = wgpuDevice,
		wgpuTextureDescriptor = textureDescriptor,
		wgpuTexture = wgpuTextureHandle,
		width = textureWidthInPixels,
		height = textureHeightInPixels,
		rgbaImageBytes = rgbaImageBytes,
	}

	setmetatable(instance, self)

	return instance
end

function Texture:CopyImageBytesToGPU()
	local textureBufferSize = self.width * self.height * 4 -- Assuming RGBA
	printf("Uploading 2D texture: %d x %d (%s)", self.width, self.height, string.filesize(textureBufferSize))

	local destination = ffi.new("WGPUImageCopyTexture")
	destination.texture = self.wgpuTexture
	destination.mipLevel = 0 -- Should update all mip levels automatically here (later)
	destination.origin = { 0, 0, 0 } -- No offsets needed as this isn't an atlas/subresource
	destination.aspect = ffi.C.WGPUTextureAspect_All -- Irrelevant (not a depth/stencil texture)

	local source = ffi.new("WGPUTextureDataLayout")
	source.offset = 0 -- Read everything from the start (no fancy optimizations here...)
	source.bytesPerRow = 4 * self.width -- Might be different for textures loaded from disk?

	assert(source.bytesPerRow >= 256, "Cannot copy texture image (bytesPerRow must be at least 256)")

	source.rowsPerImage = self.height

	webgpu.bindings.wgpu_queue_write_texture(
		webgpu.bindings.wgpu_device_get_queue(self.wgpuDevice),
		destination,
		self.rgbaImageBytes,
		textureBufferSize,
		source,
		self.wgpuTextureDescriptor.size
	)
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
Texture.__index = Texture
setmetatable(Texture, Texture)

return Texture
