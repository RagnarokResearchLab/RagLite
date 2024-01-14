local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")

local function assertSurfaceRegionMatches(actualRegion, expectedRegion)
	assertEquals(actualRegion.minU, expectedRegion.minU)
	assertEquals(actualRegion.minV, expectedRegion.minV)
	assertEquals(actualRegion.maxU, expectedRegion.maxU)
	assertEquals(actualRegion.maxV, expectedRegion.maxV)
end

describe("AnimatedWaterPlane", function()
	describe("GetTextureAnimationDuration", function()
		it("should return the texture cycling animation duration in milliseconds", function()
			assertEquals(AnimatedWaterPlane:GetTextureAnimationDuration(0), 0)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(1), 533.333, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(2), 1066.666, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(3), 1600, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(4), 2133.333, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(5), 2666.666, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(6), 3200, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(7), 3733.333, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureAnimationDuration(8), 4266.666, 1E-3)
		end)
	end)

	describe("AlignWithGroundMesh", function()
		it("should reposition the plane so that it covers the entire map if there's just one water surface", function()
			local gnd = RagnarokGND()
			gnd.gridSizeU = 120
			gnd.gridSizeV = 150
			gnd.numWaterPlanesU = 1
			gnd.numWaterPlanesV = 1

			local expectedSurfaceRegion = { maxU = 120, maxV = 150, minU = 1, minV = 1, tileSlotU = 1, tileSlotV = 1 }

			local waterPlane = AnimatedWaterPlane(1, 1)
			waterPlane:AlignWithGroundMesh(gnd)
			local actualRegion = waterPlane.surfaceRegion

			assertSurfaceRegionMatches(actualRegion, expectedSurfaceRegion)
		end)

		it("should reposition the surface so that it aligns with the assigned slot in the tiling grid", function()
			local gnd = RagnarokGND()
			gnd.gridSizeU = 150
			gnd.gridSizeV = 150
			gnd.numWaterPlanesU = 3
			gnd.numWaterPlanesV = 9

			local expectedSurfaceRegions = dofile("Tests/Fixtures/Snapshots/water-plane-regions.lua")

			local actualRegions = {}
			for tilingSlotU = 1, 3 do
				for tilingSlotV = 1, 9 do
					local waterPlane = AnimatedWaterPlane(tilingSlotU, tilingSlotV)
					waterPlane:AlignWithGroundMesh(gnd)
					table.insert(actualRegions, waterPlane.surfaceRegion)
				end
			end

			-- This won't be the most helpful if there's a mismatch, but it's unlikely to change often
			assertSurfaceRegionMatches(actualRegions, expectedSurfaceRegions)
		end)
	end)
end)
