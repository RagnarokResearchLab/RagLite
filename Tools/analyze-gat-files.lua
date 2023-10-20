local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local FileAnalyzer = require("Tools.FileAnalyzer")

local console = require("console")

local TEMP_DIR = "data.extracted.grf"
printf("Creating temporary directory: %s", TEMP_DIR)
C_FileSystem.MakeDirectory(TEMP_DIR)

local grf = RagnarokGRF()
grf:Open("data.grf")

console.startTimer("Extracting GAT files")

local fileList = grf:GetFileList()
local gatFiles = {}
for index, fileEntry in ipairs(fileList) do
	local filePath = fileEntry.name
	local isGAT = (path.extname(filePath) == ".gat")

	if isGAT then
		local tempFilePath = path.join(TEMP_DIR, filePath)
		table.insert(gatFiles, tempFilePath)
		if not C_FileSystem.Exists(tempFilePath) then
			local tempDirectory = path.dirname(tempFilePath)
			C_FileSystem.MakeDirectoryTree(tempDirectory)
			printf("Extracting %s to %s", filePath, tempFilePath)
			grf:ExtractFileToDisk(filePath, tempFilePath)
		end
	end
end

grf:Close()

local analysisResult = FileAnalyzer:AnalyzeGAT(gatFiles)
dump(analysisResult)

console.stopTimer("Extracting GAT files")
