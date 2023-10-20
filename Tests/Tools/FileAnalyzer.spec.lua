local FileAnalyzer = require("Tools.FileAnalyzer")
local QuadTreeRange = require("Core.FileFormats.RSW.QuadTreeRange")

local gndFiles = {
	path.join("Tests", "Fixtures", "no-water-plane.gnd"),
	path.join("Tests", "Fixtures", "single-water-plane.gnd"),
	path.join("Tests", "Fixtures", "multiple-water-planes.gnd"),
}

local sprFiles = {
	path.join("Tests", "Fixtures", "bmp-paletted.spr"),
	path.join("Tests", "Fixtures", "bmp-tga-paletted.spr"),
	path.join("Tests", "Fixtures", "rle-bmp-tga-paletted.spr"),
}

local rswFiles = {
	[path.join("Tests", "Fixtures", "v0109.rsw")] = false, -- No quad tree in this version
	[path.join("Tests", "Fixtures", "v0201.rsw")] = true, -- Generate random tree so the decoder doesn't crash
	[path.join("Tests", "Fixtures", "v0202.rsw")] = true,
	[path.join("Tests", "Fixtures", "v0205.rsw")] = true,
	[path.join("Tests", "Fixtures", "v0206-no-rsm2-flag.rsw")] = true,
	[path.join("Tests", "Fixtures", "v0206-with-rsm2-flag.rsw")] = true,
}

local actFiles = {
	path.join("Tests", "Fixtures", "v0200.act"),
	path.join("Tests", "Fixtures", "v0201.act"),
	path.join("Tests", "Fixtures", "v0203.act"),
	path.join("Tests", "Fixtures", "v0204.act"),
	path.join("Tests", "Fixtures", "v0205.act"),
}

local gatFiles = {
	path.join("Tests", "Fixtures", "v0102.gat"),
	path.join("Tests", "Fixtures", "v0103.gat"),
}

describe("FileAnalyzer", function()
	describe("AnalyzeGND", function()
		it("should return a summary of the metadata found in the given GND files", function()
			local analysisResult = FileAnalyzer:AnalyzeGND(gndFiles)

			assertEquals(analysisResult.numFilesAnalyzed, 3)

			assertEquals(analysisResult.fields.version[1.7], 1)
			assertEquals(analysisResult.fields.version[1.8], 1)
			assertEquals(analysisResult.fields.version[1.9], 1)

			assertEquals(analysisResult.fields.diffuseTextureCount[2], 3)
			assertEquals(analysisResult.fields.gridSizeU[1], 3)
			assertEquals(analysisResult.fields.gridSizeV[2], 3)
		end)
	end)

	describe("AnalyzeSPR", function()
		it("should return a summary of the metadata found in the given SPR files", function()
			local analysisResult = FileAnalyzer:AnalyzeSPR(sprFiles)

			assertEquals(analysisResult.numFilesAnalyzed, 3)

			assertEquals(analysisResult.fields.version[1.1], 1)
			assertEquals(analysisResult.fields.version[2.0], 1)
			assertEquals(analysisResult.fields.version[2.1], 1)

			assertEquals(analysisResult.fields.bmpImagesCount[2], 3)
			assertEquals(analysisResult.fields.tgaImagesCount[0], 1)
			assertEquals(analysisResult.fields.tgaImagesCount[1], 2)
		end)
	end)

	describe("AnalyzeRSW", function()
		local GENERATED_QUADTREE_BYTES = QuadTreeRange:CreateNormalizedDebugTree()
		local modifiedFilesBackup = {}
		before(function()
			for filePath, needsQuadTree in pairs(rswFiles) do
				if needsQuadTree then
					local originalFileContents = C_FileSystem.ReadFile(filePath)
					modifiedFilesBackup[filePath] = originalFileContents

					local modifiedFileContents = originalFileContents .. GENERATED_QUADTREE_BYTES
					C_FileSystem.WriteFile(filePath, modifiedFileContents)
				end
			end
		end)

		after(function()
			for filePath, originalFileContents in pairs(modifiedFilesBackup) do
				C_FileSystem.WriteFile(filePath, originalFileContents)
			end
		end)

		it("should return a summary of the metadata found in the given RSW files", function()
			local orderedFiles = {}
			for filePath, _ in pairs(rswFiles) do
				table.insert(orderedFiles, filePath)
			end
			local analysisResult = FileAnalyzer:AnalyzeRSW(orderedFiles)

			assertEquals(analysisResult.numFilesAnalyzed, 6)

			assertEquals(analysisResult.fields.version[1.9], 1)
			assertEquals(analysisResult.fields.version[2.1], 1)
			assertEquals(analysisResult.fields.version[2.2], 1)
			assertEquals(analysisResult.fields.version[2.5], 1)
			assertEquals(analysisResult.fields.version[2.6], 2)

			assertEquals(analysisResult.fields.buildNumber[0], 2)
			assertEquals(analysisResult.fields.buildNumber[42], 1)
			assertEquals(analysisResult.fields.buildNumber[160], 1)
			assertEquals(analysisResult.fields.buildNumber[161], 1)
			assertEquals(analysisResult.fields.buildNumber[162], 1)

			assertEquals(analysisResult.fields.unknownRenderFlag[0], 3)
			assertEquals(analysisResult.fields.unknownRenderFlag[17], 1)
			assertEquals(analysisResult.fields.unknownRenderFlag[33], 1)

			assertEquals(analysisResult.fields.iniFile[""], 6)
			assertEquals(analysisResult.fields.scrFile[""], 6)

			assertEquals(analysisResult.fields.unknownRenewalPropFlag[0], 10)
			assertEquals(analysisResult.fields.unknownRenewalPropFlag[171], 1)
			assertEquals(analysisResult.fields.unknownRenewalPropFlag[188], 1)

			assertEquals(analysisResult.fields.numSceneObjects[8], 6)
			assertEquals(analysisResult.fields.numAnimatedProps[2], 6)
			assertEquals(analysisResult.fields.numDynamicLightSources[2], 6)
			assertEquals(analysisResult.fields.numSpatialAudioSources[2], 6)
			assertEquals(analysisResult.fields.numParticleEffectEmitters[2], 6)
			assertEquals(analysisResult.fields.isSolid[false], 12)
		end)
	end)

	describe("AnalyzeACT", function()
		it("should return a summary of the metadata found in the given ACT files", function()
			local analysisResult = FileAnalyzer:AnalyzeACT(actFiles)

			assertEquals(analysisResult.numFilesAnalyzed, 5)

			assertEquals(analysisResult.fields.version[2.0], 1)
			assertEquals(analysisResult.fields.version[2.1], 1)
			assertEquals(analysisResult.fields.version[2.3], 1)
			assertEquals(analysisResult.fields.version[2.4], 1)
			assertEquals(analysisResult.fields.version[2.5], 1)

			assertEquals(analysisResult.fields.numAnimationClips[1], 5)
		end)
	end)

	describe("AnalyzeGAT", function()
		it("should return a summary of the metadata found in the given GAT files", function()
			local analysisResult = FileAnalyzer:AnalyzeGAT(gatFiles)

			assertEquals(analysisResult.numFilesAnalyzed, 2)

			assertEquals(analysisResult.fields.version[1.2], 1)
			assertEquals(analysisResult.fields.version[1.3], 1)

			assertEquals(analysisResult.fields.mapU[3], 2)
			assertEquals(analysisResult.fields.mapV[2], 2)

			assertEquals(analysisResult.fields.terrainTypes, { 2, 1, 1, 1, 1, 1, [0] = 5 })

			assertEquals(analysisResult.fields.terrainFlags, {
				isSnipeable = 3,
				isWalkable = 4,
				isWater = 3,
			})

			assertEquals(analysisResult.fields.renewalWaterFlags, {
				[0] = 10,
				[32768] = 2,
			})

			assertEquals(analysisResult.minObservedAltitude, 1)
			assertEquals(analysisResult.maxObservedAltitude, 4)
		end)
	end)
end)
