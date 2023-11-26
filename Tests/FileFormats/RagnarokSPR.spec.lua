local miniz = require("miniz")

local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

local BMP_ONLY_SPR = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "bmp-paletted.spr"))
local BASIC_TGA_SPR = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "bmp-tga-paletted.spr"))
local TGA_SPR_WITH_RLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "rle-bmp-tga-paletted.spr"))

describe("RagnarokSPR", function()
	describe("DecodeFileContents", function()
		it("should be able to decode SPR files using version 1.1 of the format", function()
			local spr = RagnarokSPR()
			spr:DecodeFileContents(BMP_ONLY_SPR)
			assertEquals(spr.version, 1.1)
			assertEquals(spr.paletteStartOffset, 26)

			assertEquals(spr.palette.colors[0].red, 9)
			assertEquals(spr.palette.colors[0].green, 8)
			assertEquals(spr.palette.colors[0].blue, 7)
			assertEquals(spr.palette.colors[0].alpha, 6)

			assertEquals(spr.palette.colors[1].red, 0x42)
			assertEquals(spr.palette.colors[1].green, 0x42)
			assertEquals(spr.palette.colors[1].blue, 0x42)
			assertEquals(spr.palette.colors[1].alpha, 0x42)

			assertEquals(spr.bmpImagesCount, 2)
			assertEquals(spr.tgaImagesCount, 0)

			assertEquals(spr.bmpImages[1].pixelWidth, 2)
			assertEquals(spr.bmpImages[1].pixelHeight, 3)
			assertEquals(spr.bmpImages[1].compressedBufferSize, 6)
			assertEquals(spr.bmpImages[1].decompressedBufferSize, 24)
			assertEquals(#spr.bmpImages[1].pixelBuffer, 6)
			assertEquals(miniz.crc32(tostring(spr.bmpImages[1].pixelBuffer)), 2180413220)

			assertEquals(spr.bmpImages[2].pixelWidth, 3)
			assertEquals(spr.bmpImages[2].pixelHeight, 2)
			assertEquals(spr.bmpImages[2].compressedBufferSize, 6)
			assertEquals(spr.bmpImages[2].decompressedBufferSize, 24)
			assertEquals(#spr.bmpImages[2].pixelBuffer, 6)
			assertEquals(miniz.crc32(tostring(spr.bmpImages[2].pixelBuffer)), 1735309012)
		end)

		it("should be able to decode SPR files using version 2.0 of the format", function()
			local spr = RagnarokSPR()
			spr:DecodeFileContents(BASIC_TGA_SPR)
			assertEquals(spr.version, 2.0)
			assertEquals(spr.paletteStartOffset, 48)

			assertEquals(spr.palette.colors[0].red, 9)
			assertEquals(spr.palette.colors[0].green, 8)
			assertEquals(spr.palette.colors[0].blue, 7)
			assertEquals(spr.palette.colors[0].alpha, 6)

			assertEquals(spr.palette.colors[1].red, 0x42)
			assertEquals(spr.palette.colors[1].green, 0x42)
			assertEquals(spr.palette.colors[1].blue, 0x42)
			assertEquals(spr.palette.colors[1].alpha, 0x42)

			assertEquals(spr.bmpImagesCount, 2)
			assertEquals(spr.tgaImagesCount, 1)

			assertEquals(spr.bmpImages[1].pixelWidth, 2)
			assertEquals(spr.bmpImages[1].pixelHeight, 3)
			assertEquals(spr.bmpImages[1].compressedBufferSize, 6)
			assertEquals(spr.bmpImages[1].decompressedBufferSize, 24)
			assertEquals(#spr.bmpImages[1].pixelBuffer, 6)
			assertEquals(miniz.crc32(tostring(spr.bmpImages[1].pixelBuffer)), 2180413220)

			assertEquals(spr.bmpImages[2].pixelWidth, 3)
			assertEquals(spr.bmpImages[2].pixelHeight, 2)
			assertEquals(spr.bmpImages[2].compressedBufferSize, 6)
			assertEquals(spr.bmpImages[2].decompressedBufferSize, 24)
			assertEquals(#spr.bmpImages[2].pixelBuffer, 6)
			assertEquals(miniz.crc32(tostring(spr.bmpImages[2].pixelBuffer)), 1735309012)

			assertEquals(spr.tgaImages[1].pixelWidth, 1)
			assertEquals(spr.tgaImages[1].pixelHeight, 4)
			assertEquals(#spr.tgaImages[1].pixelBuffer, 16)
			assertEquals(miniz.crc32(tostring(spr.tgaImages[1].pixelBuffer)), 1945965963)
		end)

		it("should be able to decode SPR files using version 2.1 of the format", function()
			local spr = RagnarokSPR()
			spr:DecodeFileContents(TGA_SPR_WITH_RLE)
			assertEquals(spr.version, 2.1)
			assertEquals(spr.paletteStartOffset, 52)

			assertEquals(spr.palette.colors[0].red, 9)
			assertEquals(spr.palette.colors[0].green, 8)
			assertEquals(spr.palette.colors[0].blue, 7)
			assertEquals(spr.palette.colors[0].alpha, 6)

			assertEquals(spr.palette.colors[1].red, 0x42)
			assertEquals(spr.palette.colors[1].green, 0x42)
			assertEquals(spr.palette.colors[1].blue, 0x42)
			assertEquals(spr.palette.colors[1].alpha, 0x42)

			assertEquals(spr.bmpImagesCount, 2)
			assertEquals(spr.tgaImagesCount, 1)

			assertEquals(spr.bmpImages[1].pixelWidth, 2)
			assertEquals(spr.bmpImages[1].pixelHeight, 3)
			assertEquals(spr.bmpImages[1].compressedBufferSize, 6)
			assertEquals(spr.bmpImages[1].decompressedBufferSize, 24)
			assertEquals(#spr.bmpImages[1].pixelBuffer, 6)
			assertEquals(miniz.crc32(tostring(spr.bmpImages[1].pixelBuffer)), 2180413220)

			assertEquals(spr.bmpImages[2].pixelWidth, 3)
			assertEquals(spr.bmpImages[2].pixelHeight, 2)
			assertEquals(spr.bmpImages[2].compressedBufferSize, 6)
			assertEquals(spr.bmpImages[2].decompressedBufferSize, 24)
			assertEquals(#spr.bmpImages[2].pixelBuffer, 6)
			assertEquals(miniz.crc32(tostring(spr.bmpImages[2].pixelBuffer)), 552382195)

			assertEquals(spr.tgaImages[1].pixelWidth, 1)
			assertEquals(spr.tgaImages[1].pixelHeight, 4)
			assertEquals(#spr.tgaImages[1].pixelBuffer, 16)
			assertEquals(miniz.crc32(tostring(spr.tgaImages[1].pixelBuffer)), 1945965963)
		end)
	end)

	describe("DecompressRunLengthEncodedBytes", function()
		it("should return the original pixel data if it didn't contain any runs of zeroes", function()
			local compressedBuffer = buffer.new(3)
			local decompressedBuffer = buffer.new(3)
			compressedBuffer:put("ABC")

			RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
			assertEquals(tostring(decompressedBuffer), "ABC")
		end)

		it("should return the decoded pixel data after resolving all existing runs of zeroes", function()
			local compressedBuffer = buffer.new(9)
			local decompressedBuffer = buffer.new(8)
			compressedBuffer:put("ABC\0\3ASDF")

			RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)

			assertEquals(tostring(decompressedBuffer), "ABC\0\0\0ASDF")
		end)

		it("should add single zeroes to the decompressed buffer if a run of length one is encountered", function()
			local compressedBuffer = buffer.new(2)
			local decompressedBuffer = buffer.new()
			compressedBuffer:put("A\0\1B")

			RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)

			assertEquals(tostring(decompressedBuffer), "A\0B")
		end)

		it("should throw if a zero-length run is encountered", function()
			-- I don't think this can happen in valid RLE buffers? But if it does, ring the alarm so it can be investigated
			local function attemptToDecompressZeroLengthRun()
				local compressedBuffer = buffer.new(2)
				local decompressedBuffer = buffer.new()
				compressedBuffer:put("A\0\0B")

				RagnarokSPR:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
			end
			local expectedErrorMessage = "Encountered zero-length run at index 2 (not an RLE-encoded image?)"
			assertThrows(attemptToDecompressZeroLengthRun, expectedErrorMessage)
		end)
	end)

	describe("GetEmbeddedColorPalette", function()
		it("should return an 8-bit BMP color palette with 256 entries if a string buffer is passed", function()
			local sprFileContents = buffer.new(#TGA_SPR_WITH_RLE):put(TGA_SPR_WITH_RLE)
			local palette = RagnarokSPR:GetEmbeddedColorPalette(sprFileContents)

			assertEquals(palette.colors[0].red, 9)
			assertEquals(palette.colors[0].green, 8)
			assertEquals(palette.colors[0].blue, 7)
			assertEquals(palette.colors[0].alpha, 6)

			assertEquals(palette.colors[1].red, 66)
			assertEquals(palette.colors[1].green, 66)
			assertEquals(palette.colors[1].blue, 66)
			assertEquals(palette.colors[1].alpha, 66)
		end)

		it("should return an 8-bit BMP color palette with 256 entries if a string is passed", function()
			local palette = RagnarokSPR:GetEmbeddedColorPalette(TGA_SPR_WITH_RLE)

			assertEquals(palette.colors[0].red, 9)
			assertEquals(palette.colors[0].green, 8)
			assertEquals(palette.colors[0].blue, 7)
			assertEquals(palette.colors[0].alpha, 6)

			assertEquals(palette.colors[1].red, 66)
			assertEquals(palette.colors[1].green, 66)
			assertEquals(palette.colors[1].blue, 66)
			assertEquals(palette.colors[1].alpha, 66)
		end)
	end)

	describe("ApplyColorPalette", function()
		it("should replace all palette indices with their respective RGBA colors", function()
			local indexedColorImageData = buffer.new(2):put("\0\1")
			local palette = RagnarokSPR:GetEmbeddedColorPalette(TGA_SPR_WITH_RLE)
			local rgbaPixelBuffer = RagnarokSPR:ApplyColorPalette(indexedColorImageData, palette)

			assertEquals(tostring(rgbaPixelBuffer), "\9\8\7\6\66\66\66\66")
		end)
	end)
end)
