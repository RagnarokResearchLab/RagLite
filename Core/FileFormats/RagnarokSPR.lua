local BinaryReader = require("Core.FileFormats.BinaryReader")
local RagnarokPAL = require("Core.FileFormats.RagnarokPAL")

local ffi = require("ffi")
local stbi = require("stbi")
local uv = require("uv")

local printf = printf
local tonumber = tonumber

local ffi_cast = ffi.cast
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof
local uv_hrtime = uv.hrtime

local RagnarokSPR = {}

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

	self.reader = BinaryReader(fileContents)

	self:DecodeHeader()
	self:DecodeIndexedColorBitmaps()
	self:DecodeIndexedColorBitmapsWithRLE()
	self:DecodeTrueColorImages()
	self:DecodeColorPalette()

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure!", numBytesRemaining)
	assert(self.reader:HasReachedEOF(), eofErrorMessage)

	local endTime = uv_hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokSPR] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokSPR:DecodeHeader()
	local reader = self.reader

	self.signature = reader:GetCountedString(2)
	if self.signature ~= "SP" then
		error("Failed to decode SPR header (Signature " .. self.signature .. ' should be "SP")', 0)
	end

	local minorVersion = reader:GetUnsignedInt8()
	local majorVersion = reader:GetUnsignedInt8()
	self.version = majorVersion + minorVersion / 10

	self.bmpImagesCount = reader:GetUnsignedInt16()
	self.tgaImagesCount = self.version > 1.1 and reader:GetUnsignedInt16() or 0

	assert(self.version == 1.1 or self.version >= 2.0, "Unsupported SPR version " .. self.version)
end

function RagnarokSPR:DecodeColorPalette()
	local reader = self.reader

	self.paletteStartOffset = reader.endOfFilePointer - ffi_sizeof("spr_palette_t")
	self.palette = reader:GetTypedArray("spr_palette_t")
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
	-- Kind of sketchy, but let's keep this around for the time being...
	return RagnarokPAL:DecodeFileContents(fileContents)
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

	local reader = self.reader
	for index = 1, self.bmpImagesCount, 1 do
		local imageWidthInPixels = reader:GetUnsignedInt16()
		local imageHeightInPixels = reader:GetUnsignedInt16()

		local pixelCount = imageWidthInPixels * imageHeightInPixels
		local pixelBufferSize = pixelCount * 4 -- RGBA
		local pixelBuffer = buffer.new(pixelBufferSize)

		local pixels = reader:GetTypedArray("uint8_t", pixelCount)
		pixelBuffer:putcdata(pixels, pixelCount)

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

	local reader = self.reader
	for index = 1, self.bmpImagesCount, 1 do
		local imageWidthInPixels = reader:GetUnsignedInt16()
		local imageHeightInPixels = reader:GetUnsignedInt16()

		local compressedBufferSize = reader:GetUnsignedInt16()
		local compressedBytes = buffer.new(compressedBufferSize)
		local compressedImageBytes = reader:GetTypedArray("uint8_t", compressedBufferSize)
		compressedBytes:putcdata(compressedImageBytes, compressedBufferSize)

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

	local reader = self.reader
	for index = 1, self.tgaImagesCount, 1 do
		image.width = reader:GetUnsignedInt16()
		image.height = reader:GetUnsignedInt16()

		local pixelBufferSize = image.width * image.height * 4 -- ABGR
		local pixelBuffer = buffer.new(pixelBufferSize)

		local abgrPixelBytes = reader:GetTypedArray("uint8_t", pixelBufferSize)
		local abgrPixelArray = ffi_cast("stbi_pixelbuffer_t", abgrPixelBytes) -- TBD redundant, can remove?
		image.data = abgrPixelArray

		stbi.bindings.stbi_abgr_to_rgba(image)
		pixelBuffer:putcdata(image.data, pixelBufferSize)

		self.tgaImages[index] = {
			pixelWidth = tonumber(image.width),
			pixelHeight = tonumber(image.height),
			pixelBuffer = pixelBuffer,
		}
	end
end

return RagnarokSPR
