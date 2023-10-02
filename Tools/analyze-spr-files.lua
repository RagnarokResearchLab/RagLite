local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local FileAnalyzer = require("Tools.FileAnalyzer")

local console = require("console")

local TEMP_DIR = "data.extracted.grf"
printf("Creating temporary directory: %s", TEMP_DIR)
C_FileSystem.MakeDirectory(TEMP_DIR)

local grf = RagnarokGRF()
grf:Open("data.grf")

console.startTimer("Extracting SPR files")

local fileList = grf:GetFileList()
local sprFiles = {}
for index, fileEntry in ipairs(fileList) do
	local filePath = fileEntry.name
	local isSPR = (path.extname(filePath) == ".spr")

	if isSPR then
		local tempFilePath = path.join(TEMP_DIR, fileEntry.name)
		table.insert(sprFiles, tempFilePath)
		if not C_FileSystem.Exists(tempFilePath) then
			local tempDirectory = path.dirname(tempFilePath)
			C_FileSystem.MakeDirectoryTree(tempDirectory)
			printf("Extracting %s to %s", filePath, tempFilePath)
			grf:ExtractFileToDisk(fileEntry.name, tempFilePath)
		end
	end
end

grf:Close()

local analysisResult = FileAnalyzer:AnalyzeSPR(sprFiles)
dump(analysisResult)

console.stopTimer("Extracting SPR files")

local json = require("json")
local jsonString = json.prettier(analysisResult.fields.version)
local outputFilePath = path.join("Exports", "spr-versions.json")
C_FileSystem.WriteFile(outputFilePath, jsonString)
