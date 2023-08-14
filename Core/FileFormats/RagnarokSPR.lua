local ffi = require("ffi")
local stbi = require("stbi")
local uv = require("uv")

local printf = printf
local tonumber = tonumber
local type = type

local ffi_cast = ffi.cast
local ffi_copy = ffi.copy
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof
local ffi_string = ffi.string
local uv_hrtime = uv.hrtime

local RagnarokSPR = {
	cdefs = [[
		#pragma pack(1)
		typedef struct spr_header {
			char signature[2];
			uint8_t version_minor;
			uint8_t version_major;
			uint16_t bmp_images_count;
			uint16_t tga_images_count;
		} spr_header_t;

		typedef struct spr_rgba_color {
			uint8_t red;
			uint8_t green;
			uint8_t blue;
			uint8_t alpha;
		} spr_rgba_color_t;

		typedef struct spr_palette {
			spr_rgba_color_t colors[256];
		} spr_palette_t;

		typedef struct spr_rle_header {
			uint16_t pixel_width;
			uint16_t pixel_height;
			uint16_t compressed_buffer_size;
		} spr_rle_header_t;
	]],
}

function RagnarokSPR:Construct()
	local instance = {
		bmpImages = {},
		tgaImages = {},
	}

	setmetatable(instance, self)

	return instance
end

RagnarokSPR.__index = RagnarokSPR
RagnarokSPR.__call = RagnarokSPR.Construct
setmetatable(RagnarokSPR, RagnarokSPR)

function RagnarokSPR:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.fileContents = ffi_cast("char*", fileContents)

	self:DecodeHeader()
	self:DecodeColorPalette(#fileContents)

	self:DecodeIndexedColorBitmaps()
	self:DecodeIndexedColorBitmapsWithRLE()
	self:DecodeTrueColorImages()

	self.fileContents = fileContents -- GC anchor for the cdata used internally

	local endTime = uv_hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokSPR] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokSPR:DecodeHeader()
	local header = ffi_cast("spr_header_t*", self.fileContents)
	local headerSize = ffi_sizeof(header.signature)

	self.signature = ffi_string(header.signature, headerSize)
	if self.signature ~= "SP" then
		error("Failed to decode SPR header (Signature " .. self.signature .. ' should be "SP")', 0)
	end

	self.version = header.version_major + header.version_minor / 10

	self.bmpImagesCount = tonumber(header.bmp_images_count)
	self.tgaImagesCount = tonumber(header.tga_images_count)

	if self.version == 1.1 then
		self.tgaImagesCount = 0
		-- Need to rewind since we went past the header
		self.fileContents = self.fileContents - ffi_sizeof("uint16_t")
	end

	assert(self.version == 1.1 or self.version >= 2.0, "Unsupported SPR version " .. self.version)

	self.fileContents = self.fileContents + ffi_sizeof("spr_header_t")
end

function RagnarokSPR:DecodeColorPalette(endOfFileOffset)
	local paletteStartOffset = endOfFileOffset - ffi_sizeof("spr_palette_t")
	local numSkippedBytes = ffi_sizeof("spr_header_t")

	if self.version < 2.0 then
		-- No TGA images are present, so we went too far
		numSkippedBytes = numSkippedBytes - ffi_sizeof("uint16_t")
	end

	self.palette = ffi_cast("spr_palette_t*", self.fileContents - numSkippedBytes + paletteStartOffset)
	self.paletteStartOffset = paletteStartOffset
end

function RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
	local compressedBytes = ffi_cast("uint8_t*", compressedBuffer:ref())
	local isDecompressingRunOfZeroes = false

	for byteIndex = 0, #compressedBuffer - 1 do
		local currentByte = compressedBytes[byteIndex]

		if isDecompressingRunOfZeroes then
			local numZeroesToAdd = currentByte - 1
			if numZeroesToAdd > 0 then
				decompressedBuffer:putcdata(ffi_new("uint8_t[?]", numZeroesToAdd), numZeroesToAdd)
			elseif numZeroesToAdd < 0 then
				error(format("Encountered zero-length run at index %s (not an RLE-encoded image?)", byteIndex), 0)
			end
			isDecompressingRunOfZeroes = false
		else
			decompressedBuffer:putcdata(ffi_new("uint8_t[1]", currentByte), 1)
			if currentByte == 0 then
				isDecompressingRunOfZeroes = true
			end
		end
	end
end

function RagnarokSPR:GetEmbeddedColorPalette(fileContents)
	local endOfFileOffset = #fileContents
	local paletteStartOffset = endOfFileOffset - ffi_sizeof("spr_palette_t")

	if type(fileContents) == "string" then -- Can't use Lua strings as a buffer directly
		fileContents = buffer.new(#fileContents):put(fileContents)
	end

	local bufferAreaStartPointer = fileContents:ref()
	local paletteBytes = ffi_cast("spr_palette_t*", bufferAreaStartPointer + paletteStartOffset)

	-- Must copy to create a GC anchor here before the buffer is collected (probably not a big deal?)
	local bmpColorPalette = ffi_new("spr_palette_t[1]", paletteBytes[0])
	local newColors = ffi_new("spr_palette_t")

	ffi_copy(newColors, bmpColorPalette[0], ffi_sizeof("spr_palette_t"))
	return newColors
end

function RagnarokSPR:ApplyColorPalette(indexedColorImageBytes, palette)
	local rgbaImageBytes = buffer.new(#indexedColorImageBytes * 4)

	local startPointer = indexedColorImageBytes:ref()

	local paletteIndices = ffi_cast("uint8_t*", startPointer)

	for byteIndex = 0, #indexedColorImageBytes - 1, 1 do
		local paletteIndex = tonumber(paletteIndices[byteIndex])
		local paletteColor = palette.colors[tonumber(paletteIndex)]
		rgbaImageBytes:putcdata(paletteColor, ffi_sizeof(paletteColor))
	end

	return rgbaImageBytes
end

function RagnarokSPR:DecodeIndexedColorBitmaps()
	if self.version >= 2.1 then
		return -- Need to deal with RLE first
	end

	for index = 1, self.bmpImagesCount, 1 do
		local imageWidthInPixels = ffi_cast("int16_t*", self.fileContents)[0]
		self.fileContents = self.fileContents + ffi_sizeof("int16_t")

		local imageHeightInPixels = ffi_cast("int16_t*", self.fileContents)[0]
		self.fileContents = self.fileContents + ffi_sizeof("int16_t")

		local pixelCount = imageWidthInPixels * imageHeightInPixels
		local pixelBufferSize = pixelCount * 4 -- RGBA
		local pixelBuffer = buffer.new(pixelBufferSize)

		local pixels = ffi_cast("uint8_t*", self.fileContents)
		pixelBuffer:putcdata(pixels, pixelCount)
		self.fileContents = self.fileContents + pixelCount

		self.bmpImages[index] = {
			pixelWidth = imageWidthInPixels,
			pixelHeight = imageHeightInPixels,
			compressedBufferSize = pixelCount,
			decompressedBufferSize = pixelBufferSize,
			pixelBuffer = pixelBuffer,
		}
	end
end

function RagnarokSPR:DecodeIndexedColorBitmapsWithRLE()
	if self.version < 2.1 then
		return -- RLE isn't used
	end

	for index = 1, self.bmpImagesCount, 1 do
		local runLengthEncodedImageMetadata = ffi_cast("spr_rle_header_t*", self.fileContents)
		self.fileContents = self.fileContents + ffi_sizeof("spr_rle_header_t")

		local compressedBufferSize = tonumber(runLengthEncodedImageMetadata.compressed_buffer_size)
		local compressedBytes = buffer.new(compressedBufferSize)
		compressedBytes:putcdata(ffi_cast("uint8_t*", self.fileContents), compressedBufferSize)
		self.fileContents = self.fileContents + compressedBufferSize

		local imageWidthInPixels = tonumber(runLengthEncodedImageMetadata.pixel_width)
		local imageHeightInPixels = tonumber(runLengthEncodedImageMetadata.pixel_height)

		-- We only require width * height * 1 bytes to decompress, but later we'll need to replace the palette colors anyway
		local decompressedBufferSize = imageWidthInPixels * imageHeightInPixels * 4 -- RGBA
		local decompressedBytes = buffer.new(decompressedBufferSize)

		self:DecompressRunLengthEncodedBytes(compressedBytes, decompressedBytes)
		self.bmpImages[index] = {
			pixelWidth = imageWidthInPixels,
			pixelHeight = imageHeightInPixels,
			compressedBufferSize = compressedBufferSize,
			decompressedBufferSize = decompressedBufferSize,
			pixelBuffer = decompressedBytes,
		}
	end
end

function RagnarokSPR:DecodeTrueColorImages()
	if self.version < 2.0 then
		return -- No TGA segment present
	end

	local image = ffi_new("stbi_image_t")
	image.channels = 4

	for index = 1, self.tgaImagesCount, 1 do
		image.width = ffi_cast("uint16_t*", self.fileContents)[0]
		self.fileContents = self.fileContents + ffi_sizeof("uint16_t")

		image.height = ffi_cast("uint16_t*", self.fileContents)[0]
		self.fileContents = self.fileContents + ffi_sizeof("uint16_t")

		local pixelBufferSize = image.width * image.height * 4 -- ABGR
		local pixelBuffer = buffer.new(pixelBufferSize)

		local abgrPixelArray = ffi_cast("stbi_pixelbuffer_t", self.fileContents)
		image.data = abgrPixelArray

		stbi.bindings.stbi_abgr_to_rgba(image)
		pixelBuffer:putcdata(image.data, pixelBufferSize)
		self.fileContents = self.fileContents + pixelBufferSize

		self.tgaImages[index] = {
			pixelWidth = tonumber(image.width),
			pixelHeight = tonumber(image.height),
			pixelBuffer = pixelBuffer,
		}
	end
end

ffi.cdef(RagnarokSPR.cdefs)

return RagnarokSPR
