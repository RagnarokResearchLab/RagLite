local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokTools = require("Tools.RagnarokTools")

local gatFileName = arg[1] or "pay_dun00"
local gatFilePath = "data/" .. gatFileName .. ".gat"
printf("Dumping GAT terrain images: %s", gatFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local gatBytes = grf:ExtractFileInMemory(gatFilePath)

grf:Close()

RagnarokTools:ExportCollisionMapFromGAT(gatBytes)
RagnarokTools:ExportHeightMapFromGAT(gatBytes)
RagnarokTools:ExportTerrainMapFromGAT(gatBytes)
