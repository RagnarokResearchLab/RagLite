local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokTools = require("Tools.RagnarokTools")

local rswFileName = arg[1] or "niflheim"
local rswFilePath = "data/" .. rswFileName .. ".rsw"
printf("Dumping RSW scene graph: %s", rswFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local rswBytes = grf:ExtractFileInMemory(rswFilePath)

grf:Close()

RagnarokTools:ExportSceneGraphFromRSW(rswBytes)
