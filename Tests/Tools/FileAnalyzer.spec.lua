local FileAnalyzer = require("Tools.FileAnalyzer")

local gndFiles = {
	path.join("Tests", "Fixtures", "no-water-plane.gnd"),
	path.join("Tests", "Fixtures", "single-water-plane.gnd"),
	path.join("Tests", "Fixtures", "multiple-water-planes.gnd"),
}

describe("FileAnalyzer", function()
	describe("AnalyzeGND", function()
		it("should return a summary of the metadata found in the given GND files", function()
			local analysisResult = FileAnalyzer:AnalyzeGND(gndFiles)

			assertEquals(analysisResult.numFilesAnalyzed, 3)

			assertEquals(analysisResult.fields.version[1.7], 1)
			assertEquals(analysisResult.fields.version[1.8], 1)
			assertEquals(analysisResult.fields.version[1.9], 1)

			assertEquals(analysisResult.fields.diffuseTextureCount[2], 3)
			assertEquals(analysisResult.fields.gridSizeU[1], 3)
			assertEquals(analysisResult.fields.gridSizeV[2], 3)
		end)
	end)
end)
