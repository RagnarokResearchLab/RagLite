local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local FileAnalyzer = require("Tools.FileAnalyzer")

local console = require("console")

local TEMP_DIR = "data.grf.extracted"
printf("Creating temporary directory: %s", TEMP_DIR)
C_FileSystem.MakeDirectory(TEMP_DIR)

local grf = RagnarokGRF()
grf:Open("data.grf")

console.startTimer("Extracting ACT files")

local fileList = grf:GetFileList()
local actFiles = {}
for index, fileEntry in ipairs(fileList) do
	local filePath = fileEntry.name
	local isACT = (path.extname(filePath) == ".act")

	if isACT then
		local tempFilePath = path.join(TEMP_DIR, fileEntry.name)
		table.insert(actFiles, tempFilePath)
		if not C_FileSystem.Exists(tempFilePath) then
			local tempDirectory = path.dirname(tempFilePath)
			C_FileSystem.MakeDirectoryTree(tempDirectory)
			printf("Extracting %s to %s", filePath, tempFilePath)
			grf:ExtractFileToDisk(fileEntry.name, tempFilePath)
		end
	end
end

grf:Close()

local analysisResult = FileAnalyzer:AnalyzeACT(actFiles)
dump(analysisResult)

console.stopTimer("Extracting ACT files")
