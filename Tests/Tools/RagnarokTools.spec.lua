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

			local gndFileContents = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "no-water-plane.gnd"))
			RagnarokTools:ExportLightmapsFromGND(gndFileContents)

			local generatedLightmapBytes = C_FileSystem.ReadFile("lightmap.png")
			local generatedShadowmapBytes = C_FileSystem.ReadFile("shadowmap.png")

			local generatedLightmapChecksum = openssl.digest.digest("sha256", generatedLightmapBytes)
			local generatedShadowmapChecksum = openssl.digest.digest("sha256", generatedShadowmapBytes)

			assertEquals(generatedLightmapChecksum, expectedLightmapChecksum)
			assertEquals(generatedShadowmapChecksum, expectedShadowmapChecksum)

			C_FileSystem.Delete("lightmap.png")
			C_FileSystem.Delete("shadowmap.png")
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
end)
