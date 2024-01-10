local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local filesToExtract = { unpack(arg) }
local grfPath = "data.grf"
local destinationFolder = grfPath .. ".extracted"

local grf = RagnarokGRF()
grf:Open(grfPath)

printf("Extracting %d file(s) from archive %s into folder %s", #filesToExtract, grfPath, destinationFolder)

for index, fileToExtract in ipairs(filesToExtract) do
	local destinationPath = path.join(destinationFolder, fileToExtract)
	C_FileSystem.MakeDirectoryTree(path.dirname(destinationPath))

	printf("Saving %s to %s", fileToExtract, destinationPath)
	grf:ExtractFileToDisk(fileToExtract, destinationPath)
end

grf:Close()
