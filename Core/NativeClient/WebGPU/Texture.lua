local Color = require("Core.NativeClient.DebugDraw.Color")
local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local UniformBuffer = require("Core.NativeClient.WebGPU.UniformBuffer")

local bit = require("bit")
local ffi = require("ffi")
local transform = require("transform")
local webgpu = require("webgpu")

local cast = ffi.cast
local new = ffi.new
local math_floor = math.floor

local Texture = {
	DEFAULT_TEXTURE_FORMAT = ffi.C.WGPUTextureFormat_RGBA8Unorm, -- TBD: WGPUTextureFormat_BGRA8UnormSrgb ?
	MAX_TEXTURE_DIMENSION = 4096,
	ERROR_DIMENSIONS_NOT_POWER_OF_TWO = "Texture dimensions should always be a power of two",
	ERROR_DIMENSIONS_EXCEEDING_LIMIT = "Texture dimensions must not exceed the configured GPU limit",
}

local function assertDimensionsArePowerOfTwo(width, height)
	-- The assumption that dimensions are power-of-two is implicit in the codebase, so let's avoid surprises here
	if not Texture:IsPowerOfTwo(width) or not Texture:IsPowerOfTwo(height) then
		error(Texture.ERROR_DIMENSIONS_NOT_POWER_OF_TWO, 0)
	end
end

local function assertDimensionsAreWithinLimits(width, height)
	-- This may be caught by the validation layer, but no need to waste resources generating incompatible textures
	if width > Texture.MAX_TEXTURE_DIMENSION or height > Texture.MAX_TEXTURE_DIMENSION then
		error(Texture.ERROR_DIMENSIONS_EXCEEDING_LIMIT, 0)
	end
end

local DEFAULT_TEXTURE_SIZE = 256
local GRID_CELL_SIZE = 64

function Texture:Construct(wgpuDevice, rgbaImageBytes, textureWidthInPixels, textureHeightInPixels)
	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE
	assertDimensionsAreWithinLimits(textureWidthInPixels, textureHeightInPixels)
	assert(rgbaImageBytes, "Failed to create 2D texture (no image data was provided)")

	if not Texture:IsPowerOfTwo(textureWidthInPixels) or not Texture:IsPowerOfTwo(textureHeightInPixels) then
		-- This isn't ideal, but some maps use textures that will be oddly-sized (e.g., prontera)
		print(transform.yellow("WARNING: " .. Texture.ERROR_DIMENSIONS_NOT_POWER_OF_TWO))
	end

	local textureDescriptor = new("WGPUTextureDescriptor", {
		dimension = ffi.C.WGPUTextureDimension_2D,
		size = {
			width = textureWidthInPixels,
			height = textureHeightInPixels,
			depthOrArrayLayers = 1,
		},
		mipLevelCount = 1, -- No need for mip-maps (deferred)
		sampleCount = 1, -- MSAA isn't currently supported)
		format = Texture.DEFAULT_TEXTURE_FORMAT,
		usage = bit.bor(ffi.C.WGPUTextureUsage_CopyDst, ffi.C.WGPUTextureUsage_TextureBinding),
		viewFormatCount = 0, -- No texture view (for now)
	})

	local textureHandle = webgpu.bindings.wgpu_device_create_texture(wgpuDevice, textureDescriptor)
	local bindGroup = self:CreateBindGroupForPipeline(textureHandle, BasicTriangleDrawingPipeline)

	local instance = {
		wgpuDevice = wgpuDevice,
		wgpuTextureDescriptor = textureDescriptor,
		wgpuTexture = textureHandle,
		wgpuBindGroup = bindGroup,
		width = textureWidthInPixels,
		height = textureHeightInPixels,
		rgbaImageBytes = rgbaImageBytes,
	}

	setmetatable(instance, self)

	return instance
end

function Texture:CreateBindGroupForPipeline(textureHandle, renderPipeline)
	local wgpuDevice = renderPipeline.wgpuDevice

	printf(
		"[Texture] Creating new bind group for texture %p and pipeline %s",
		textureHandle,
		renderPipeline.displayName
	)

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
	local textureView = webgpu.bindings.wgpu_texture_create_view(textureHandle, textureViewDescriptor)

	-- Assign texture view and sampler so that they can be bound to the pipeline (in the render loop)
	local bindGroupEntries = new("WGPUBindGroupEntry[?]", 2, {
		new("WGPUBindGroupEntry", {
			binding = 0,
			textureView = textureView,
		}),
		new("WGPUBindGroupEntry", {
			binding = 1,
			sampler = self.sharedTrilinearSampler,
		}),
	})

	local textureBindGroupDescriptor = new("WGPUBindGroupDescriptor")
	textureBindGroupDescriptor.layout = UniformBuffer.materialBindGroupLayout

	local wgpuMaterialBindGroupLayoutDescriptor = UniformBuffer.materialBindGroupLayoutDescriptor
	textureBindGroupDescriptor.entryCount = wgpuMaterialBindGroupLayoutDescriptor.entryCount
	textureBindGroupDescriptor.entries = bindGroupEntries

	return webgpu.bindings.wgpu_device_create_bind_group(wgpuDevice, textureBindGroupDescriptor)
end

function Texture:CreateSharedTrilinearSampler(wgpuDevice)
	local samplerDescriptor = new("WGPUSamplerDescriptor", {
		label = "SharedTrilinearTextureSampler",
		addressModeU = ffi.C.WGPUAddressMode_ClampToEdge,
		addressModeV = ffi.C.WGPUAddressMode_ClampToEdge,
		addressModeW = ffi.C.WGPUAddressMode_ClampToEdge,
		magFilter = ffi.C.WGPUFilterMode_Linear,
		minFilter = ffi.C.WGPUFilterMode_Linear,
		mipmapFilter = ffi.C.WGPUFilterMode_Linear,
		lodMinClamp = 0.0,
		lodMaxClamp = math.huge,
		compare = ffi.C.WGPUCompareFunction_Undefined, -- Irrelevant (not a depth texture)
		maxAnisotropy = 1, -- Might want to use clamped addressing with anisotropic filtering here?
	})

	printf("[Texture] Registering shared sampler: %s", ffi.string(samplerDescriptor.label))
	self.sharedTrilinearSampler = webgpu.bindings.wgpu_device_create_sampler(wgpuDevice, samplerDescriptor)
end

function Texture:CopyImageBytesToGPU()
	local textureBufferSize = self.width * self.height * 4 -- Assuming RGBA
	printf("Uploading 2D texture: %d x %d (%s)", self.width, self.height, string.filesize(textureBufferSize))

	local destination = new("WGPUImageCopyTexture", {
		texture = self.wgpuTexture,
		mipLevel = 0, -- Should update all mip levels automatically here (later)
		origin = { 0, 0, 0 }, -- No offsets needed as this isn't an atlas/subresource
		aspect = ffi.C.WGPUTextureAspect_All, -- Irrelevant (not a depth/stencil texture)
	})

	local source = new("WGPUTextureDataLayout", {
		offset = 0, -- Read everything from the start (no fancy optimizations here...)
		bytesPerRow = 4 * self.width, -- Might be different for textures loaded from disk?
		rowsPerImage = self.height,
	})

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
	assertDimensionsArePowerOfTwo(textureWidthInPixels, textureHeightInPixels)
	assertDimensionsAreWithinLimits(textureWidthInPixels, textureHeightInPixels)

	local pixelCount = textureWidthInPixels * textureHeightInPixels
	local pixels = new("uint8_t[?]", 4 * pixelCount)

	for u = 0, textureWidthInPixels - 1 do
		for v = 0, textureHeightInPixels - 1 do
			local index = 4 * (v * textureWidthInPixels + u)

			pixels[index + RGBA_OFFSET_RED] = cast("uint8_t", u)
			pixels[index + RGBA_OFFSET_GREEN] = cast("uint8_t", v)
			pixels[index + RGBA_OFFSET_BLUE] = cast("uint8_t", 128)
			pixels[index + RGBA_OFFSET_ALPHA] = cast("uint8_t", 255)
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
	assertDimensionsArePowerOfTwo(textureWidthInPixels, textureHeightInPixels)
	assertDimensionsAreWithinLimits(textureWidthInPixels, textureHeightInPixels)
	color = color or Color.WHITE

	local pixelCount = textureWidthInPixels * textureHeightInPixels
	local pixels = new("uint8_t[?]", 4 * pixelCount)

	for u = 0, textureWidthInPixels - 1 do
		for v = 0, textureHeightInPixels - 1 do
			local index = 4 * (v * textureWidthInPixels + u)

			pixels[index + RGBA_OFFSET_RED] = cast("uint8_t", color.red * 255)
			pixels[index + RGBA_OFFSET_GREEN] = cast("uint8_t", color.green * 255)
			pixels[index + RGBA_OFFSET_BLUE] = cast("uint8_t", color.blue * 255)
			pixels[index + RGBA_OFFSET_ALPHA] = cast("uint8_t", 255)
		end
	end

	return pixels
end

function Texture:GenerateCheckeredGridImage(textureWidthInPixels, textureHeightInPixels, firstColor, secondColor)
	textureWidthInPixels = textureWidthInPixels or DEFAULT_TEXTURE_SIZE
	textureHeightInPixels = textureHeightInPixels or DEFAULT_TEXTURE_SIZE
	assertDimensionsArePowerOfTwo(textureWidthInPixels, textureHeightInPixels)
	assertDimensionsAreWithinLimits(textureWidthInPixels, textureHeightInPixels)

	firstColor = firstColor or { red = 1, blue = 1, green = 1 }
	secondColor = secondColor or { red = 0, blue = 0, green = 0 }

	local pixelCount = textureWidthInPixels * textureHeightInPixels
	local pixels = new("uint8_t[?]", 4 * pixelCount)

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
