local RagnarokGAT = require("Core.FileFormats.RagnarokGAT")

local GATV1_2_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0102.gat"))
local GATV1_3_EXAMPLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v0103.gat"))

describe("RagnarokGAT", function()
	describe("DecodeFileContents", function()
		it("should be able to decode GAT files using version 1.2 of the format", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertEquals(gat.signature, "GRAT")
			assertEquals(gat.version, 1.2)
			assertEquals(gat.mapU, 3)
			assertEquals(gat.mapV, 2)
		end)

		it("should be able to decode ACT files using version 1.3 of the format", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_3_EXAMPLE)
		end)
	end)

	describe("IsValidMapPosition", function()
		it("should return true if the given map position is inside the actual map boundaries", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertTrue(gat:IsValidMapPosition(1, 1))
			assertTrue(gat:IsValidMapPosition(1, 1))
			assertTrue(gat:IsValidMapPosition(2, 2))
			assertTrue(gat:IsValidMapPosition(2, 1))
			assertTrue(gat:IsValidMapPosition(3, 1))
			assertTrue(gat:IsValidMapPosition(3, 2))
		end)

		it("should return false if the given map position is outside the actual map boundaries", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertFalse(gat:IsValidMapPosition(0, 0))
			assertFalse(gat:IsValidMapPosition(0, -1))
			assertFalse(gat:IsValidMapPosition(1, 0))
			assertFalse(gat:IsValidMapPosition(-1, 0))
			assertFalse(gat:IsValidMapPosition(-1, -1))
			assertFalse(gat:IsValidMapPosition(4, 2))
			assertFalse(gat:IsValidMapPosition(3, 3))
			assertFalse(gat:IsValidMapPosition(42, 42))
		end)
	end)

	describe("MapPositionToTileID", function()
		it("should return the collision map index of the tile identified by the given map coordinates", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertEquals(gat:MapPositionToTileID(1, 1), 0)
			assertEquals(gat:MapPositionToTileID(1, 2), 3)
			assertEquals(gat:MapPositionToTileID(2, 1), 1)
			assertEquals(gat:MapPositionToTileID(2, 2), 4)
			assertEquals(gat:MapPositionToTileID(3, 1), 2)
			assertEquals(gat:MapPositionToTileID(3, 2), 5)
		end)

		it("should return failure if the given map coordinates are out of bounds", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertFailure(function()
				return gat:MapPositionToTileID(0, 0)
			end, "Map position (0, 0) is outside the actual map boundaries of (3, 2)")
			assertFailure(function()
				return gat:MapPositionToTileID(0, -1)
			end, "Map position (0, -1) is outside the actual map boundaries of (3, 2)")
			assertFailure(function()
				return gat:MapPositionToTileID(-1, 0)
			end, "Map position (-1, 0) is outside the actual map boundaries of (3, 2)")
			assertFailure(function()
				return gat:MapPositionToTileID(4, 2)
			end, "Map position (4, 2) is outside the actual map boundaries of (3, 2)")
			assertFailure(function()
				return gat:MapPositionToTileID(3, 3)
			end, "Map position (3, 3) is outside the actual map boundaries of (3, 2)")
			assertFailure(function()
				return gat:MapPositionToTileID(42, 12345)
			end, "Map position (42, 12345) is outside the actual map boundaries of (3, 2)")
			assertFailure(function()
				return gat:MapPositionToTileID(42, -12345)
			end, "Map position (42, -12345) is outside the actual map boundaries of (3, 2)")
			assertFailure(function()
				return gat:MapPositionToTileID(-42, 12345)
			end, "Map position (-42, 12345) is outside the actual map boundaries of (3, 2)")
		end)
	end)

	describe("IsObstructedTerrain", function()
		it("should return true if the OBSTRUCTED flag is set for the given map coordinates", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertTrue(gat:IsObstructedTerrain(1, 2))
			assertTrue(gat:IsObstructedTerrain(2, 1))
			assertTrue(gat:IsObstructedTerrain(3, 2))
		end)

		it("should return false if the OBSTRUCTED flag is not for the given map coordinates", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertFalse(gat:IsObstructedTerrain(1, 1))
			assertFalse(gat:IsObstructedTerrain(1, 1))
			assertFalse(gat:IsObstructedTerrain(2, 2))
			assertFalse(gat:IsObstructedTerrain(3, 1))
		end)

		it("should throw if the given map coordinates are out of bounds", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			local function attemptToQueryCollisionMapWithInvalidCoords()
				gat:IsObstructedTerrain(0, 0)
			end

			local expectedErrorMessage = "Map position (0, 0) is outside the actual map boundaries of (3, 2)"
			assertThrows(attemptToQueryCollisionMapWithInvalidCoords, expectedErrorMessage)
		end)
	end)

	describe("IsTerrainBlockingRangedAttacks", function()
		it("should return true if the SNIPEABLE flag is not set for the given map coordinates", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertTrue(gat:IsTerrainBlockingRangedAttacks(1, 1))
			assertTrue(gat:IsTerrainBlockingRangedAttacks(1, 1))
			assertTrue(gat:IsTerrainBlockingRangedAttacks(2, 2))
			assertTrue(gat:IsTerrainBlockingRangedAttacks(2, 1))
			assertTrue(gat:IsTerrainBlockingRangedAttacks(3, 2))
		end)

		it("should return false if the SNIPEABLE flag is not for the given map coordinates", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertFalse(gat:IsTerrainBlockingRangedAttacks(1, 2))

			assertFalse(gat:IsTerrainBlockingRangedAttacks(3, 1))
		end)

		it("should throw if the given map coordinates are out of bounds", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			local function attemptToQueryCollisionMapWithInvalidCoords()
				gat:IsTerrainBlockingRangedAttacks(0, 0)
			end

			local expectedErrorMessage = "Map position (0, 0) is outside the actual map boundaries of (3, 2)"
			assertThrows(attemptToQueryCollisionMapWithInvalidCoords, expectedErrorMessage)
		end)
	end)

	describe("IsWater", function()
		-- May conflict with the RE water flag? Unclear, so for now just ignore this situation entirely
		it("should return true if the WATER flag is set for the given map coordinates", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertTrue(gat:IsWater(2, 2))
			assertTrue(gat:IsWater(3, 2))
		end)

		it("should return false if the WATER flag is not for the given map coordinates", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertFalse(gat:IsWater(1, 1))
			assertFalse(gat:IsWater(1, 2))
			assertFalse(gat:IsWater(2, 1))

			assertFalse(gat:IsWater(3, 1))
		end)

		it("should throw if the given map coordinates are out of bounds", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			local function attemptToQueryCollisionMapWithInvalidCoords()
				gat:IsWater(0, 0)
			end

			local expectedErrorMessage = "Map position (0, 0) is outside the actual map boundaries of (3, 2)"
			assertThrows(attemptToQueryCollisionMapWithInvalidCoords, expectedErrorMessage)
		end)
	end)

	describe("GetTerrainAltitudeAt", function()
		it("should return the normalized terrain altitude if the given map coordinates are valid", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			assertEquals(gat:GetTerrainAltitudeAt(1, 1), -0.5)
			assertEquals(gat:GetTerrainAltitudeAt(1, 2), -0.5)
			assertEquals(gat:GetTerrainAltitudeAt(2, 1), -0.5)
			assertEquals(gat:GetTerrainAltitudeAt(2, 2), -0.5)
			assertEquals(gat:GetTerrainAltitudeAt(3, 1), -0.5)
			assertEquals(gat:GetTerrainAltitudeAt(3, 2), -0.5)
		end)

		it("should throw if the given map coordinates are out of bounds", function()
			local gat = RagnarokGAT()
			gat:DecodeFileContents(GATV1_2_EXAMPLE)

			local function attemptToQueryCollisionMapWithInvalidCoords()
				gat:GetTerrainAltitudeAt(0, 0)
			end

			local expectedErrorMessage = "Map position (0, 0) is outside the actual map boundaries of (3, 2)"
			assertThrows(attemptToQueryCollisionMapWithInvalidCoords, expectedErrorMessage)
		end)
	end)
end)
