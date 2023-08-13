local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokTools = require("Tools.RagnarokTools")

local sprFilePath = arg[1] or "data/sprite/몬스터/bakonawa.spr"
printf("Dumping SPR frames: %s", sprFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local sprBytes = grf:ExtractFileInMemory(sprFilePath)

grf:Close()

RagnarokTools:ExportImagesFromSPR(sprBytes)
