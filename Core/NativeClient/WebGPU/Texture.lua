local Color = require("Core.NativeClient.DebugDraw.Color")
local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")

local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local ffi_cast = ffi.cast
local math_floor = math.floor

local Texture = {
	ERROR_DIMENSIONS_NOT_POWER_OF_TWO = "Texture dimensions should always be a power of two",
}

local function assertPowerOfTwoDimensions(width, height)
	-- The assumption that dimensions are power-of-two is implicit in the codebase, so let's avoid surprises here
	if not Texture:IsPowerOfTwo(width) or not Texture:IsPowerOfTwo(height) then
		error(Texture.ERROR_DIMENSIONS_NOT_POWER_OF_TWO, 0)
	end
end

local DEFAULT_TEXTURE_SIZE = 256
local GRID_CELL_SIZE = 64

function Texture:Construct(wgpuDevice, rgbaImageBytes, textureWidthInPixels, textureHeightInPixels)
	assert(rgbaImageBytes, "Failed to create 2D texture (no image data was provided)")

	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE
	assertPowerOfTwoDimensions(textureWidthInPixels, textureHeightInPixels)

	local textureDescriptor = ffi.new("WGPUTextureDescriptor")
	textureDescriptor.dimension = ffi.C.WGPUTextureDimension_2D
	textureDescriptor.size = { textureWidthInPixels, textureHeightInPixels, 1 }
	textureDescriptor.mipLevelCount = 1 -- No need for mip-maps (deferred)
	textureDescriptor.sampleCount = 1 -- MSAA isn't currently supported)
	textureDescriptor.format = ffi.C.WGPUTextureFormat_RGBA8Unorm -- TBD: WGPUTextureFormat_BGRA8UnormSrgb ?
	textureDescriptor.usage = bit.bor(ffi.C.WGPUTextureUsage_CopyDst, ffi.C.WGPUTextureUsage_TextureBinding)

	textureDescriptor.viewFormatCount = 0 -- No texture view (for now)

	local textureHandle = webgpu.bindings.wgpu_device_create_texture(wgpuDevice, textureDescriptor)

	-- Create readonly view that should be accessed by a sampler
	local textureViewDescriptor = ffi.new("WGPUTextureViewDescriptor")
	textureViewDescriptor.aspect = ffi.C.WGPUTextureAspect_All
	textureViewDescriptor.baseArrayLayer = 0
	textureViewDescriptor.arrayLayerCount = 1
	textureViewDescriptor.baseMipLevel = 0
	textureViewDescriptor.mipLevelCount = 1
	textureViewDescriptor.dimension = ffi.C.WGPUTextureViewDimension_2D
	textureViewDescriptor.format = textureDescriptor.format
	local textureView = webgpu.bindings.wgpu_texture_create_view(textureHandle, textureViewDescriptor)

	-- Creating one sampler per texture is wasteful, but gives the most flexibility (revisit later, if needed)
	local samplerDescriptor = ffi.new("WGPUSamplerDescriptor")
	samplerDescriptor.label = "SharedTextureSampler"
	samplerDescriptor.addressModeU = ffi.C.WGPUAddressMode_ClampToEdge
	samplerDescriptor.addressModeV = ffi.C.WGPUAddressMode_ClampToEdge
	samplerDescriptor.addressModeW = ffi.C.WGPUAddressMode_ClampToEdge
	samplerDescriptor.magFilter = ffi.C.WGPUFilterMode_Linear
	samplerDescriptor.minFilter = ffi.C.WGPUFilterMode_Linear
	samplerDescriptor.mipmapFilter = ffi.C.WGPUFilterMode_Linear
	samplerDescriptor.lodMinClamp = 0.0
	samplerDescriptor.lodMaxClamp = math.huge
	samplerDescriptor.compare = ffi.C.WGPUCompareFunction_Undefined -- Irrelevant (not a depth texture)
	samplerDescriptor.maxAnisotropy = 1 -- Might want to use clamped addressing with anisotropic filtering here?
	local textureSampler = webgpu.bindings.wgpu_device_create_sampler(wgpuDevice, samplerDescriptor)

	-- Assign texture view and sampler so that they can be bound to the pipeline (in the render loop)
	local textureViewBindGroupEntry = ffi.new("WGPUBindGroupEntry")
	textureViewBindGroupEntry.binding = 0
	textureViewBindGroupEntry.textureView = textureView

	local samplerBindGroupEntry = ffi.new("WGPUBindGroupEntry")
	samplerBindGroupEntry.binding = 1
	samplerBindGroupEntry.sampler = textureSampler

	local bindGroupEntries = ffi.new("WGPUBindGroupEntry[?]", 2)
	bindGroupEntries[0] = textureViewBindGroupEntry
	bindGroupEntries[1] = samplerBindGroupEntry

	-- Depending on the pipeline to be initialized here is unfortunate, but I guess there's no other way?
	local textureBindGroupDescriptor = ffi.new("WGPUBindGroupDescriptor")
	textureBindGroupDescriptor.layout = BasicTriangleDrawingPipeline.wgpuMaterialBindGroupLayout
	textureBindGroupDescriptor.entryCount =
		BasicTriangleDrawingPipeline.wgpuMaterialBindGroupLayoutDescriptor.entryCount
	textureBindGroupDescriptor.entries = bindGroupEntries

	local bindGroup = webgpu.bindings.wgpu_device_create_bind_group(wgpuDevice, textureBindGroupDescriptor)

	local instance = {
		wgpuDevice = wgpuDevice,
		wgpuTextureDescriptor = textureDescriptor,
		wgpuTexture = textureHandle,
		wgpuTextureView = textureView,
		wgpuTextureViewDescriptor = textureViewDescriptor,
		wgpuTextureSampler = textureSampler,
		wgpuSamplerDescriptor = samplerDescriptor,
		wgpuBindGroup = bindGroup,
		wgpuBindGroupDescriptor = textureBindGroupDescriptor,
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
	assertPowerOfTwoDimensions(textureWidthInPixels, textureHeightInPixels)

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

function Texture:IsPowerOfTwo(n)
	return n > 0 and (bit.band(n, n - 1) == 0)
end

function Texture:GenerateBlankImage(textureWidthInPixels, textureHeightInPixels, color)
	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE
	assertPowerOfTwoDimensions(textureWidthInPixels, textureHeightInPixels)
	color = color or Color.WHITE

	local pixelCount = textureWidthInPixels * textureHeightInPixels
	local pixels = ffi.new("uint8_t[?]", 4 * pixelCount)

	for u = 0, textureWidthInPixels - 1 do
		for v = 0, textureHeightInPixels - 1 do
			local index = 4 * (v * textureWidthInPixels + u)

			pixels[index + RGBA_OFFSET_RED] = ffi_cast("uint8_t", color.red * 255)
			pixels[index + RGBA_OFFSET_GREEN] = ffi_cast("uint8_t", color.green * 255)
			pixels[index + RGBA_OFFSET_BLUE] = ffi_cast("uint8_t", color.blue * 255)
			pixels[index + RGBA_OFFSET_ALPHA] = ffi_cast("uint8_t", 255)
		end
	end

	return pixels
end

function Texture:GenerateCheckeredGridImage(textureWidthInPixels, textureHeightInPixels, firstColor, secondColor)
	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE
	assertPowerOfTwoDimensions(textureWidthInPixels, textureHeightInPixels)

	firstColor = firstColor or { red = 1, blue = 1, green = 1 }
	secondColor = secondColor or { red = 0, blue = 0, green = 0 }

	local pixelCount = textureWidthInPixels * textureHeightInPixels
	local pixels = ffi.new("uint8_t[?]", 4 * pixelCount)

	for u = 0, textureWidthInPixels - 1 do
		for v = 0, textureHeightInPixels - 1 do
			local index = 4 * (v * textureWidthInPixels + u)

			local useAlternateColor = math_floor(u / GRID_CELL_SIZE) % 2 == math_floor(v / GRID_CELL_SIZE) % 2
			local cellColor = useAlternateColor and firstColor or secondColor

			pixels[index + RGBA_OFFSET_RED] = ffi.cast("uint8_t", cellColor.red * 255)
			pixels[index + RGBA_OFFSET_GREEN] = ffi.cast("uint8_t", cellColor.green * 255)
			pixels[index + RGBA_OFFSET_BLUE] = ffi.cast("uint8_t", cellColor.blue * 255)
			pixels[index + RGBA_OFFSET_ALPHA] = ffi.cast("uint8_t", 255)
		end
	end

	return pixels
end

function Texture:CreateTextureView(wgpuTexture, wgpuTextureViewDescriptor)
	return webgpu.bindings.wgpu_texture_create_view(wgpuTexture, wgpuTextureViewDescriptor)
end

Texture.__call = Texture.Construct
Texture.__index = Texture
setmetatable(Texture, Texture)

return Texture
