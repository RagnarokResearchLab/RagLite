local ffi = require("ffi")
local uv = require("uv")

local ffi_cast = ffi.cast
local ffi_copy = ffi.copy
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof
local ffi_string = ffi.string
local tonumber = tonumber

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

		typedef struct spr_palette_color {
			uint8_t red;
			uint8_t green;
			uint8_t blue;
			uint8_t alpha;
		} spr_palette_color_t;

		typedef struct spr_palette {
			spr_palette_color_t colors[256];
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
-- 		waterPlanes = {},
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
	self:DecodeIndexedColorBitmapsWithRLE() -- TBD: 2.1 only?
	-- 	self:DecodeTexturedSurfaces()
	-- 	self:DecodeCubeGrid()
	-- 	self:DecodeWaterPlanes()

	self.fileContents = fileContents -- GC anchor for the cdata used internally

	local endTime = uv.hrtime()
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

	self.fileContents = self.fileContents + ffi_sizeof("spr_header_t")
end

function RagnarokSPR:DecodeColorPalette(endOfFileOffset)
	local paletteStartOffset = endOfFileOffset - ffi_sizeof("spr_palette_t")
	local numSkippedBytes = ffi_sizeof("spr_header_t")
	self.palette = ffi_cast("spr_palette_t*", self.fileContents -  numSkippedBytes + paletteStartOffset)
	self.paletteStartOffset = paletteStartOffset
end

local string_rep = string.rep
local math_max = math.max

local assert = assert
local type = type

function RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
	local compressedBufferSize = #compressedBuffer
	printf("Decompressing input buffer: %d bytes", compressedBufferSize)

	local startPointer = compressedBuffer:ref()
	local bytes = ffi_cast("uint8_t*", startPointer)

	local isDecompressingRunOfZeroes = false
	for byteIndex = 0, compressedBufferSize - 1, 1 do
		local nextByteToProcess = bytes[byteIndex]
		-- print(byteIndex, nextByteToProcess)
		-- Add next run
		if isDecompressingRunOfZeroes then
			-- Add X zeroes (X-1 since the previous byte was already a zero that we added, don't add that again)
			local numZeroesToAdd = nextByteToProcess -1
			if numZeroesToAdd > 0 then
				decompressedBuffer:putcdata(ffi_new("uint8_t[?]", numZeroesToAdd), numZeroesToAdd)
			elseif numZeroesToAdd < 0 then
				-- Not sure if this can actually happen - so let's wait and see?
				error(format("Encountered zero-length run at index %s (not an RLE-encoded image?)", byteIndex), 0)
				-- decompressedBuffer:putcdata(ffi_new("uint8_t[1]", 0), 1)
			end
			isDecompressingRunOfZeroes = false
		elseif nextByteToProcess == 0 then
			-- Just add the current byte and start decompressing a run
			decompressedBuffer:putcdata(ffi_new("uint8_t[1]", nextByteToProcess), 1) -- TODO reuse
			isDecompressingRunOfZeroes = true
		else
			-- Just add the current byte
			decompressedBuffer:putcdata(ffi_new("uint8_t[1]", nextByteToProcess), 1)
		end
	end

	printf("Decompressed RLE buffer: %s bytes",#decompressedBuffer)

	C_FileSystem.WriteFile("test.bin", tostring(decompressedBuffer))
end

function RagnarokSPR:GetEmbeddedColorPalette(fileContents)
	local endOfFileOffset = #fileContents
	local paletteStartOffset = endOfFileOffset - ffi_sizeof("spr_palette_t")

	if type(fileContents) == "string" then -- Can't access Lua strings as a buffer directly
		fileContents = buffer.new(#fileContents):put(fileContents)
	end

	local bufferAreaStartPointer = fileContents:ref()
	local paletteBytes = ffi_cast("uint8_t*", bufferAreaStartPointer + paletteStartOffset)
	local bmpColorPalette = ffi_cast("spr_palette_t*", paletteBytes)

	return bmpColorPalette
end

function RagnarokSPR:ApplyColorPalette(decompressedBuffer, pixelBuffer)
end

function RagnarokSPR:DecodeIndexedColorBitmapsWithRLE()

	-- if version does not have RLE then early exit

		for index = 0, self.bmpImagesCount - 1, 1 do
			local runLengthEncodedImageMetadata = ffi_cast("spr_rle_header_t*", self.fileContents)
			self.fileContents = self.fileContents + ffi_sizeof("spr_rle_header_t")

			local compressedBufferSize = tonumber(runLengthEncodedImageMetadata.compressed_buffer_size)
			local compressedBytes =buffer.new(compressedBufferSize)
			compressedBytes:putcdata(ffi_cast("uint8_t*", self.fileContents), compressedBufferSize)
			self.fileContents = self.fileContents +  compressedBufferSize

			local imageWidthInPixels = tonumber(runLengthEncodedImageMetadata.pixel_width)
			local imageHeightInPixels = tonumber(runLengthEncodedImageMetadata.pixel_height)
			-- Note: We only need width * height * 1 to decompress, but later we'll need to replace the palette colors too
			local decompressedBufferSize = imageWidthInPixels * imageHeightInPixels * 4 -- RGBA
			local decompressedBytes = buffer.new(decompressedBufferSize)

			self:DecompressRunLengthEncodedBytes(compressedBytes, decompressedBytes)
			self.bmpImages[index] = {
				pixelWidth = imageWidthInPixels,
				pixelHeight = imageHeightInPixels,
				compressedBufferSize = compressedBufferSize,
				decompressedBufferSize = decompressedBufferSize,
				decompressedImageBuffer = decompressedBytes,
			}

		end

-- 	self.lightmapSlices = ffi_cast("gnd_lightmap_slice_t*", self.fileContents)
-- 	self.fileContents = self.fileContents + lightmapFormatInfo.slice_count * ffi_sizeof("gnd_lightmap_slice_t")

-- 	self.lightmapFormat = {
-- 		numSlices = tonumber(lightmapFormatInfo.slice_count),
-- 		pixelWidth = tonumber(lightmapFormatInfo.slice_width),
-- 		pixelHeight = tonumber(lightmapFormatInfo.slice_height),
-- 		pixelFormatID = tonumber(lightmapFormatInfo.pixel_format),
-- 	}

-- 	-- Basic sanity checks (since other formats aren't supported)
-- 	assert(self.lightmapFormat.pixelFormatID == 1, "Unexpected lightmap pixel format")
-- 	assert(self.lightmapFormat.pixelWidth == 8, "Unexpected lightmap pixel size")
-- 	assert(self.lightmapFormat.pixelHeight == 8, "Unexpected lightmap pixel height")
end

ffi.cdef(RagnarokSPR.cdefs)

return RagnarokSPR
