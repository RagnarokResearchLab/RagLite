local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local KeyframeAnimation = require("Core.NativeClient.KeyframeAnimation")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local WaterSurfaceMaterial = require("Core.NativeClient.WebGPU.Materials.WaterSurfaceMaterial")

local ffi = require("ffi")
local miniz = require("miniz")
local json = require("json")

-- Altitudes aren't normalized in the GND decoder to reduce loading times
local function denormalizeTerrainAltitude(normalizedAltitude)
	return -1 * normalizedAltitude * 1 / RagnarokGND.NORMALIZING_SCALE_FACTOR
end

local function assertSurfaceRegionMatches(actualRegion, expectedRegion)
	assertEquals(actualRegion.minU, expectedRegion.minU)
	assertEquals(actualRegion.minV, expectedRegion.minV)
	assertEquals(actualRegion.maxU, expectedRegion.maxU)
	assertEquals(actualRegion.maxV, expectedRegion.maxV)
end

local GND_WITH_A_SINGLE_WATER_PLANE = RagnarokGND()
GND_WITH_A_SINGLE_WATER_PLANE.gridSizeU = 120
GND_WITH_A_SINGLE_WATER_PLANE.gridSizeV = 150
GND_WITH_A_SINGLE_WATER_PLANE.numWaterPlanesU = 1
GND_WITH_A_SINGLE_WATER_PLANE.numWaterPlanesV = 1
GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid = ffi.new("gnd_groundmesh_cube_t[?]", 150 * 150)

local GND_WITH_MULTIPLE_WATER_PLANES = RagnarokGND()
GND_WITH_MULTIPLE_WATER_PLANES.gridSizeU = 150
GND_WITH_MULTIPLE_WATER_PLANES.gridSizeV = 150
GND_WITH_MULTIPLE_WATER_PLANES.numWaterPlanesU = 3
GND_WITH_MULTIPLE_WATER_PLANES.numWaterPlanesV = 9
GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid = ffi.new("gnd_groundmesh_cube_t[?]", 150 * 150)

local WATER_PLANE_REGIONS = dofile("Tests/Fixtures/Snapshots/water-plane-regions.lua")

describe("AnimatedWaterPlane", function()
	describe("GetTextureCyclingSpeed", function()
		it("should return the texture cycling animation speed in milliseconds per frame", function()
			assertEquals(AnimatedWaterPlane:GetTextureCyclingSpeed(0), 0)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(1), 16.666666666667, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(2), 33.333333333333, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(3), 50, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(4), 66.666666666667, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(5), 83.333333333333, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(6), 100, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(7), 116.66666666667, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(8), 133.33333333333, 1E-3)
			assertEqualNumbers(AnimatedWaterPlane:GetTextureCyclingSpeed(9), 150, 1E-3)
		end)
	end)

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

	describe("GetTextureDimensionsByWaterType", function()
		it("should return the texture dimensions for the given water type ID", function()
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(0), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(1), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(2), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(3), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(4), 256)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(5), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(6), 256)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(7), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(8), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(9), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(10), 128)
			assertEquals(AnimatedWaterPlane:GetExpectedTextureDimensions(11), 128)
		end)

		it("should return the texture dimensions for the plane itself if no type ID was given", function()
			local waterPlane = AnimatedWaterPlane()
			waterPlane.textureTypePrefix = 0 -- Regular water surface
			local classicLavaPlane = AnimatedWaterPlane()
			classicLavaPlane.textureTypePrefix = 4 -- Classic lava surface
			local renewalWaterPlane = AnimatedWaterPlane()
			renewalWaterPlane.textureTypePrefix = 6 -- Renewal lava surface

			assertEquals(waterPlane:GetExpectedTextureDimensions(), 128)
			assertEquals(classicLavaPlane:GetExpectedTextureDimensions(), 256)
			assertEquals(renewalWaterPlane:GetExpectedTextureDimensions(), 256)
		end)
	end)

	describe("AlignWithGroundMesh", function()
		it("should reposition the plane so that it covers the entire map if there's just one water surface", function()
			local expectedSurfaceRegion = { maxU = 120, maxV = 150, minU = 1, minV = 1, tileSlotU = 1, tileSlotV = 1 }

			local waterPlane = AnimatedWaterPlane(1, 1)
			waterPlane:AlignWithGroundMesh(GND_WITH_A_SINGLE_WATER_PLANE)
			local actualRegion = waterPlane.surfaceRegion

			assertSurfaceRegionMatches(actualRegion, expectedSurfaceRegion)
		end)

		it("should reposition the surface so that it aligns with the assigned slot in the tiling grid", function()
			local expectedSurfaceRegions = WATER_PLANE_REGIONS

			local actualRegions = {}
			for tilingSlotU = 1, 3 do
				for tilingSlotV = 1, 9 do
					local waterPlane = AnimatedWaterPlane(tilingSlotU, tilingSlotV)
					waterPlane:AlignWithGroundMesh(GND_WITH_MULTIPLE_WATER_PLANES)
					table.insert(actualRegions, waterPlane.surfaceRegion)
				end
			end

			-- This won't be the most helpful if there's a mismatch, but it's unlikely to change often
			assertSurfaceRegionMatches(actualRegions, expectedSurfaceRegions)
		end)
	end)

	describe("GenerateWaterVertices", function()
		it("should throw if the grid position is out of bounds", function()
			local plane = AnimatedWaterPlane()
			assertThrows(function()
				plane:GenerateWaterVertices(GND_WITH_A_SINGLE_WATER_PLANE, 200, 200)
			end, "Grid position (200, 200) is out of bounds")
		end)

		it(
			"should generate no vertices if the ground mesh has no upwards-facing surface at the grid position",
			function()
				local plane = AnimatedWaterPlane()
				GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].top_surface_id = -1

				plane:GenerateWaterVertices(GND_WITH_A_SINGLE_WATER_PLANE, 1, 1)

				assertEquals(#plane.surfaceGeometry.vertexPositions, 0)
				assertEquals(#plane.surfaceGeometry.vertexColors, 0)
				assertEquals(#plane.surfaceGeometry.triangleConnections, 0)
				assertEquals(#plane.surfaceGeometry.diffuseTextureCoords, 0)
			end
		)

		it("should generate no vertices if the ground mesh surface is above sea level at the grid position", function()
			local plane = AnimatedWaterPlane()
			plane.normalizedSeaLevel = 42

			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].top_surface_id = 0
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].southwest_corner_altitude =
				denormalizeTerrainAltitude(plane.normalizedSeaLevel + 1)
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].southeast_corner_altitude =
				denormalizeTerrainAltitude(plane.normalizedSeaLevel + 1)
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].northwest_corner_altitude =
				denormalizeTerrainAltitude(plane.normalizedSeaLevel + 1)
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].northeast_corner_altitude =
				denormalizeTerrainAltitude(plane.normalizedSeaLevel + 1)

			plane:GenerateWaterVertices(GND_WITH_A_SINGLE_WATER_PLANE, 1, 1)

			assertEquals(#plane.surfaceGeometry.vertexPositions, 0)
			assertEquals(#plane.surfaceGeometry.vertexColors, 0)
			assertEquals(#plane.surfaceGeometry.triangleConnections, 0)
			assertEquals(#plane.surfaceGeometry.diffuseTextureCoords, 0)
		end)

		it("should generate no vertices if the grid position is outside the plane's surface region", function()
			local plane = AnimatedWaterPlane(2, 1) -- Starts at u = 51 in this case (= clearly OOB)
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].top_surface_id = 0

			-- Need to make sure the terrain is below the sea level to be rendered in the first place
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].southwest_corner_altitude = denormalizeTerrainAltitude(-42)
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].southeast_corner_altitude = denormalizeTerrainAltitude(-42)
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].northwest_corner_altitude = denormalizeTerrainAltitude(-42)
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].northeast_corner_altitude = denormalizeTerrainAltitude(-42)

			plane:GenerateWaterVertices(GND_WITH_MULTIPLE_WATER_PLANES, 1, 1)

			assertEquals(#plane.surfaceGeometry.vertexPositions, 0)
			assertEquals(#plane.surfaceGeometry.vertexColors, 0)
			assertEquals(#plane.surfaceGeometry.triangleConnections, 0)
			assertEquals(#plane.surfaceGeometry.diffuseTextureCoords, 0)
		end)

		it("should generate vertices that align with the terrain geometry at the grid position", function()
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].southwest_corner_altitude = denormalizeTerrainAltitude(0)
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].southeast_corner_altitude = denormalizeTerrainAltitude(0)
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].northwest_corner_altitude = denormalizeTerrainAltitude(0)
			GND_WITH_MULTIPLE_WATER_PLANES.cubeGrid[0].northeast_corner_altitude = denormalizeTerrainAltitude(0)

			-- This is just some arbitrary data with (hopefully) enough variation to detect breaking changes
			local surfaceGeometries = {}
			for planeU = 1, 3 do
				for planeV = 1, 9 do
					local planeID = #surfaceGeometries + 1
					local plane = AnimatedWaterPlane(planeU, planeV)
					plane.normalizedSeaLevel = 500
					plane.surfaceRegion.minU = WATER_PLANE_REGIONS[planeID].minU
					plane.surfaceRegion.minV = WATER_PLANE_REGIONS[planeID].minV
					plane.surfaceRegion.maxU = WATER_PLANE_REGIONS[planeID].maxU
					plane.surfaceRegion.maxV = WATER_PLANE_REGIONS[planeID].maxV

					for gridV = plane.surfaceRegion.minV, plane.surfaceRegion.maxV do
						for gridU = plane.surfaceRegion.minU, plane.surfaceRegion.maxU do
							plane:GenerateWaterVertices(GND_WITH_MULTIPLE_WATER_PLANES, gridU, gridV)
						end
					end

					table.insert(surfaceGeometries, plane.surfaceGeometry)
				end
			end

			local compressedGeometryFilePath =
				path.join("Tests", "Fixtures", "Snapshots", "water-surface-geometry.deflated")

			-- Extremely wasteful, should be changed... Leaving this here until I find a better approach
			-- local compressedGeometryFileContents = miniz.compress(json.stringify(surfaceGeometries))
			-- C_FileSystem.WriteFile(compressedGeometryFilePath, compressedGeometryFileContents)

			local compressedGeometryFileContents = C_FileSystem.ReadFile(compressedGeometryFilePath)
			local decompressedGeometryFileContents = miniz.uncompress(compressedGeometryFileContents)
			local expectedSurfaceGeometries = json.parse(decompressedGeometryFileContents)
			local function assertSurfaceGeometryMatches(actualSurfaceGeometry, expectedSurfaceGeometry)
				assertEquals(#actualSurfaceGeometry.vertexPositions, #expectedSurfaceGeometry.vertexPositions)
				assertEquals(actualSurfaceGeometry.vertexPositions, expectedSurfaceGeometry.vertexPositions)
				assertEquals(#actualSurfaceGeometry.vertexColors, #expectedSurfaceGeometry.vertexColors)
				assertEquals(actualSurfaceGeometry.vertexColors, expectedSurfaceGeometry.vertexColors)
				assertEquals(#actualSurfaceGeometry.triangleConnections, #expectedSurfaceGeometry.triangleConnections)
				assertEquals(actualSurfaceGeometry.triangleConnections, expectedSurfaceGeometry.triangleConnections)
				assertEquals(#actualSurfaceGeometry.diffuseTextureCoords, #expectedSurfaceGeometry.diffuseTextureCoords)
				assertEquals(actualSurfaceGeometry.diffuseTextureCoords, expectedSurfaceGeometry.diffuseTextureCoords)
			end

			assertSurfaceGeometryMatches(surfaceGeometries[1], expectedSurfaceGeometries[1])
			assertSurfaceGeometryMatches(surfaceGeometries[2], expectedSurfaceGeometries[2])
			assertSurfaceGeometryMatches(surfaceGeometries[3], expectedSurfaceGeometries[3])
			assertSurfaceGeometryMatches(surfaceGeometries[4], expectedSurfaceGeometries[4])
			assertSurfaceGeometryMatches(surfaceGeometries[5], expectedSurfaceGeometries[5])
			assertSurfaceGeometryMatches(surfaceGeometries[6], expectedSurfaceGeometries[6])
			assertSurfaceGeometryMatches(surfaceGeometries[7], expectedSurfaceGeometries[7])
			assertSurfaceGeometryMatches(surfaceGeometries[8], expectedSurfaceGeometries[8])
			assertSurfaceGeometryMatches(surfaceGeometries[9], expectedSurfaceGeometries[9])
			assertSurfaceGeometryMatches(surfaceGeometries[10], expectedSurfaceGeometries[10])
			assertSurfaceGeometryMatches(surfaceGeometries[11], expectedSurfaceGeometries[11])
			assertSurfaceGeometryMatches(surfaceGeometries[12], expectedSurfaceGeometries[12])
			assertSurfaceGeometryMatches(surfaceGeometries[13], expectedSurfaceGeometries[13])
			assertSurfaceGeometryMatches(surfaceGeometries[14], expectedSurfaceGeometries[14])
			assertSurfaceGeometryMatches(surfaceGeometries[15], expectedSurfaceGeometries[15])
			assertSurfaceGeometryMatches(surfaceGeometries[16], expectedSurfaceGeometries[16])
			assertSurfaceGeometryMatches(surfaceGeometries[17], expectedSurfaceGeometries[17])
			assertSurfaceGeometryMatches(surfaceGeometries[18], expectedSurfaceGeometries[18])
			assertSurfaceGeometryMatches(surfaceGeometries[19], expectedSurfaceGeometries[19])
			assertSurfaceGeometryMatches(surfaceGeometries[20], expectedSurfaceGeometries[20])
			assertSurfaceGeometryMatches(surfaceGeometries[21], expectedSurfaceGeometries[21])
			assertSurfaceGeometryMatches(surfaceGeometries[22], expectedSurfaceGeometries[22])
			assertSurfaceGeometryMatches(surfaceGeometries[23], expectedSurfaceGeometries[23])
			assertSurfaceGeometryMatches(surfaceGeometries[24], expectedSurfaceGeometries[24])
			assertSurfaceGeometryMatches(surfaceGeometries[25], expectedSurfaceGeometries[25])
			assertSurfaceGeometryMatches(surfaceGeometries[26], expectedSurfaceGeometries[26])
			assertSurfaceGeometryMatches(surfaceGeometries[27], expectedSurfaceGeometries[27])
		end)

		it("should apply an inset to ease debugging if GEOMETRY_DEBUG_INSET is set", function()
			local DEBUG_INSET = 0.25

			local plane = AnimatedWaterPlane(1, 1)
			plane.normalizedSeaLevel = 42
			plane.surfaceRegion.minU = 1
			plane.surfaceRegion.minV = 1
			plane.surfaceRegion.maxU = 150
			plane.surfaceRegion.maxV = 150

			-- Need to make sure the terrain is below the sea level to be rendered in the first place
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].southwest_corner_altitude = denormalizeTerrainAltitude(-42)
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].southeast_corner_altitude = denormalizeTerrainAltitude(-42)
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].northwest_corner_altitude = denormalizeTerrainAltitude(-42)
			GND_WITH_A_SINGLE_WATER_PLANE.cubeGrid[0].northeast_corner_altitude = denormalizeTerrainAltitude(-42)

			AnimatedWaterPlane.GEOMETRY_DEBUG_INSET = DEBUG_INSET
			plane:GenerateWaterVertices(GND_WITH_A_SINGLE_WATER_PLANE, 1, 1)
			AnimatedWaterPlane.GEOMETRY_DEBUG_INSET = 0

			assertEquals(#plane.surfaceGeometry.vertexPositions, 12)
			assertEquals(plane.surfaceGeometry.vertexPositions, {
				0 + DEBUG_INSET,
				42,
				0 + DEBUG_INSET,
				2 - DEBUG_INSET,
				42,
				0 + DEBUG_INSET,
				0 + DEBUG_INSET,
				42,
				2 - DEBUG_INSET,
				2 - DEBUG_INSET,
				42,
				2 - DEBUG_INSET,
			})
			assertEquals(#plane.surfaceGeometry.vertexColors, 12)
			assertEquals(plane.surfaceGeometry.vertexColors, { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 })
			assertEquals(#plane.surfaceGeometry.triangleConnections, 6)
			assertEquals(plane.surfaceGeometry.triangleConnections, { 0, 1, 2, 1, 3, 2 })
			assertEquals(#plane.surfaceGeometry.diffuseTextureCoords, 8)
			assertEquals(plane.surfaceGeometry.diffuseTextureCoords, { 0, 1, 0.5, 1, 0, 0.5, 0.5, 0.5 })
		end)
	end)

	describe("Construct", function()
		it("should replace the default material with a specialized one for water surfaces", function()
			local plane = AnimatedWaterPlane()
			assertTrue(instanceof(plane.surfaceGeometry.material, WaterSurfaceMaterial))
		end)

		it("should set the material opacity to 56% for regular water surfaces", function()
			local plane = AnimatedWaterPlane()
			assertEquals(plane.surfaceGeometry.material.opacity, 144 / 255)
		end)

		it("should set the material opacity to 100% for Classic lava surfaces", function()
			local plane = AnimatedWaterPlane(1, 1, {
				textureTypePrefix = 4,
			})
			assertEquals(plane.surfaceGeometry.material.opacity, 1)
		end)

		it("should set the material opacity to 100% for Renewal lava surfaces", function()
			local plane = AnimatedWaterPlane(1, 1, {
				textureTypePrefix = 6,
			})
			assertEquals(plane.surfaceGeometry.material.opacity, 1)
		end)

		it("should create a keyframed animation for the texture cycling", function()
			local plane = AnimatedWaterPlane(2, 3)
			assertEquals(plane.cyclingTextureAnimation.currentAnimationFrame, 1)
			assertEquals(
				plane.cyclingTextureAnimation.numAnimationFrames,
				AnimatedWaterPlane.NUM_FRAMES_PER_TEXTURE_ANIMATION
			)
			assertEquals(plane.cyclingTextureAnimation.frameDisplayDurationInMilliseconds, 50)
			assertTrue(instanceof(plane.cyclingTextureAnimation, KeyframeAnimation))
		end)

		it("should register the cycling texture animation for delta time updates with the Renderer", function()
			local plane = AnimatedWaterPlane()
			assertEquals(plane.surfaceGeometry.keyframeAnimations[1], plane.cyclingTextureAnimation)
		end)
	end)
end)
