local FileAnalyzer = require("Tools.FileAnalyzer")
local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local QuadTreeRange = require("Core.FileFormats.RSW.QuadTreeRange")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")

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

local rsmFiles = {
	path.join("Tests", "Fixtures", "v0104.rsm"),
	path.join("Tests", "Fixtures", "v0105.rsm"),
	path.join("Tests", "Fixtures", "v0202.rsm2"),
	path.join("Tests", "Fixtures", "v0203.rsm2"),
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

			assertEquals(analysisResult.fields.animationTypeID[1], 6)
			assertEquals(analysisResult.fields.animationTypeID[2], 6)

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

			assertEquals(analysisResult.fields.animationFrameMysteryBytes, {
				[-2004318072] = 1,
				[-1532779871] = 1,
				[-1465473371] = 1,
				[-1263291727] = 1,
				[0] = 11,
				[4] = 1,
				[32] = 1,
				[66] = 1,
				[145] = 1,
				[480] = 1,
				[640] = 1,
				[724] = 1,
				[904] = 1,
				[1750] = 1,
				[2366] = 1,
				[3535] = 1,
				[6757] = 1,
				[6778] = 1,
				[54647] = 1,
				[67305985] = 2,
				[134678021] = 2,
				[286331153] = 1,
				[572662306] = 1,
				[858993459] = 1,
				[1145324612] = 1,
				[1431655765] = 1,
				[1717986918] = 1,
				[2004318071] = 1,
			})
			assertEquals(analysisResult.fields.spriteAnchorMysteryBytes, {})
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

	describe("AnalyzeRSM", function()
		it("should return a summary of the metadata found in the given RSM files", function()
			local analysisResult = FileAnalyzer:AnalyzeRSM(rsmFiles)

			assertEquals(analysisResult.numFilesAnalyzed, 4)

			assertEquals(analysisResult.fields.version[1.4], 1)
			assertEquals(analysisResult.fields.version[1.5], 1)
			assertEquals(analysisResult.fields.version[2.2], 1)
			assertEquals(analysisResult.fields.version[2.3], 1)
		end)
	end)

	describe("AnalyzeWaterPlanes", function()
		it("should return a summary of the given water plane's properties", function()
			local waterPlane = AnimatedWaterPlane()
			waterPlane.textureTypePrefix = 1
			local classicLavaPlane = AnimatedWaterPlane()
			classicLavaPlane.textureTypePrefix = 4
			local renewalLavaPlane = AnimatedWaterPlane()
			renewalLavaPlane.textureTypePrefix = 6

			local rswA = RagnarokRSW()
			table.insert(rswA.waterPlanes, waterPlane)
			local rswB = RagnarokRSW()
			table.insert(rswB.waterPlanes, classicLavaPlane)
			local gndC = RagnarokGND()
			table.insert(gndC.waterPlanes, waterPlane)
			local gndD = RagnarokGND()
			table.insert(gndD.waterPlanes, renewalLavaPlane)
			table.insert(gndD.waterPlanes, waterPlane)
			table.insert(gndD.waterPlanes, waterPlane)
			local rswE = RagnarokRSW() -- No water planes

			local inputs = {
				["map_a.rsw"] = rswA,
				["map_c.gnd"] = gndC,
				["map_b.rsw"] = rswB,
				["map_d.gnd"] = gndD,
				["map_e.rsw"] = rswE,
			}

			local analysisResult = FileAnalyzer:AnalyzeWaterPlanes(inputs)

			assertEquals(analysisResult.numProcessedResources, 5)
			assertEquals(analysisResult.fields.textureTypePrefix.numEncounteredValues, 6)

			assertEquals(analysisResult.fields.textureTypePrefix.keysToValues, {
				["map_a.rsw"] = { 1 },
				["map_c.gnd"] = { 1 },
				["map_b.rsw"] = { 4 },
				["map_d.gnd"] = { 6, 1, 1 },
			})
			assertEquals(analysisResult.fields.textureTypePrefix.valuesToKeys, {
				["01"] = {
					["map_a.rsw"] = 1,
					["map_c.gnd"] = 1,
					["map_d.gnd"] = 2,
				},
				["04"] = {
					["map_b.rsw"] = 1,
				},
				["06"] = {
					["map_d.gnd"] = 1,
				},
			})
		end)
	end)
end)
