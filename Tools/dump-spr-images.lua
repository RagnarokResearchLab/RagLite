local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

local compressedBuffer = buffer.new(990)
local frameBytes = C_FileSystem.ReadFile("v2-1-goldporing-rle-encoded-frame0.bin")
compressedBuffer:put(frameBytes)
local decompressedBuffer = buffer.new(1332)

RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)