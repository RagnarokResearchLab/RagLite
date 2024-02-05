local ffi = require("ffi")
local miniz = require("miniz")

local RagnarokGND = require("Core.FileFormats.RagnarokGND")

local GND_WITHOUT_WATER_PLANE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "no-water-plane.gnd"))
local GND_WITH_SINGLE_WATER_PLANE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "single-water-plane.gnd"))
local GND_WITH_MULTIPLE_WATER_PLANES =
	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "multiple-water-planes.gnd"))

describe("RagnarokGND", function()
	describe("Construct", function()
		it("should use pre-allocated geometry buffers if any have been provided", function()
			local preallocatedGeometryBuffers = {
				{},
			}
			local gnd = RagnarokGND(preallocatedGeometryBuffers)
		end)
	end)

	describe("DecodeFileContents", function()
		it("should throw if the geometry scale factor has changed", function()
			-- A lot of assumptions are based on this being effectively a constant, so let's hope it never does change
			local gnd = RagnarokGND()
			local gndBytes =
				"GRGN\001\007\001\001\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000"
			local function decodeUnexpectedGeometryScaleGND()
				gnd:DecodeFileContents(gndBytes)
			end

			local expectedErrorMessage = "Unexpected geometry scale factor 0 (should be 10)"
			assertThrows(decodeUnexpectedGeometryScaleGND, expectedErrorMessage)
		end)

		it("should throw if the GND version is not supported", function()
			local gnd = RagnarokGND()
			local gndBytes = "GRGN\001\000"
			local function decodeUnexpectedVersionGND()
				gnd:DecodeFileContents(gndBytes)
			end

			local expectedErrorMessage = "Unsupported GND version 1.0"
			assertThrows(decodeUnexpectedVersionGND, expectedErrorMessage)
		end)

		it("should be able to decode GND files using version 1.7 of the format", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITHOUT_WATER_PLANE)

			assertEquals(gnd.signature, "GRGN")
			assertEquals(gnd.version, 1.7)
			assertEquals(gnd.gridSizeU, 1)
			assertEquals(gnd.gridSizeV, 2)
			assertEquals(gnd.geometryScaleFactor, 10)
			assertEquals(gnd.diffuseTextureCount, 2)
			assertEquals(gnd.texturePathLength, 80)

			assertEquals(gnd.diffuseTexturePaths[1], "TEXTURE1.BMP")
			assertEquals(gnd.diffuseTexturePaths[2], "somedir1\\texture2-01.bmp")

			assertEquals(gnd.lightmapFormat.numSlices, 4)
			assertEquals(gnd.lightmapFormat.pixelWidth, 8)
			assertEquals(gnd.lightmapFormat.pixelHeight, 8)
			assertEquals(gnd.lightmapFormat.pixelFormatID, 1)
			assertEquals(gnd.lightmapSlices[0].ambient_occlusion_texels[0], 255)
			assertEquals(gnd.lightmapSlices[0].baked_lightmap_texels[0], 0)

			assertEquals(gnd.texturedSurfaceCount, 2)
			assertEquals(gnd.texturedSurfaces[0].uvs.bottom_left_u, 1)
			assertEquals(gnd.texturedSurfaces[0].uvs.bottom_right_u, 1)
			assertEquals(gnd.texturedSurfaces[0].uvs.top_left_u, 0)
			assertEquals(gnd.texturedSurfaces[0].uvs.top_right_u, 0)
			assertEquals(gnd.texturedSurfaces[0].uvs.bottom_left_v, 0)
			assertEquals(gnd.texturedSurfaces[0].uvs.bottom_right_v, 1)
			assertEquals(gnd.texturedSurfaces[0].uvs.top_left_v, 0)
			assertEquals(gnd.texturedSurfaces[0].uvs.top_right_v, 1)
			assertEquals(gnd.texturedSurfaces[0].texture_id, 0)
			assertEquals(gnd.texturedSurfaces[0].lightmap_slice_id, 0)
			assertEquals(gnd.texturedSurfaces[0].bottom_left_color.red, 255)
			assertEquals(gnd.texturedSurfaces[0].bottom_left_color.blue, 255)
			assertEquals(gnd.texturedSurfaces[0].bottom_left_color.green, 255)
			assertEquals(gnd.texturedSurfaces[0].bottom_left_color.alpha, 255)

			assertEquals(gnd.cubeGrid[0].southwest_corner_altitude, -40)
			assertEquals(gnd.cubeGrid[0].southeast_corner_altitude, -40)
			assertEquals(gnd.cubeGrid[0].northwest_corner_altitude, -40)
			assertEquals(gnd.cubeGrid[0].northeast_corner_altitude, -40)
			assertEquals(gnd.cubeGrid[0].top_surface_id, -1)
			assertEquals(gnd.cubeGrid[0].north_surface_id, -1)
			assertEquals(gnd.cubeGrid[0].east_surface_id, -1)

			assertEquals(#gnd.waterPlanes, 0)
		end)

		it("should be able to decode GND files using version 1.8 of the format", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITH_SINGLE_WATER_PLANE)

			assertEquals(#gnd.waterPlanes, 1)
			assertEquals(gnd.numWaterPlanesU, 1)
			assertEquals(gnd.numWaterPlanesV, 1)

			assertEquals(gnd.waterPlaneDefaults.normalizedSeaLevel, -10)
			assertEquals(gnd.waterPlaneDefaults.textureTypePrefix, 0)
			assertEquals(gnd.waterPlaneDefaults.waveformAmplitudeScalingFactor, 1)
			assertEquals(gnd.waterPlaneDefaults.waveformPhaseShiftInDegreesPerFrame, 2)
			assertEquals(gnd.waterPlaneDefaults.waveformFrequencyInDegrees, 50)
			assertEquals(gnd.waterPlaneDefaults.textureDisplayDurationInFrames, 3)

			assertEqualNumbers(gnd.waterPlanes[1].normalizedSeaLevel, -8.3999996185303, 1E-3)
			assertEquals(gnd.waterPlanes[1].textureTypePrefix, 0)
			assertEquals(gnd.waterPlanes[1].waveformAmplitudeScalingFactor, 1)
			assertEquals(gnd.waterPlanes[1].waveformPhaseShiftInDegreesPerFrame, 2)
			assertEquals(gnd.waterPlanes[1].waveformFrequencyInDegrees, 50)
			assertEquals(gnd.waterPlanes[1].textureDisplayDurationInFrames, 3)
		end)

		it("should be able to decode GND files using version 1.9 of the format", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITH_MULTIPLE_WATER_PLANES)
			assertEquals(#gnd.waterPlanes, 2)
			assertEquals(gnd.numWaterPlanesU, 1)
			assertEquals(gnd.numWaterPlanesV, 2)

			assertEquals(gnd.waterPlaneDefaults.normalizedSeaLevel, -4)
			assertEquals(gnd.waterPlaneDefaults.textureTypePrefix, 10)
			assertEquals(gnd.waterPlaneDefaults.waveformAmplitudeScalingFactor, 1)
			assertEquals(gnd.waterPlaneDefaults.waveformPhaseShiftInDegreesPerFrame, 1)
			assertEquals(gnd.waterPlaneDefaults.waveformFrequencyInDegrees, 50)
			assertEquals(gnd.waterPlaneDefaults.textureDisplayDurationInFrames, 3)

			assertEquals(gnd.waterPlanes[1].normalizedSeaLevel, -4)
			assertEquals(gnd.waterPlanes[1].textureTypePrefix, 10)
			assertEquals(gnd.waterPlanes[1].waveformAmplitudeScalingFactor, 1)
			assertEquals(gnd.waterPlanes[1].waveformPhaseShiftInDegreesPerFrame, 1)
			assertEquals(gnd.waterPlanes[1].waveformFrequencyInDegrees, 50)
			assertEquals(gnd.waterPlanes[1].textureDisplayDurationInFrames, 3)
		end)
	end)

	describe("GridPositionToCubeID", function()
		local gnd = RagnarokGND()
		gnd.gridSizeU = 3
		gnd.gridSizeV = 3
		it("should return the corresponding C-style cube index if a valid grid position was given", function()
			assertEquals(gnd:GridPositionToCubeID(1, 1), 0) -- C arrays start at zero
			assertEquals(gnd:GridPositionToCubeID(2, 1), 1)
			assertEquals(gnd:GridPositionToCubeID(3, 1), 2)
			assertEquals(gnd:GridPositionToCubeID(1, 2), 3)
			assertEquals(gnd:GridPositionToCubeID(2, 2), 4)
			assertEquals(gnd:GridPositionToCubeID(3, 2), 5)
			assertEquals(gnd:GridPositionToCubeID(1, 3), 6)
			assertEquals(gnd:GridPositionToCubeID(2, 3), 7)
			assertEquals(gnd:GridPositionToCubeID(3, 3), 8)
		end)

		it("should fail if the given grid position is out of bounds", function()
			-- The purpose of this is to make sure OOB access raises an error, rather than potentially SEGFAULTing
			assertFailure(function()
				return gnd:GridPositionToCubeID(4, 1)
			end, "Grid position (4, 1) is out of bounds")

			assertFailure(function()
				return gnd:GridPositionToCubeID(1, 4)
			end, "Grid position (1, 4) is out of bounds")

			assertFailure(function()
				return gnd:GridPositionToCubeID(1, -1)
			end, "Grid position (1, -1) is out of bounds")

			assertFailure(function()
				return gnd:GridPositionToCubeID(-1, 1)
			end, "Grid position (-1, 1) is out of bounds")

			assertFailure(function()
				return gnd:GridPositionToCubeID(1, 0)
			end, "Grid position (1, 0) is out of bounds")

			assertFailure(function()
				return gnd:GridPositionToCubeID(0, 1)
			end, "Grid position (0, 1) is out of bounds")

			assertFailure(function()
				return gnd:GridPositionToCubeID(0, 0)
			end, "Grid position (0, 0) is out of bounds")
		end)
	end)

	describe("GridCoordinatesToWorldPosition", function()
		local gnd = RagnarokGND()
		gnd.gridSizeU = 3
		gnd.gridSizeV = 3
		gnd.cubeGrid = ffi.new("gnd_groundmesh_cube_t[9]")

		for cubeV = 1, 3, 1 do
			for cubeU = 1, 3, 1 do
				local cubeID = gnd:GridPositionToCubeID(cubeU, cubeV)
				local cube = gnd.cubeGrid[cubeID]
				local denormalizedAltitude = -1 * (42 + cubeID + 1) * 1 / RagnarokGND.NORMALIZING_SCALE_FACTOR
				cube.southwest_corner_altitude = denormalizedAltitude
				cube.southeast_corner_altitude = denormalizedAltitude
				cube.northwest_corner_altitude = denormalizedAltitude
				cube.northeast_corner_altitude = denormalizedAltitude
			end
		end

		it("should return the normalized world position of the center", function()
			local centerWorldPositions = {
				gnd:GridCoordinatesToWorldPosition(1, 1).center,
				gnd:GridCoordinatesToWorldPosition(2, 1).center,
				gnd:GridCoordinatesToWorldPosition(3, 1).center,
				gnd:GridCoordinatesToWorldPosition(1, 2).center,
				gnd:GridCoordinatesToWorldPosition(2, 2).center,
				gnd:GridCoordinatesToWorldPosition(3, 2).center,
				gnd:GridCoordinatesToWorldPosition(1, 3).center,
				gnd:GridCoordinatesToWorldPosition(2, 3).center,
				gnd:GridCoordinatesToWorldPosition(3, 3).center,
			}

			local index = 1
			local vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 1)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 1)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 3)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 1)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 5)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 1)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 1)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 3)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 3)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 3)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 5)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 3)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 1)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 5)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 3)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 5)
			index = index + 1
			vertex = centerWorldPositions[index]
			assertEquals(vertex.x, 5)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 5)
		end)

		it("should return the normalized world position of the SW corner", function()
			local southwestCornerWorldPositions = {
				gnd:GridCoordinatesToWorldPosition(1, 1).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(2, 1).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(3, 1).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(1, 2).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(2, 2).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(3, 2).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(1, 3).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(2, 3).bottomLeftCorner,
				gnd:GridCoordinatesToWorldPosition(3, 3).bottomLeftCorner,
			}

			local index = 1
			local vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 0)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 0)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 0)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 0)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 0)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 0)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = southwestCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
		end)

		it("should return the normalized world position of the SE corner", function()
			local southeastCornerWorldPositions = {
				gnd:GridCoordinatesToWorldPosition(1, 1).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(2, 1).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(3, 1).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(1, 2).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(2, 2).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(3, 2).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(1, 3).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(2, 3).bottomRightCorner,
				gnd:GridCoordinatesToWorldPosition(3, 3).bottomRightCorner,
			}

			local index = 1
			local vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 0)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 0)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 6)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 0)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 6)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = southeastCornerWorldPositions[index]
			assertEquals(vertex.x, 6)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
		end)

		it("should return the normalized world position of the NW corner", function()
			local northwestCornerWorldPositions = {
				gnd:GridCoordinatesToWorldPosition(1, 1).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(2, 1).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(3, 1).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(1, 2).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(2, 2).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(3, 2).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(1, 3).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(2, 3).topLeftCorner,
				gnd:GridCoordinatesToWorldPosition(3, 3).topLeftCorner,
			}

			local index = 1
			local vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 0)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 0)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 0)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 6)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 6)
			index = index + 1
			vertex = northwestCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 6)
		end)

		it("should return the normalized world position of the NE corner", function()
			local northeastCornerWorldPositions = {
				gnd:GridCoordinatesToWorldPosition(1, 1).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(2, 1).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(3, 1).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(1, 2).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(2, 2).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(3, 2).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(1, 3).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(2, 3).topRightCorner,
				gnd:GridCoordinatesToWorldPosition(3, 3).topRightCorner,
			}

			local index = 1
			local vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 6)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 2)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 6)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 4)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 2)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 6)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 4)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 6)
			index = index + 1
			vertex = northeastCornerWorldPositions[index]
			assertEquals(vertex.x, 6)
			assertEquals(vertex.y, 42 + index)
			assertEquals(vertex.z, 6)
		end)

		it("should fail if the given grid coordinates ae out of bounds", function()
			assertFailure(function()
				return gnd:GridCoordinatesToWorldPosition(4, 1)
			end, "Grid position (4, 1) is out of bounds")

			assertFailure(function()
				return gnd:GridCoordinatesToWorldPosition(1, 4)
			end, "Grid position (1, 4) is out of bounds")

			assertFailure(function()
				return gnd:GridCoordinatesToWorldPosition(1, -1)
			end, "Grid position (1, -1) is out of bounds")

			assertFailure(function()
				return gnd:GridCoordinatesToWorldPosition(-1, 1)
			end, "Grid position (-1, 1) is out of bounds")

			assertFailure(function()
				return gnd:GridCoordinatesToWorldPosition(1, 0)
			end, "Grid position (1, 0) is out of bounds")

			assertFailure(function()
				return gnd:GridCoordinatesToWorldPosition(0, 1)
			end, "Grid position (0, 1) is out of bounds")

			assertFailure(function()
				return gnd:GridCoordinatesToWorldPosition(0, 0)
			end, "Grid position (0, 0) is out of bounds")
		end)
	end)

	describe("GenerateGroundMeshSections", function()
		it("should generate one ground mesh section per diffuse texture", function()
			local gnd = RagnarokGND()
			gnd.gridSizeU = 3
			gnd.gridSizeV = 3
			gnd.cubeGrid = ffi.new("gnd_groundmesh_cube_t[?]", gnd.gridSizeU * gnd.gridSizeV)
			gnd.lightmapFormat = { numSlices = 0 }
			for gridV = 1, gnd.gridSizeV, 1 do
				for gridU = 1, gnd.gridSizeU, 1 do
					local cubeID = (gridU - 1) + (gridV - 1) * gnd.gridSizeU
					local cube = gnd.cubeGrid[cubeID]
					cube.southwest_corner_altitude = -4 * cubeID + 1
					cube.southeast_corner_altitude = -4 * cubeID + 2
					cube.northwest_corner_altitude = -4 * cubeID + 3
					cube.northeast_corner_altitude = -4 * cubeID + 4
				end
			end
			gnd.texturedSurfaces = ffi.new("gnd_textured_surface_t[?]", gnd.gridSizeU * gnd.gridSizeV)
			gnd.texturedSurfaces[0].bottom_left_color.red = 255
			gnd.texturedSurfaces[0].bottom_left_color.green = 255
			gnd.texturedSurfaces[0].bottom_left_color.blue = 255
			gnd.texturedSurfaces[0].bottom_left_color.alpha = 255
			gnd.texturedSurfaces[0].uvs.bottom_left_u = 0
			gnd.texturedSurfaces[0].uvs.bottom_left_v = 0
			gnd.texturedSurfaces[0].uvs.bottom_right_u = 0.25 * 4
			gnd.texturedSurfaces[0].uvs.bottom_right_v = 0
			gnd.texturedSurfaces[0].uvs.top_left_u = 0
			gnd.texturedSurfaces[0].uvs.top_left_v = 0.25 * 4
			gnd.texturedSurfaces[0].uvs.top_right_u = 0.25 * 4
			gnd.texturedSurfaces[0].uvs.top_right_v = 0.25 * 4
			gnd.texturedSurfaceCount = gnd.gridSizeU * gnd.gridSizeV
			gnd.diffuseTextureCount = 1
			gnd.diffuseTexturePaths = {
				"whatever.bmp",
			}
			gnd.groundMeshSections = { -- Not a real Mesh since that can't be serialized as easily
				{
					vertexPositions = {},
					vertexColors = {},
					triangleConnections = {},
					diffuseTextureCoords = {},
					surfaceNormals = {},
					lightmapTextureCoords = {},
				},
			}
			local sections = gnd:GenerateGroundMeshSections()
			assertEquals(#sections, 1) -- Index starts at zero
			assertEquals(table.count(sections), 1)

			-- Remove this once the actual lightmap UVs are being computed
			for index, section in ipairs(sections) do
				section.lightmapTextureCoords = nil -- No need to snapshot placeholder UVs
			end

			local json = require("json")
			local jsonDump = json.prettier(sections)
			-- Leaving this here because the snapshot likely needs to be recreated once lightmaps/normals are needed
			-- C_FileSystem.WriteFile(path.join("Tests", "Fixtures", "Snapshots", "gnd-geometry.json"), jsonDump)
			local snapshot = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Snapshots", "gnd-geometry.json"))
			assertEquals(jsonDump, snapshot)
		end)
	end)

	describe("GenerateLightmapTextureImage", function()
		it("should return a combined shadow-and-lightmap texture with power-of-two dimensions", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITHOUT_WATER_PLANE)
			gnd.lightmapSlices[0].baked_lightmap_texels[0] = 255
			local lightmapTextureImage = gnd:GenerateLightmapTextureImage()
			assertEquals(lightmapTextureImage.width, 2048)
			assertEquals(lightmapTextureImage.height, 8)

			local rawImageBytes = tostring(lightmapTextureImage.rgbaImageBytes)
			local expectedTextureChecksum = 3839217290
			local generatedTextureChecksum = miniz.crc32(rawImageBytes)
			assertEquals(generatedTextureChecksum, expectedTextureChecksum)
		end)

		it("should take into account the selected posterization level if any was given", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITHOUT_WATER_PLANE)
			gnd.lightmapSlices[0].baked_lightmap_texels[0] = 255
			local lightmapTextureImage = gnd:GenerateLightmapTextureImage(0)
			assertEquals(lightmapTextureImage.width, 2048)
			assertEquals(lightmapTextureImage.height, 8)

			local rawImageBytes = tostring(lightmapTextureImage.rgbaImageBytes)
			local expectedTextureChecksum = 3127357477
			local generatedTextureChecksum = miniz.crc32(rawImageBytes)
			assertEquals(generatedTextureChecksum, expectedTextureChecksum)
		end)
	end)

	describe("ComputeLightmapTextureCoords", function()
		it("should return the set of texture coordinates that corresponds to the given lightmap slice", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITHOUT_WATER_PLANE)

			assertEquals(gnd:ComputeLightmapTextureCoords(0), {
				bottomLeftU = 0.00048828125,
				bottomLeftV = 0.125,
				bottomRightU = 0.00341796875,
				bottomRightV = 0.125,
				topLeftU = 0.00048828125,
				topLeftV = 0.875,
				topRightU = 0.00341796875,
				topRightV = 0.875,
			})
			assertEquals(gnd:ComputeLightmapTextureCoords(1), {
				bottomLeftU = 0.00439453125,
				bottomLeftV = 0.125,
				bottomRightU = 0.00732421875,
				bottomRightV = 0.125,
				topLeftU = 0.00439453125,
				topLeftV = 0.875,
				topRightU = 0.00732421875,
				topRightV = 0.875,
			})
			assertEquals(gnd:ComputeLightmapTextureCoords(3), {
				bottomLeftU = 0.01220703125,
				bottomLeftV = 0.125,
				bottomRightU = 0.01513671875,
				bottomRightV = 0.125,
				topLeftU = 0.01220703125,
				topLeftV = 0.875,
				topRightU = 0.01513671875,
				topRightV = 0.875,
			})
		end)
	end)
end)
