local Color = require("Core.NativeClient.DebugDraw.Color")

local transform = require("transform")
local bold = transform.bold

describe("Color", function()
	describe("__tostring", function()
		it("should return a human-readable representation of the contained RGBA values", function()
			local color = Color({
				red = 117 / 255,
				green = 169 / 255,
				blue = 255 / 255,
				alpha = 34 / 255,
			})
			local expected = format("%s { red = 0.459, green = 0.663, blue = 1.000, alpha = 0.133 }", bold("Color"))
			assertEquals(tostring(color), expected)
		end)
	end)

	describe("HexStringToRGBA", function()
		it("should return the color represented by the provided hex string", function()
			local input = "0x2275A9FF"
			local expectedResult = {
				red = 117 / 255,
				green = 169 / 255,
				blue = 255 / 255,
				alpha = 34 / 255,
			}
			local result = Color:HexStringToRGBA(input)
			assertEqualNumbers(result.alpha, expectedResult.alpha, 1E-3)
			assertEqualNumbers(result.red, expectedResult.red, 1E-3)
			assertEqualNumbers(result.green, expectedResult.green, 1E-3)
			assertEqualNumbers(result.blue, expectedResult.blue, 1E-3)
		end)
	end)
end)
