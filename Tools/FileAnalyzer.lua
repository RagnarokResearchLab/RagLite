local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

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

function FileAnalyzer:AnalyzeSPR(sprFiles)
	local analysisResult = {
		numFilesAnalyzed = 0,
		fields = {
			version = {},
			bmpImagesCount = {},
			tgaImagesCount = {},
		},
	}

	local spr = RagnarokSPR()
	for index, filePath in ipairs(sprFiles) do
		printf("Analyzing file: %s", filePath)

		local sprFileContents = C_FileSystem.ReadFile(filePath)
		spr:DecodeFileContents(sprFileContents)

		analysisResult.fields.version[spr.version] = analysisResult.fields.version[spr.version] or 0
		analysisResult.fields.version[spr.version] = analysisResult.fields.version[spr.version] + 1

		analysisResult.fields.bmpImagesCount[spr.bmpImagesCount] = analysisResult.fields.bmpImagesCount[spr.bmpImagesCount]
			or 0
		analysisResult.fields.tgaImagesCount[spr.tgaImagesCount] = analysisResult.fields.tgaImagesCount[spr.tgaImagesCount]
			or 0
		analysisResult.fields.bmpImagesCount[spr.bmpImagesCount] = analysisResult.fields.bmpImagesCount[spr.bmpImagesCount]
			+ 1
		analysisResult.fields.tgaImagesCount[spr.tgaImagesCount] = analysisResult.fields.tgaImagesCount[spr.tgaImagesCount]
			+ 1

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

return FileAnalyzer
