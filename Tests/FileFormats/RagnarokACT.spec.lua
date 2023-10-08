local RagnarokACT = require("Core.FileFormats.RagnarokACT")

local json = require("json")

local ACTV2_0_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0200.act"))
local ACTV2_1_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0201.act"))
local ACTV2_3_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0203.act"))
local ACTV2_4_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0204.act"))
local ACTV2_5_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0205.act"))

describe("RagnarokACT", function()
	describe("DecodeFileContents", function()
		it("should be able to decode ACT files using version 2.0 of the format", function()
			local act = RagnarokACT()
			act:DecodeFileContents(ACTV2_0_EXAMPLE)
			local actual = act:ToJSON()
			local expected = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Snapshots", "v0200.act.json"))
			assertEquals(json.parse(actual), json.parse(expected)) -- Workaround for encoding issues in the CI :/
		end)

		it("should be able to decode ACT files using version 2.1 of the format", function()
			local act = RagnarokACT()
			act:DecodeFileContents(ACTV2_1_EXAMPLE)
			local actual = act:ToJSON()
			local expected = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Snapshots", "v0201.act.json"))
			assertEquals(json.parse(actual), json.parse(expected)) -- Workaround for encoding issues in the CI :/
		end)

		it("should be able to decode ACT files using version 2.3 of the format", function()
			local act = RagnarokACT()
			act:DecodeFileContents(ACTV2_3_EXAMPLE)
			local actual = act:ToJSON()
			local expected = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Snapshots", "v0203.act.json"))
			assertEquals(json.parse(actual), json.parse(expected)) -- Workaround for encoding issues in the CI :/
		end)

		it("should be able to decode ACT files using version 2.4 of the format", function()
			local act = RagnarokACT()
			act:DecodeFileContents(ACTV2_4_EXAMPLE)
			local actual = act:ToJSON()
			local expected = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Snapshots", "v0204.act.json"))
			assertEquals(json.parse(actual), json.parse(expected)) -- Workaround for encoding issues in the CI :/
		end)

		it("should be able to decode ACT files using version 2.5 of the format", function()
			local act = RagnarokACT()
			act:DecodeFileContents(ACTV2_5_EXAMPLE)
			local actual = act:ToJSON()
			local expected = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Snapshots", "v0205.act.json"))
			assertEquals(json.parse(actual), json.parse(expected)) -- Workaround for encoding issues in the CI :/
		end)
	end)
end)
