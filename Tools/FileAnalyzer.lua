local RagnarokACT = require("Core.FileFormats.RagnarokACT")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")
local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

local FileAnalyzer = {}

function FileAnalyzer:AnalyzeGND(gndFiles)
	local analysisResult = {
		numFilesAnalyzed = 0,
		fields = {
			version = {},
			diffuseTextureCount = {},
			gridSizeU = {},
			gridSizeV = {},
		},
	}

	for index, filePath in ipairs(gndFiles) do
		printf("Analyzing file: %s", filePath)

		local gndFileContents = C_FileSystem.ReadFile(filePath)
		local gnd = RagnarokGND()
		gnd:DecodeFileContents(gndFileContents)

		local stringKey = tostring(gnd.version)
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] or 0
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] + 1

		analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount] = analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount]
			or 0
		analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount] = analysisResult.fields.diffuseTextureCount[gnd.diffuseTextureCount]
			+ 1

		analysisResult.fields.gridSizeU[gnd.gridSizeU] = analysisResult.fields.gridSizeU[gnd.gridSizeU] or 0
		analysisResult.fields.gridSizeU[gnd.gridSizeU] = analysisResult.fields.gridSizeU[gnd.gridSizeU] + 1

		analysisResult.fields.gridSizeV[gnd.gridSizeV] = analysisResult.fields.gridSizeV[gnd.gridSizeV] or 0
		analysisResult.fields.gridSizeV[gnd.gridSizeV] = analysisResult.fields.gridSizeV[gnd.gridSizeV] + 1

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

function FileAnalyzer:AnalyzeSPR(sprFiles)
	local analysisResult = {
		numFilesAnalyzed = 0,
		fields = {
			version = {},
			bmpImagesCount = {},
			tgaImagesCount = {},
		},
	}

	for index, filePath in ipairs(sprFiles) do
		printf("Analyzing file: %s", filePath)

		local sprFileContents = C_FileSystem.ReadFile(filePath)
		local spr = RagnarokSPR()
		spr:DecodeFileContents(sprFileContents)

		local stringKey = tostring(spr.version)
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] or 0
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] + 1

		analysisResult.fields.bmpImagesCount[spr.bmpImagesCount] = analysisResult.fields.bmpImagesCount[spr.bmpImagesCount]
			or 0
		analysisResult.fields.tgaImagesCount[spr.tgaImagesCount] = analysisResult.fields.tgaImagesCount[spr.tgaImagesCount]
			or 0
		analysisResult.fields.bmpImagesCount[spr.bmpImagesCount] = analysisResult.fields.bmpImagesCount[spr.bmpImagesCount]
			+ 1
		analysisResult.fields.tgaImagesCount[spr.tgaImagesCount] = analysisResult.fields.tgaImagesCount[spr.tgaImagesCount]
			+ 1

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

function FileAnalyzer:AnalyzeRSW(rswFiles)
	local analysisResult = {
		numFilesAnalyzed = 0,
		fields = {
			version = {},
			buildNumber = {},
			unknownRenderFlag = {},
			iniFile = {},
			scrFile = {},
			numSceneObjects = {},
			numAnimatedProps = {},
			numDynamicLightSources = {},
			numSpatialAudioSources = {},
			numParticleEffectEmitters = {},
			unknownRenewalPropFlag = {},
			isSolid = {},
		},
	}

	for index, filePath in ipairs(rswFiles) do
		printf("Analyzing file: %s", filePath)

		local rswFileContents = C_FileSystem.ReadFile(filePath)
		local rsw = RagnarokRSW()
		rsw:DecodeFileContents(rswFileContents)

		local stringKey = tostring(rsw.version)
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] or 0
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] + 1

		analysisResult.fields.buildNumber[rsw.buildNumber] = analysisResult.fields.buildNumber[rsw.buildNumber] or 0
		analysisResult.fields.buildNumber[rsw.buildNumber] = analysisResult.fields.buildNumber[rsw.buildNumber] + 1

		analysisResult.fields.unknownRenderFlag[rsw.unknownRenderFlag] = analysisResult.fields.unknownRenderFlag[rsw.unknownRenderFlag]
			or 0
		analysisResult.fields.unknownRenderFlag[rsw.unknownRenderFlag] = analysisResult.fields.unknownRenderFlag[rsw.unknownRenderFlag]
			+ 1

		analysisResult.fields.iniFile[rsw.iniFile] = analysisResult.fields.iniFile[rsw.iniFile] or 0
		analysisResult.fields.iniFile[rsw.iniFile] = analysisResult.fields.iniFile[rsw.iniFile] + 1

		analysisResult.fields.scrFile[rsw.scrFile] = analysisResult.fields.scrFile[rsw.scrFile] or 0
		analysisResult.fields.scrFile[rsw.scrFile] = analysisResult.fields.scrFile[rsw.scrFile] + 1

		analysisResult.fields.numSceneObjects[rsw.numSceneObjects] = analysisResult.fields.numSceneObjects[rsw.numSceneObjects]
			or 0
		analysisResult.fields.numSceneObjects[rsw.numSceneObjects] = analysisResult.fields.numSceneObjects[rsw.numSceneObjects]
			+ 1

		analysisResult.fields.numAnimatedProps[#rsw.animatedProps] = analysisResult.fields.numAnimatedProps[#rsw.animatedProps]
			or 0
		analysisResult.fields.numAnimatedProps[#rsw.animatedProps] = analysisResult.fields.numAnimatedProps[#rsw.animatedProps]
			+ 1

		analysisResult.fields.numDynamicLightSources[#rsw.dynamicLightSources] = analysisResult.fields.numDynamicLightSources[#rsw.dynamicLightSources]
			or 0
		analysisResult.fields.numDynamicLightSources[#rsw.dynamicLightSources] = analysisResult.fields.numDynamicLightSources[#rsw.dynamicLightSources]
			+ 1

		analysisResult.fields.numSpatialAudioSources[#rsw.spatialAudioSources] = analysisResult.fields.numSpatialAudioSources[#rsw.spatialAudioSources]
			or 0
		analysisResult.fields.numSpatialAudioSources[#rsw.spatialAudioSources] = analysisResult.fields.numSpatialAudioSources[#rsw.spatialAudioSources]
			+ 1

		analysisResult.fields.numParticleEffectEmitters[#rsw.particleEffectEmitters] = analysisResult.fields.numParticleEffectEmitters[#rsw.particleEffectEmitters]
			or 0
		analysisResult.fields.numParticleEffectEmitters[#rsw.particleEffectEmitters] = analysisResult.fields.numParticleEffectEmitters[#rsw.particleEffectEmitters]
			+ 1

		for i, doodad in ipairs(rsw.animatedProps) do
			analysisResult.fields.unknownRenewalPropFlag[doodad.unknownMysteryByte] = analysisResult.fields.unknownRenewalPropFlag[doodad.unknownMysteryByte]
				or 0
			analysisResult.fields.unknownRenewalPropFlag[doodad.unknownMysteryByte] = analysisResult.fields.unknownRenewalPropFlag[doodad.unknownMysteryByte]
				+ 1

			analysisResult.fields.isSolid[doodad.isSolid] = analysisResult.fields.isSolid[doodad.isSolid] or 0
			analysisResult.fields.isSolid[doodad.isSolid] = analysisResult.fields.isSolid[doodad.isSolid] + 1
		end

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

function FileAnalyzer:AnalyzeACT(actFiles)
	local analysisResult = {
		numFilesAnalyzed = 0,
		fields = {
			version = {},
			numAnimationClips = {},
			unknownHeaderField = {},
		},
	}

	for index, filePath in ipairs(actFiles) do
		printf("Analyzing file: %s", filePath)

		local actFileContents = C_FileSystem.ReadFile(filePath)
		local act = RagnarokACT()
		act:DecodeFileContents(actFileContents)

		for fieldName, numOccurencesPerValue in pairs(analysisResult.fields) do
		end

		-- Hacky: string keys are needed for JSON exports
		local stringKey = tostring(act.version)
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] or 0
		analysisResult.fields.version[stringKey] = analysisResult.fields.version[stringKey] + 1

		analysisResult.fields.numAnimationClips[act.numAnimationClips] = analysisResult.fields.numAnimationClips[act.numAnimationClips]
			or 0
		analysisResult.fields.numAnimationClips[act.numAnimationClips] = analysisResult.fields.numAnimationClips[act.numAnimationClips]
			+ 1

		analysisResult.fields.unknownHeaderField[act.unknownHeaderField] = analysisResult.fields.unknownHeaderField[act.unknownHeaderField]
			or 0
		analysisResult.fields.unknownHeaderField[act.unknownHeaderField] = analysisResult.fields.unknownHeaderField[act.unknownHeaderField]
			+ 1

		-- analysisResult.fields.bmpImagesCount[spr.bmpImagesCount] = analysisResult.fields.bmpImagesCount[spr.bmpImagesCount]
		-- 	or 0
		-- analysisResult.fields.tgaImagesCount[spr.tgaImagesCount] = analysisResult.fields.tgaImagesCount[spr.tgaImagesCount]
		-- 	or 0
		-- analysisResult.fields.bmpImagesCount[spr.bmpImagesCount] = analysisResult.fields.bmpImagesCount[spr.bmpImagesCount]
		-- 	+ 1
		-- analysisResult.fields.tgaImagesCount[spr.tgaImagesCount] = analysisResult.fields.tgaImagesCount[spr.tgaImagesCount]
		-- 	+ 1

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

return FileAnalyzer
