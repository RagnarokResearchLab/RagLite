local FogParameters = require("Core.FileFormats.FogParameters")

describe("FogParameters", function()
	describe("DecodeFileContents", function()
		it("should return a table containing the fog parameters", function()
			local inputFileContents = [[
// Comment line (should be discarded, just like the empty line that follows)

mapname.rsw#
0.25#
0.7#
0x3367ABEF#
0.55#

]]
			local fogParametersTable = FogParameters:DecodeFileContents(inputFileContents)

			assertEquals(table.count(fogParametersTable), 1)

			assertEquals(fogParametersTable["mapname"].near, 0.25)
			assertEquals(fogParametersTable["mapname"].far, 0.7)
			assertEquals(fogParametersTable["mapname"].density, 0.55)
			assertEqualNumbers(fogParametersTable["mapname"].color.red, 0.40392157435417, 1E-3)
			assertEqualNumbers(fogParametersTable["mapname"].color.green, 0.67058825492859, 1E-3)
			assertEqualNumbers(fogParametersTable["mapname"].color.blue, 0.93725490570068, 1E-3)
			assertEqualNumbers(fogParametersTable["mapname"].color.alpha, 0.20000000298023, 1E-3)
		end)
	end)
end)
