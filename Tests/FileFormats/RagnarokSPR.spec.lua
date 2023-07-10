local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

-- Features: BMP palette appended, BMP and TGA frames, RLE-encoded image data
-- Assertions: No system palette (ancient versions), works on all files in the kRO GRF, works with old (ArcExe/alpha) files?
-- Versions: 0.2 Arcturus (bug? crow.spr = 2.0?), 1.1 Arcturus (mariaspr), 1.2 (2.1) default, 2.2 and 2.3 TBD?
-- TBD: Are 1.0, 2.0, 2.2/2.3 used anywhere?
local SPR_WITH_RLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v2-1.spr"))
-- local GND_WITH_SINGLE_WATER_PLANE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "single-water-plane.gnd"))
-- local GND_WITH_MULTIPLE_WATER_PLANES =
-- 	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "multiple-water-planes.gnd"))

describe("RagnarokSPR", function()
	local spr = RagnarokSPR()
	describe("DecodeFileContents", function()
		it("should be able to decode SPR files using version 2.1 of the format", function()
			spr:DecodeFileContents(SPR_WITH_RLE)

			assertEquals(spr.signature, "SP")
			assertEquals(spr.version, 2.1)
			assertEquals(spr.paletteStartOffset, 104233)

			assertEquals(spr.palette.colors[0].red, 255)
			assertEquals(spr.palette.colors[0].green, 0)
			assertEquals(spr.palette.colors[0].blue, 0)
			assertEquals(spr.palette.colors[0].alpha, 0)

			assertEquals(spr.bmpImagesCount, 41) -- TODO 2
			assertEquals(spr.tgaImagesCount, 1) -- TODO 2

			assertEquals(spr.bmpImages[0].pixelWidth, 37)
			assertEquals(spr.bmpImages[0].pixelHeight, 36)
			assertEquals(spr.bmpImages[0].compressedBufferSize, 990)
			assertEquals(spr.bmpImages[0].decompressedBufferSize, 1332 * 4)
			assertEquals(#spr.bmpImages[0].decompressedImageBuffer, 1332)
			-- CRC32?

			assertEquals(spr.bmpImages[40].pixel_width, 37)
			assertEquals(spr.bmpImages[40].pixel_height, 36)
			assertEquals(spr.bmpImages[40].compressed_buffer_size, 990)
			assertEquals(spr.bmpImages[40].decompressed_buffer_size, 1332)

		end)
	end)

	describe("DecompressRunLengthEncodedBytes", function()
		it("should return the original pixel data if it didn't contain any runs of zeroes", function()
			local compressedBuffer = buffer.new(3)
			local decompressedBuffer = buffer.new(3)
			compressedBuffer:put("ABC")

			spr:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
			assertEquals(tostring(decompressedBuffer), "ABC")
		end)

		it("should return the decoded pixel data after resolving all existing runs of zeroes", function()
			local compressedBuffer = buffer.new(9)
			local decompressedBuffer = buffer.new(8)
			compressedBuffer:put("ABC\0\3ASDF")

			spr:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
			print(tostring(decompressedBuffer))
			local ffi = require("ffi")
			for i = 0, #decompressedBuffer - 1, 1 do
				local ref= decompressedBuffer:ref()
				print(i, ffi.string(ffi.new("uint8_t[1]", ref[i])))
			end
			assertEquals(tostring(decompressedBuffer), "ABC\0\0\0ASDF")
		end)

		it("should add single zeroes to the decompressed buffer if a run of length one is encountered", function()
			local compressedBuffer = buffer.new(2)
			local decompressedBuffer = buffer.new()
			compressedBuffer:put("A\0\1B")

			spr:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
			local ffi = require("ffi")
			for i = 0, #decompressedBuffer - 1, 1 do
				local ref= decompressedBuffer:ref()
				print(i, ffi.string(ffi.new("uint8_t[1]", ref[i])))
			end
			assertEquals(tostring(decompressedBuffer), "A\0B")
		end)

		it("should throw if a zero-length run is encountered", function()
			-- TODO (00 -_ not valid RLE)
			-- I don't think this can happen in valid RLE buffers? But if it does, ring the alarm so it can be investigated
			local function attemptToDecompressZeroLengthRun()
			local compressedBuffer = buffer.new(2)
			local decompressedBuffer = buffer.new()
			compressedBuffer:put("A\0\0B")

			spr:DecompressRunLengthEncodedBytes(compressedBuffer, decompressedBuffer)
			local ffi = require("ffi")
			for i = 0, #decompressedBuffer - 1, 1 do
				local ref= decompressedBuffer:ref()
				print(i, ffi.string(ffi.new("uint8_t[1]", ref[i])))
			end
			-- assertEquals(tostring(decompressedBuffer), "A\0\0B")
		end
		local expectedErrorMessage = "Encountered zero-length run at index 2 (not an RLE-encoded image?)"
		assertThrows(attemptToDecompressZeroLengthRun, expectedErrorMessage)
		end)
	end)
end)
