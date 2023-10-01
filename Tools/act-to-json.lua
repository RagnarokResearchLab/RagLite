local RagnarokACT = require("Core.FileFormats.RagnarokACT")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local json = require("json")

local actFileName = arg[1] or "cursors"
local actFilePath = "data/sprite/" .. actFileName .. ".act"
printf("Exporting ACT as JSON: %s", actFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local actBytes = grf:ExtractFileInMemory(actFilePath)

grf:Close()

local act = RagnarokACT()
act:DecodeFileContents(actBytes)

local actInfo = {
	version = act.version,
	unknownHeaderField = act.unknownHeaderField,
	numAnimationClips = act.numAnimationClips,
	animationClips = act.animationClips,
	animationEvents = act.animationEvents,
	timings = act.timings,
}

local jsonString = json.prettier(actInfo)

local outputFilePath = path.join("Exports", actFileName .. ".act.json")
C_FileSystem.MakeDirectoryTree(path.dirname(outputFilePath))
C_FileSystem.WriteFile(outputFilePath, jsonString)
