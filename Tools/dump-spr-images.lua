local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

local sprFilePath = "Tests/Fixtures/v2-1.spr"
local sprFileContents = C_FileSystem.ReadFile(sprFilePath)

local spr = RagnarokSPR()
spr:DecodeFileContents(sprFileContents)

local palette = spr:GetEmbeddedColorPalette(sprFileContents)
C_FileSystem.WriteFile("palette.bin", tostring(buffer.new(1024):putcdata(palette, 1024)))

-- for index=0, spr.bmpImagesCount - 1, 1 do
for index=0, 1, 1 do
	local indexedColorImageBytes = spr.bmpImages[index].decompressedImageBuffer
	local rgbaImageBytes = spr:ApplyColorPalette(indexedColorImageBytes, palette)
	C_FileSystem.WriteFile("rgba-frame-" .. index .. ".bin", tostring(rgbaImageBytes))
end

-- local compressedBuffer = buffer.new(990)
-- local frameBytes = C_FileSystem.ReadFile("v2-1-goldporing-rle-encoded-frame0.bin")
-- compressedBuffer:put(frameBytes)
-- local decompressedBuffer = buffer.new(1332)

-- RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)