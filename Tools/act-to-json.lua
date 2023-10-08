local RagnarokACT = require("Core.FileFormats.RagnarokACT")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local actFilePath = arg[1] or "data/sprite/몬스터/poring.act"
local source = arg[2] or "data.grf"
printf("Exporting ACT as JSON: %s (using source: %s)", actFilePath, source)

local actBytes
local isSourceGRF = path.extname(source:lower()) == ".grf"
if isSourceGRF then
	local grfPath = "data.grf"
	local grf = RagnarokGRF()
	grf:Open(grfPath)
	actBytes = grf:ExtractFileInMemory(actFilePath)
	grf:Close()
else
	actBytes = C_FileSystem.ReadFile(actFilePath)
end

local act = RagnarokACT()
act:DecodeFileContents(actBytes)

local jsonString = act:ToJSON()

local actFileName = path.basename(actFilePath)
local outputFilePath = path.join("Exports", actFileName .. ".json")
C_FileSystem.MakeDirectoryTree(path.dirname(outputFilePath))
C_FileSystem.WriteFile(outputFilePath, jsonString)
