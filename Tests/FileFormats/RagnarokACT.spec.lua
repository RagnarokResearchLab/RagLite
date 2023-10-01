local RagnarokACT = require("Core.FileFormats.RagnarokACT")

-- local ACTV2_0_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0200.act"))
local ACTV2_0_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0109.rsw"))
local ACTV2_1_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0201.rsw"))
local ACTV2_2_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0202.rsw"))
-- 2.3 and 2.4 skipped for now, as there are no discernible (i.e., surface-level) changes in the format
-- local ACTV2_5_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0205.act"))
local ACTV2_5_EXAMPLE =
	C_FileSystem.ReadFile(path.join("data.extracted.grf", "data", "sprite", "몬스터", "poring.act"))
-- local ACTV2_6_WITHOUT_FLAG_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0206-no-rsm2-flag.rsw"))
-- local ACTV2_6_WITH_FLAG_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0206-with-rsm2-flag.rsw"))

describe("RagnarokACT", function()
	describe("DecodeFileContents", function()
		-- TODO remove
		it("should be able to decode ACT files using version 2.0 of the format", function()
			-- local act = RagnarokACT()
			-- act:DecodeFileContents(ACTV2_0_EXAMPLE)

			-- assertEquals(act.signature, "AC")
			-- assertEquals(act.version, 2.0)
			-- assertEquals(act.buildNumber, 0)
			-- assertEquals(act.unknownRenderFlag, 0)
		end)
		it("should be able to decode ACT files using version 2.1 of the format", function() end)
		it("should be able to decode ACT files using version 2.2 of the format", function() end)
		it("should be able to decode ACT files using version 2.3 of the format", function() end)
		it("should be able to decode ACT files using version 2.4 of the format", function() end)
		it("should be able to decode ACT files using version 2.5 of the format", function()
			local act = RagnarokACT()
			act:DecodeFileContents(ACTV2_5_EXAMPLE)

			assertEquals(act.signature, "AC")
			assertEquals(act.version, 2.5)
			assertEquals(act.numAnimationClips, 72)
			assertEquals(#act.unknownHeaderField, 10)

			assertEquals(act.animationClips[1].numAnimationFrames, 4)
			assertEquals(act.animationClips[1].animationFrames[1].mysteryBox1.bottomLeftCorner.u, 24641536) -- WTF
			assertEquals(act.animationClips[1].animationFrames[1].mysteryBox1.bottomLeftCorner.v, 24641688)
			assertEquals(act.animationClips[1].animationFrames[1].mysteryBox1.topRightCorner.u, 152)
			assertEquals(act.animationClips[1].animationFrames[1].mysteryBox1.topRightCorner.v, 0)
			assertEquals(act.animationClips[1].animationFrames[1].animationEventTypeID, 65536) -- ??? TBD should be -1?

			assertEquals(act.animationClips[1].animationFrames[1].numSpriteLayers, 0) -- ???
			assertEquals(#act.animationClips[1].animationFrames[1].spriteLayers, 0) -- ???

			assertEquals(act.animationClips[1].animationFrames[1].numAnchors, 0) -- ???			
			assertEquals(#act.animationClips[1].animationFrames[1].anchors, 0) -- ???
			-- TBD other frames
			-- TBD other clips
			assertEquals(act.numAnimationEvents, 0) -- ???

		end)
	end)
end)
