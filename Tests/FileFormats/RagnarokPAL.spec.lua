local RagnarokPAL = require("Core.FileFormats.RagnarokPAL")

local RGBA_PALETTE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "rgba-palette.pal"))

describe("RagnarokPAL", function()
	describe("DecodeFileContents", function()
		it("should return an 8-bit BMP color palette with 256 entries if a string buffer is passed", function()
			local sprFileContents = buffer.new(#RGBA_PALETTE):put(RGBA_PALETTE)
			local palette = RagnarokPAL:DecodeFileContents(sprFileContents)

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
			local palette = RagnarokPAL:DecodeFileContents(RGBA_PALETTE)

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
end)
