local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")

local json = require("json")

local rswFileName = arg[1] or "ecl_fild01"
local rswFilePath = "data/" .. rswFileName .. ".rsw"
printf("Dumping RSW contents: %s", rswFilePath)

local grfPath = "data.grf"
local grf = RagnarokGRF()
grf:Open(grfPath)

local rswBytes = grf:ExtractFileInMemory(rswFilePath)

grf:Close()

local rsw = RagnarokRSW()
rsw:DecodeFileContents(rswBytes)

local exportFilePathRoot = path.join("Exports", rswFileName .. ".json")

local sceneObjects = {
	version = rsw.version,
	buildNumber = rsw.buildNumber,
	directionalLight = rsw.directionalLight,
	ambientLight = rsw.ambientLight,
	contrastCorrectionColor = rsw.contrastCorrectionColor,
	prebakedShadowmapAlpha = rsw.prebakedShadowmapAlpha,
	animatedProps = rsw.animatedProps,
	spatialAudioSources = rsw.spatialAudioSources,
	dynamicLightSources = rsw.dynamicLightSources,
	particleEffectEmitters = rsw.particleEffectEmitters,
}

local jsonString = json.prettier(sceneObjects)
C_FileSystem.WriteFile(exportFilePathRoot, jsonString)
