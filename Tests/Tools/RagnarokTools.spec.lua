local json = require("json")

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
end)
