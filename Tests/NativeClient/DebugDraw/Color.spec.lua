local Color = require("Core.NativeClient.DebugDraw.Color")

describe("Color", function()
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
