local RagnarokGR2 = require("Core.FileFormats.RagnarokGR2")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local miniz = require("miniz")
local transform = require("transform")

local GRF_GR2_BASE_PATH = "data/model/3dmob/"
local GRF_GR2_SKELETONS_PATH = "data/model/3dmob_bone/"

local grannyFilesList = {
	{ file = GRF_GR2_BASE_PATH .. "aguardian90_8.gr2", checksum = 1720405178, jsonSize = 380419 },
	{ file = GRF_GR2_BASE_PATH .. "empelium90_0.gr2", checksum = 1899559409, jsonSize = 146649 },
	{ file = GRF_GR2_BASE_PATH .. "guildflag90_1.gr2", checksum = 943728643, jsonSize = 204997 },
	{ file = GRF_GR2_BASE_PATH .. "kguardian90_7.gr2", checksum = 1874720287, jsonSize = 371644 },
	{ file = GRF_GR2_BASE_PATH .. "sguardian90_9.gr2", checksum = 1359368891, jsonSize = 340137 },
	{ file = GRF_GR2_BASE_PATH .. "treasurebox_2.gr2", checksum = 2193050918, jsonSize = 136875 },

	{ file = GRF_GR2_SKELETONS_PATH .. "1_attack.gr2", checksum = 934334551, jsonSize = 395756 },
	{ file = GRF_GR2_SKELETONS_PATH .. "2_damage.gr2", checksum = 2300748981, jsonSize = 84180 },
	{ file = GRF_GR2_SKELETONS_PATH .. "2_dead.gr2", checksum = 38649294, jsonSize = 99551 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_attack.gr2", checksum = 1140390622, jsonSize = 147183 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_damage.gr2", checksum = 62130704, jsonSize = 160923 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_dead.gr2", checksum = 4063112950, jsonSize = 184387 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_move.gr2", checksum = 157276642, jsonSize = 162057 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_attack.gr2", checksum = 109337596, jsonSize = 185803 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_damage.gr2", checksum = 2035721610, jsonSize = 150797 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_dead.gr2", checksum = 1702005329, jsonSize = 168097 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_move.gr2", checksum = 2454629524, jsonSize = 165019 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_attack.gr2", checksum = 1046813075, jsonSize = 132089 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_damage.gr2", checksum = 2879254690, jsonSize = 142522 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_dead.gr2", checksum = 3960686436, jsonSize = 164883 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_move.gr2", checksum = 4072757077, jsonSize = 144728 },
}

describe("RagnarokGR2", function()
	local grfPath = "data.grf"
	if not C_FileSystem.Exists(grfPath) then
		transform.yellow("Warning: Skipped GR2 decoder test (data.grf file not present)")
		return
	end

	local grf = RagnarokGRF()
	grf:Open(grfPath) -- Leave this handle open to speed up the test (OS will clean up on exit, presumably)
	before(function() end)

	describe("DecodeFileContents", function()
		assertEquals(#grannyFilesList, 21)

		for index, testCase in pairs(grannyFilesList) do
			local expectedChecksum = testCase.checksum
			local expectedLength = testCase.jsonSize
			local gr2FilePath = testCase.file

			it("should be able to decode " .. gr2FilePath, function()
				-- This is quite hacky, but far easier than comparing everything in excruciating details
				-- Ideally, there should be a test.gr2 file that covers, but creating one would be quite laborious...
				local gr2 = RagnarokGR2()

				local gr2Bytes = grf:ExtractFileInMemory(gr2FilePath)
				gr2:DecodeFileContents(gr2Bytes)

				local jsonString = gr2:ToJSON()
				assertEquals(#jsonString, expectedLength)
				local checksum = miniz.crc32(0, jsonString)
				assertEquals(checksum, expectedChecksum)
			end)
		end
	end)
end)
