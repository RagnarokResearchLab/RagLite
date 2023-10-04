local RagnarokGR2 = require("Core.FileFormats.RagnarokGR2")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local miniz = require("miniz")
local transform = require("transform")

local GRF_GR2_BASE_PATH = "data/model/3dmob/"
local GRF_GR2_SKELETONS_PATH = "data/model/3dmob_bone/"

local grannyFilesList = {
	{ file = GRF_GR2_BASE_PATH .. "aguardian90_8.gr2", checksum = 3613547, jsonSize = 558140 },
	{ file = GRF_GR2_BASE_PATH .. "empelium90_0.gr2", checksum = 2362359871, jsonSize = 210665 },
	{ file = GRF_GR2_BASE_PATH .. "guildflag90_1.gr2", checksum = 1924535745, jsonSize = 266810 },
	{ file = GRF_GR2_BASE_PATH .. "kguardian90_7.gr2", checksum = 3216031845, jsonSize = 538284 },
	{ file = GRF_GR2_BASE_PATH .. "sguardian90_9.gr2", checksum = 3977127686, jsonSize = 494673 },
	{ file = GRF_GR2_BASE_PATH .. "treasurebox_2.gr2", checksum = 2106457723, jsonSize = 184591 },

	{ file = GRF_GR2_SKELETONS_PATH .. "1_attack.gr2", checksum = 4117355684, jsonSize = 567068 },
	{ file = GRF_GR2_SKELETONS_PATH .. "2_damage.gr2", checksum = 1139923259, jsonSize = 97404 },
	{ file = GRF_GR2_SKELETONS_PATH .. "2_dead.gr2", checksum = 1116660203, jsonSize = 126951 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_attack.gr2", checksum = 1868355480, jsonSize = 177638 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_damage.gr2", checksum = 655650119, jsonSize = 204278 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_dead.gr2", checksum = 3026864945, jsonSize = 251174 },
	{ file = GRF_GR2_SKELETONS_PATH .. "7_move.gr2", checksum = 2884345469, jsonSize = 206654 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_attack.gr2", checksum = 3744560610, jsonSize = 243809 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_damage.gr2", checksum = 22355839, jsonSize = 176141 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_dead.gr2", checksum = 4059769579, jsonSize = 209788 },
	{ file = GRF_GR2_SKELETONS_PATH .. "8_move.gr2", checksum = 3763830390, jsonSize = 203080 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_attack.gr2", checksum = 441125228, jsonSize = 160745 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_damage.gr2", checksum = 1688440907, jsonSize = 181409 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_dead.gr2", checksum = 259586279, jsonSize = 225375 },
	{ file = GRF_GR2_SKELETONS_PATH .. "9_move.gr2", checksum = 3160164003, jsonSize = 185812 },
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
