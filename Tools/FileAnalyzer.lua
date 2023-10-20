local RagnarokACT = require("Core.FileFormats.RagnarokACT")
local RagnarokGAT = require("Core.FileFormats.RagnarokGAT")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")
local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

local math_max = math.max
local math_min = math.min

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

		analysisResult.fields.version[gnd.version] = analysisResult.fields.version[gnd.version] or 0
		analysisResult.fields.version[gnd.version] = analysisResult.fields.version[gnd.version] + 1

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

		analysisResult.fields.version[spr.version] = analysisResult.fields.version[spr.version] or 0
		analysisResult.fields.version[spr.version] = analysisResult.fields.version[spr.version] + 1

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

		analysisResult.fields.version[rsw.version] = analysisResult.fields.version[rsw.version] or 0
		analysisResult.fields.version[rsw.version] = analysisResult.fields.version[rsw.version] + 1

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
		C_FileSystem.Delete("act-analysis-errors.log")

		local actFileContents = C_FileSystem.ReadFile(filePath)
		local act = RagnarokACT()
		local success, errMsg = pcall(function()
			act:DecodeFileContents(actFileContents)
		end)
		if not success then
			printf("Failed to decode %s: %s", filePath, errMsg) -- Can remove once #180 is resolved
			C_FileSystem.AppendFile("act-analysis-errors.log", filePath .. " - " .. errMsg .. "\n")
		end

		for fieldName, numOccurencesPerValue in pairs(analysisResult.fields) do
		end

		analysisResult.fields.version[act.version] = analysisResult.fields.version[act.version] or 0
		analysisResult.fields.version[act.version] = analysisResult.fields.version[act.version] + 1

		analysisResult.fields.numAnimationClips[act.numAnimationClips] = analysisResult.fields.numAnimationClips[act.numAnimationClips]
			or 0
		analysisResult.fields.numAnimationClips[act.numAnimationClips] = analysisResult.fields.numAnimationClips[act.numAnimationClips]
			+ 1

		analysisResult.fields.unknownHeaderField[act.unknownHeaderField] = analysisResult.fields.unknownHeaderField[act.unknownHeaderField]
			or 0
		analysisResult.fields.unknownHeaderField[act.unknownHeaderField] = analysisResult.fields.unknownHeaderField[act.unknownHeaderField]
			+ 1

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

function FileAnalyzer:AnalyzeGAT(gatFiles)
	local analysisResult = {
		numFilesAnalyzed = 0,
		fields = {
			version = {},
			mapU = {},
			mapV = {},
			terrainTypes = {},
			terrainFlags = {
				isWalkable = 0,
				isSnipeable = 0,
				isWater = 0,
			},
			renewalWaterFlags = {},
		},
	}

	for index, filePath in ipairs(gatFiles) do
		printf("Analyzing file: %s", filePath)

		local fileContents = C_FileSystem.ReadFile(filePath)
		local gat = RagnarokGAT()
		gat:DecodeFileContents(fileContents)

		analysisResult.fields.version[gat.version] = analysisResult.fields.version[gat.version] or 0
		analysisResult.fields.version[gat.version] = analysisResult.fields.version[gat.version] + 1

		analysisResult.fields.mapU[gat.mapU] = analysisResult.fields.mapU[gat.mapU] or 0
		analysisResult.fields.mapV[gat.mapV] = analysisResult.fields.mapV[gat.mapV] or 0
		analysisResult.fields.mapU[gat.mapU] = analysisResult.fields.mapU[gat.mapU] + 1
		analysisResult.fields.mapV[gat.mapV] = analysisResult.fields.mapV[gat.mapV] + 1

		-- Storing the individual values is overkill (and doesn't even work with regular tables as there are too many)
		local minObservedAltitude = math.huge
		local maxObservedAltitude = 0
		for mapV = 1, gat.mapV, 1 do
			for mapU = 1, gat.mapU, 1 do
				local tileID = gat:MapPositionToTileID(mapU, mapV)
				local tile = gat.collisionMap[tileID]

				minObservedAltitude = math_min(minObservedAltitude, tile.altitude_southwest)
				minObservedAltitude = math_min(minObservedAltitude, tile.altitude_southeast)
				minObservedAltitude = math_min(minObservedAltitude, tile.altitude_northwest)
				minObservedAltitude = math_min(minObservedAltitude, tile.altitude_northeast)

				maxObservedAltitude = math_max(maxObservedAltitude, tile.altitude_southwest)
				maxObservedAltitude = math_max(maxObservedAltitude, tile.altitude_southeast)
				maxObservedAltitude = math_max(maxObservedAltitude, tile.altitude_northwest)
				maxObservedAltitude = math_max(maxObservedAltitude, tile.altitude_northeast)

				analysisResult.fields.terrainTypes[tile.terrain_flags] = analysisResult.fields.terrainTypes[tile.terrain_flags]
					or 0
				analysisResult.fields.terrainTypes[tile.terrain_flags] = analysisResult.fields.terrainTypes[tile.terrain_flags]
					+ 1

				if gat:IsObstructedTerrain(mapU, mapV) then
					analysisResult.fields.terrainFlags.isWalkable = analysisResult.fields.terrainFlags.isWalkable + 1
				end

				if not gat:IsTerrainBlockingRangedAttacks(mapU, mapV) then
					analysisResult.fields.terrainFlags.isSnipeable = analysisResult.fields.terrainFlags.isSnipeable + 1
				end

				if gat:IsWater(mapU, mapV) then
					analysisResult.fields.terrainFlags.isWater = analysisResult.fields.terrainFlags.isWater + 1
				end

				-- Don't know what the RE water flag does exactly, so can't do much with it right now...
				analysisResult.fields.renewalWaterFlags[tile.renewal_water_flag] = analysisResult.fields.renewalWaterFlags[tile.renewal_water_flag]
					or 0
				analysisResult.fields.renewalWaterFlags[tile.renewal_water_flag] = analysisResult.fields.renewalWaterFlags[tile.renewal_water_flag]
					+ 1
			end
		end

		analysisResult.minObservedAltitude = minObservedAltitude
		analysisResult.maxObservedAltitude = maxObservedAltitude

		analysisResult.numFilesAnalyzed = analysisResult.numFilesAnalyzed + 1
	end

	return analysisResult
end

return FileAnalyzer
