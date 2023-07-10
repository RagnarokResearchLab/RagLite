local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

local ffi = require("ffi")
local stbi = require("stbi")

local sprFilePath = "Tests/Fixtures/v2-1.spr"
local sprFileContents = C_FileSystem.ReadFile(sprFilePath)

C_FileSystem.MakeDirectory("spr-export")

local spr = RagnarokSPR()
spr:DecodeFileContents(sprFileContents)

local palette = spr:GetEmbeddedColorPalette(sprFileContents)
C_FileSystem.WriteFile("palette.bin", tostring(buffer.new(1024):putcdata(palette, 1024)))

-- for index=0, spr.bmpImagesCount - 1, 1 do
for index=0, 1, 1 do
	local indexedColorImageBytes = spr.bmpImages[index].decompressedImageBuffer
	local rgbaImageBytes = spr:ApplyColorPalette(indexedColorImageBytes, palette)
	C_FileSystem.WriteFile("spr-export/rgba-frame-" .. index .. ".bin", tostring(rgbaImageBytes))

	-- TODO high-level API for this, it's a PITA
	local image = ffi.new("stbi_image_t")
	image.width = spr.bmpImages[index].pixelWidth
	image.height = spr.bmpImages[index].pixelHeight
	image.data = rgbaImageBytes
	image.channels = 4

	local maxFileSize = stbi.max_bitmap_size(image.width, image.height, image.channels)
	local outputBuffer = buffer.new()
	local startPointer, length = outputBuffer:reserve(maxFileSize)

	print(length, #rgbaImageBytes)

	local numBytesWritten = stbi.bindings.stbi_encode_bmp(image, startPointer, length)

	outputBuffer:commit(numBytesWritten)

	C_FileSystem.WriteFile("spr-export/rgba-frame-" .. index .. ".bmp", tostring(outputBuffer))
end

-- local compressedBuffer = buffer.new(990)
-- local frameBytes = C_FileSystem.ReadFile("v2-1-goldporing-rle-encoded-frame0.bin")
-- compressedBuffer:put(frameBytes)
-- local decompressedBuffer = buffer.new(1332)

-- RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)