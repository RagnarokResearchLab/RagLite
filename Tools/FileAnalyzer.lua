local RagnarokGND = require("Core.FileFormats.RagnarokGND")

local FileAnalyzer = {}

function FileAnalyzer:AnalyzeGND(gndFiles)
	local analysisResult = {
		numFilesAnalyzed = 0,
		fields = {
			version = {},
			diffuseTextureCount = {},
			gridSizeU = {},
			gridSizeV = {},
		},
	}

	local gnd = RagnarokGND()
	for index, filePath in ipairs(gndFiles) do
		printf("Analyzing file: %s", filePath)

		local gndFileContents = C_FileSystem.ReadFile(filePath)
		gnd:DecodeFileContents(gndFileContents)

		analysisResult.fields.version[gnd.version] = analysisResult.fields.version[gnd.version] or 0
		analysisResult.fields.version[gnd.version] = analysisResult.fields.version[gnd.version] + 1

		analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount] = analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount]
			or 0
		analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount] = analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount]
			+ 1

		analysisResult.fields.gridSizeU[gnd.gridSizeU] = analysisResult.fields.gridSizeU[gnd.gridSizeU] or 0
		analysisResult.fields.gridSizeU[gnd.gridSizeU] = analysisResult.fields.gridSizeU[gnd.gridSizeU] + 1

		analysisResult.fields.gridSizeV[gnd.gridSizeV] = analysisResult.fields.gridSizeV[gnd.gridSizeV] or 0
		analysisResult.fields.gridSizeV[gnd.gridSizeV] = analysisResult.fields.gridSizeV[gnd.gridSizeV] + 1

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

return FileAnalyzer
