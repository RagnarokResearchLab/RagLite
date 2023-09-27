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

			assertEquals(gnd.diffuseTexturePaths[0], "TEXTURE1.BMP")
			assertEquals(gnd.diffuseTexturePaths[1], "somedir1\\texture2-01.bmp")

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
end)
