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
			local expectedTextureChecksum = "a740daf79dda0245b71824d441f42baa9cb9c9449458090b983ec7b80a05b3bc"

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
			local expectedChecksum = "315ad7d3a93849ec6fbb7786cd739e8237ead08b2cb1530bf6370f9cfe9c873b"

			local gatFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0102.gat"))
			RagnarokTools:ExportCollisionMapFromGAT(gatFileContents, uv.cwd())

			local generatedImageBytes = C_FileSystem.ReadFile("gat-collision-map.png")
			local generatedChecksum = openssl.digest.digest("sha256", generatedImageBytes)

			assertEquals(generatedChecksum, expectedChecksum)

			C_FileSystem.Delete("gat-collision-map.png")
		end)
	end)

	describe("ExportTerrainMapFromGAT", function()
		it("should export the GAT terrain data in a human-readable format if a valid GAT buffer is passed", function()
			local expectedChecksum = "348cb14b08edd6e41f7c6eee094b033020d397d8d28bc91ac12f3dc98da6fe1b"

			local gatFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0102.gat"))
			RagnarokTools:ExportTerrainMapFromGAT(gatFileContents, uv.cwd())

			local generatedImageBytes = C_FileSystem.ReadFile("gat-terrain-map.png")
			local generatedChecksum = openssl.digest.digest("sha256", generatedImageBytes)

			assertEquals(generatedChecksum, expectedChecksum)

			C_FileSystem.Delete("gat-terrain-map.png")
		end)
	end)

	describe("ExportHeightMapFromGAT", function()
		it("should export the GAT terrain data in a human-readable format if a valid GAT buffer is passed", function()
			local expectedChecksum = "e3ab51a50d93a00bd28b22264e52e983a375dbbe7a87ecdd0c9a0c99ebf541e4"

			local gatFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0102.gat"))
			RagnarokTools:ExportHeightMapFromGAT(gatFileContents, uv.cwd())

			local generatedImageBytes = C_FileSystem.ReadFile("gat-height-map.png")
			local generatedChecksum = openssl.digest.digest("sha256", generatedImageBytes)

			assertEquals(generatedChecksum, expectedChecksum)

			C_FileSystem.Delete("gat-height-map.png")
		end)
	end)
end)
