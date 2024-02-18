local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokRSM = require("Core.FileFormats.RagnarokRSM")

local grf = RagnarokGRF()
grf:Open("data.grf")
local rsmFileName = arg[1] or "data/model/프론테라/민가04.rsm"

local rsmFileContents = grf:ExtractFileInMemory(rsmFileName)
grf:Close()

local rsm = RagnarokRSM()
rsm:DecodeFileContents(rsmFileContents)

local jsonFileContents = rsm:ToJSON()

local jsonFilePath = path.join("Exports", path.basename(rsmFileName) .. ".json")
printf("Exporting decoded file contents to %s", jsonFilePath)
C_FileSystem.WriteFile(jsonFilePath, jsonFileContents)
