local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local fileToExtract = arg[1] or error("Arguments: fileToExtract [destinationFolder optionalArchiveName]")
local grfPath = arg[3] or "data.grf"
local destinationFolder = arg[2] or grfPath .. ".extracted"
local destinationPath = path.join(destinationFolder, fileToExtract)

C_FileSystem.MakeDirectoryTree(path.dirname(destinationPath))
printf("Saving %s to %s", fileToExtract, destinationPath)

local grf = RagnarokGRF()
grf:Open(grfPath)
grf:ExtractFileToDisk(fileToExtract, destinationPath)
grf:Close()
