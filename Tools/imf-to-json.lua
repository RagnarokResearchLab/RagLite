local RagnarokIMF = require("Core.FileFormats.RagnarokIMF")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)
local imfs = grf:FindFilesByType("imf")

for index, fileEntry in pairs(imfs) do
	local imfFilePath = fileEntry.name
	printf("Exporting IMF as JSON: %s", imfFilePath)

	local imfBytes = grf:ExtractFileInMemory(imfFilePath)
	local imf = RagnarokIMF()
	imf:DecodeFileContents(imfBytes)

	local jsonString = imf:ToJSON()

	local imfFileName = path.basename(imfFilePath)
	local outputFilePath = path.join("Exports", imfFileName .. ".json")
	C_FileSystem.MakeDirectoryTree(path.dirname(outputFilePath))
	C_FileSystem.WriteFile(outputFilePath, jsonString)
end

grf:Close()
