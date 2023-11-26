local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local FileAnalyzer = require("Tools.FileAnalyzer")

local console = require("console")

local TEMP_DIR = "data.grf.extracted"
printf("Creating temporary directory: %s", TEMP_DIR)
C_FileSystem.MakeDirectory(TEMP_DIR)

local grf = RagnarokGRF()
grf:Open("data.grf")

console.startTimer("Extracting RSM files")

local fileList = grf:GetFileList()
local rsmFiles = {}
for index, fileEntry in ipairs(fileList) do
	local filePath = grf:GetNormalizedFilePath(fileEntry.name)
	local isRSM = (path.extname(filePath) == ".rsm")
	local isRSM2 = (path.extname(filePath) == ".rsm2")

	if isRSM or isRSM2 then
		local tempFilePath = path.join(TEMP_DIR, filePath)
		table.insert(rsmFiles, tempFilePath)
		if not C_FileSystem.Exists(tempFilePath) then
			local tempDirectory = path.dirname(tempFilePath)
			C_FileSystem.MakeDirectoryTree(tempDirectory)
			printf("Extracting %s to %s", filePath, tempFilePath)
			grf:ExtractFileToDisk(filePath, tempFilePath)
		end
	end
end

grf:Close()

local analysisResult = FileAnalyzer:AnalyzeRSM(rsmFiles)
dump(analysisResult)
console.stopTimer("Extracting RSM files")

local largestFileRSM1 = grf:FindLargestFileByType(".rsm")
local largestFileRSM2 = grf:FindLargestFileByType(".rsm2")

printf(
	"Found largest RSM1 file: %s (%s)",
	largestFileRSM1.name,
	string.filesize(largestFileRSM1.decompressedSizeInBytes)
)
dump(largestFileRSM1)
printf(
	"Found largest RSM2 file: %s (%s)",
	largestFileRSM2.name,
	string.filesize(largestFileRSM2.decompressedSizeInBytes)
)
dump(largestFileRSM2)
