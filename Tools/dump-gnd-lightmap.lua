local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokTools = require("Tools.RagnarokTools")

local gndFileName = arg[1] or "geffen"
local gndFilePath = "data/" .. gndFileName .. ".gnd"
printf("Dumping GND lightmap: %s", gndFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local gndBytes = grf:ExtractFileInMemory(gndFilePath)

grf:Close()

RagnarokTools:ExportLightmapsFromGND(gndBytes)
