local ffi = require("ffi")

local RagnarokGND = require("Core.FileFormats.RagnarokGND")

local GND_WITHOUT_WATER_PLANE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "no-water-plane.gnd"))
local GND_WITH_SINGLE_WATER_PLANE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "single-water-plane.gnd"))
local GND_WITH_MULTIPLE_WATER_PLANES =
	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "multiple-water-planes.gnd"))

describe("RagnarokGND", function()
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

			assertEquals(gnd.waterPlanesCount, 0)
			assertEquals(gnd.waterGridU, 0)
			assertEquals(gnd.waterGridV, 0)
		end)

		it("should be able to decode GND files using version 1.8 of the format", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITH_SINGLE_WATER_PLANE)

			assertEquals(gnd.waterPlanesCount, 1)
			assertEquals(gnd.waterGridU, 1)
			assertEquals(gnd.waterGridV, 1)

			assertEquals(gnd.waterPlaneDefaults.level, 50)
			assertEquals(gnd.waterPlaneDefaults.water_type_id, 0)
			assertEquals(gnd.waterPlaneDefaults.waveform_amplitude, 1)
			assertEquals(gnd.waterPlaneDefaults.waveform_phase, 2)
			assertEquals(gnd.waterPlaneDefaults.surface_curvature_deg, 50)
			assertEquals(gnd.waterPlaneDefaults.texture_cycling_interval, 3)

			assertEquals(gnd.waterPlanes[0].level, 42)
			assertEquals(gnd.waterPlanes[0].water_type_id, 0)
			assertEquals(gnd.waterPlanes[0].waveform_amplitude, 1)
			assertEquals(gnd.waterPlanes[0].waveform_phase, 2)
			assertEquals(gnd.waterPlanes[0].surface_curvature_deg, 50)
			assertEquals(gnd.waterPlanes[0].texture_cycling_interval, 3)
		end)

		it("should be able to decode GND files using version 1.9 of the format", function()
			local gnd = RagnarokGND()
			gnd:DecodeFileContents(GND_WITH_MULTIPLE_WATER_PLANES)
			assertEquals(gnd.waterPlanesCount, 2)
			assertEquals(gnd.waterGridU, 1)
			assertEquals(gnd.waterGridV, 2)

			assertEquals(gnd.waterPlaneDefaults.level, 20)
			assertEquals(gnd.waterPlaneDefaults.water_type_id, 10)
			assertEquals(gnd.waterPlaneDefaults.waveform_amplitude, 1)
			assertEquals(gnd.waterPlaneDefaults.waveform_phase, 1)
			assertEquals(gnd.waterPlaneDefaults.surface_curvature_deg, 50)
			assertEquals(gnd.waterPlaneDefaults.texture_cycling_interval, 3)

			assertEquals(gnd.waterPlanes[0].level, 20)
			assertEquals(gnd.waterPlanes[0].water_type_id, 10)
			assertEquals(gnd.waterPlanes[0].waveform_amplitude, 1)
			assertEquals(gnd.waterPlanes[0].waveform_phase, 1)
			assertEquals(gnd.waterPlanes[0].surface_curvature_deg, 50)
			assertEquals(gnd.waterPlanes[0].texture_cycling_interval, 3)
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

	describe("GenerateGroundMeshSections", function()
		it("should generate one ground mesh section per diffuse texture", function()
			local gnd = RagnarokGND()
			gnd.gridSizeU = 3
			gnd.gridSizeV = 3
			gnd.cubeGrid = ffi.new("gnd_groundmesh_cube_t[?]", gnd.gridSizeU * gnd.gridSizeV)
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
			gnd.groundMeshSections = {
				{
					vertexPositions = {},
					vertexColors = {},
					triangleConnections = {},
					diffuseTextureCoords = {},
				},
			}
			local sections = gnd:GenerateGroundMeshSections()
			assertEquals(#sections, 1) -- Index starts at zero
			assertEquals(table.count(sections), 1)
			local json = require("json")
			local jsonDump = json.prettier(sections)
			-- Leaving this here because the snapshot likely needs to be recreated once lightmaps/normals are needed
			-- C_FileSystem.WriteFile(path.join("Tests", "Fixtures", "Snapshots", "gnd-geometry.json"), jsonDump)
			local snapshot = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "Snapshots", "gnd-geometry.json"))
			assertEquals(json.parse(jsonDump), json.parse(snapshot)) -- Workaround for encoding issues in the CI :/
		end)
	end)
end)
