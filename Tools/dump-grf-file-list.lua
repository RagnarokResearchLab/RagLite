local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local json = require("json")

local grfPath = arg[1] or "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)
grf:Close()

local jsonString = json.prettier(grf:GetFileList())
local jsonFilePath = path.join("Exports", path.basename(grfPath) .. ".json")
C_FileSystem.MakeDirectoryTree(path.dirname(jsonFilePath))
C_FileSystem.WriteFile(jsonFilePath, jsonString)
