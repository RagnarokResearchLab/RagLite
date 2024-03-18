local json = require("json")
local openssl = require("openssl")
local uv = require("uv")

local QuadTreeRange = require("Core.FileFormats.RSW.QuadTreeRange")
local RagnarokTools = require("Tools.RagnarokTools")

describe("RagnarokTools", function()
	describe("GenerateMapListFromGRF", function()
		it("should return a list of complete map files present in the given GRF archive", function()
			local expectedMapList = {
				"123",
				"456",
			}
			local actualMapList, _ = RagnarokTools:GenerateMapListFromGRF("Tests/Fixtures/missing-map-files.grf")
			assertEquals(#actualMapList, #expectedMapList)
			assertEquals(actualMapList, expectedMapList)
		end)

		it("should return a list of incomplete map files present in the given GRF archive", function()
			local expectedMapList = {
				"no-gat",
				"no-gnd",
				"rsw-only",
			}
			local _, actualMapList = RagnarokTools:GenerateMapListFromGRF("Tests/Fixtures/missing-map-files.grf")
			assertEquals(#actualMapList, #expectedMapList)
			assertEquals(actualMapList, expectedMapList)
		end)
	end)

	describe("SaveMapDatabaseAsJSON", function()
		it("should generate a JSON database for the given map list", function()
			local mapList = {
				"foo",
				"bar",
			}
			RagnarokTools:SaveMapDatabaseAsJSON(mapList, "maps.json")

			local storedJSON = C_FileSystem.ReadFile("maps.json")
			C_FileSystem.Delete("maps.json")

			local expectedJSON = json.prettier(mapList)
			assertEquals(storedJSON, expectedJSON)
		end)
	end)

	describe("ExportLightmapsFromGND", function()
		it("should export the GND lightmap data in a human-readable format if a valid GND buffer is passed", function()
			local expectedLightmapChecksum = "be735bab85771a54892d4129d7aba3126e0f7f41f2c9891a28aa8dcfc897d2fa"
			local expectedShadowmapChecksum = "4a7a36bedbb8e73797b91b2f568b59b8d4600dc3975e2265114339a5142e9175"
			local expectedTextureChecksum = "dfbff3a58a516c0990147567388431dee2d05dae12a01bd5fb4d30230bb79573"

			local gndFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "no-water-plane.gnd"))
			RagnarokTools:ExportLightmapsFromGND(gndFileContents)

			local generatedLightmapBytes = C_FileSystem.ReadFile("lightmap.png")
			local generatedShadowmapBytes = C_FileSystem.ReadFile("shadowmap.png")
			local generatedTextureImage = C_FileSystem.ReadFile("combined-lightmap-texture.png")

			local generatedLightmapChecksum = openssl.digest.digest("sha256", generatedLightmapBytes)
			local generatedShadowmapChecksum = openssl.digest.digest("sha256", generatedShadowmapBytes)
			local generatedTextureChecksum = openssl.digest.digest("sha256", generatedTextureImage)

			assertEquals(generatedLightmapChecksum, expectedLightmapChecksum)
			assertEquals(generatedShadowmapChecksum, expectedShadowmapChecksum)
			assertEquals(generatedTextureChecksum, expectedTextureChecksum)

			C_FileSystem.Delete("lightmap.png")
			C_FileSystem.Delete("shadowmap.png")
			C_FileSystem.Delete("combined-lightmap-texture.png")
		end)
	end)

	describe("ExportSceneGraphFromRSW", function()
		after(function()
			C_FileSystem.Delete("rsw-quadtree.bin")
			C_FileSystem.Delete("rsw-quadtree.bin.dot")
		end)

		it("should export the quad tree ranges after re-encoding them if a valid RSW buffer is passed", function()
			-- Simply copying bytes directly would be easier, but the point is to test the (de)serialization logic
			local rawQuadTreeBytes = QuadTreeRange:CreateDebugTree() -- As would be present in the RSW file itself
			local normalizedQuadTreeBytes = QuadTreeRange:CreateNormalizedDebugTree() -- Normalized when stored in memory
			RagnarokTools:ExportSceneGraphFromRSW(rawQuadTreeBytes, uv.cwd()) -- "Empty" RSW file, valid here
			local reEncodedQuadTreeBytes = C_FileSystem.ReadFile(path.join(uv.cwd(), "rsw-quadtree.bin"))

			assertEquals(#reEncodedQuadTreeBytes, #normalizedQuadTreeBytes)
			assertEquals(reEncodedQuadTreeBytes, normalizedQuadTreeBytes)
		end)
	end)

	describe("ExportCollisionMapFromGAT", function()
		it("should export the GAT terrain data in a human-readable format if a valid GAT buffer is passed", function()
			local expectedChecksum = "782b916b6e39531622f552e69c3e52d6a3b11ab30f877163e3778f3cfd58d42c"

			local gatFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0102.gat"))
			RagnarokTools:ExportCollisionMapFromGAT(gatFileContents, uv.cwd())

			local generatedFileContents = C_FileSystem.ReadFile("gat-collision-map.png")
			local generatedImageBytes, width, height = C_ImageProcessing.DecodeFileContents(generatedFileContents)
			local generatedChecksum = openssl.digest.digest("sha256", generatedImageBytes)

			assertEquals(width, 3)
			assertEquals(height, 2)
			assertEquals(#generatedImageBytes, 3 * 2 * 4)
			assertEquals(generatedChecksum, expectedChecksum)

			C_FileSystem.Delete("gat-collision-map.png")
		end)
	end)

	describe("ExportTerrainMapFromGAT", function()
		it("should export the GAT terrain data in a human-readable format if a valid GAT buffer is passed", function()
			local expectedChecksum = "720f8a671b438e6db46b7e8298b3d66695cc46d38057f1f32a6810b7de3cd4ec"

			local gatFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0102.gat"))
			RagnarokTools:ExportTerrainMapFromGAT(gatFileContents, uv.cwd())

			local generatedFileContents = C_FileSystem.ReadFile("gat-terrain-map.png")
			local generatedImageBytes, width, height = C_ImageProcessing.DecodeFileContents(generatedFileContents)
			local generatedChecksum = openssl.digest.digest("sha256", generatedImageBytes)

			assertEquals(width, 3)
			assertEquals(height, 2)
			assertEquals(#generatedImageBytes, 3 * 2 * 4)
			assertEquals(generatedChecksum, expectedChecksum)

			C_FileSystem.Delete("gat-terrain-map.png")
		end)
	end)

	describe("ExportHeightMapFromGAT", function()
		it("should export the GAT terrain data in a human-readable format if a valid GAT buffer is passed", function()
			local expectedChecksum = "c773395b224984566fc1c2a1bc01ed83f5e89ea97e9c035b75d1a1c5ef48ff48"

			local gatFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0102.gat"))
			RagnarokTools:ExportHeightMapFromGAT(gatFileContents, uv.cwd())

			local generatedFileContents = C_FileSystem.ReadFile("gat-height-map.png")
			local generatedImageBytes, width, height = C_ImageProcessing.DecodeFileContents(generatedFileContents)
			local generatedChecksum = openssl.digest.digest("sha256", generatedImageBytes)

			assertEquals(width, 3)
			assertEquals(height, 2)
			assertEquals(#generatedImageBytes, 3 * 2 * 4)
			assertEquals(generatedChecksum, expectedChecksum)

			C_FileSystem.Delete("gat-height-map.png")
		end)
	end)
end)
