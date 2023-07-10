local RagnarokSPR = require("Core.FileFormats.RagnarokSPR")

-- Features: BMP palette appended, BMP and TGA frames, RLE-encoded image data
-- Assertions: No system palette (ancient versions), works on all files in the kRO GRF, works with old (ArcExe/alpha) files?
-- Versions: 0.2 Arcturus (bug? crow.spr = 2.0?), 1.1 Arcturus (mariaspr), 1.2 (2.1) default, 2.2 and 2.3 TBD?
-- TBD: Are 1.0, 2.0, 2.2/2.3 used anywhere?
local SPR_WITH_RLE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "v2-1.spr"))
-- local GND_WITH_SINGLE_WATER_PLANE = C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "single-water-plane.gnd"))
-- local GND_WITH_MULTIPLE_WATER_PLANES =
-- 	C_FileSystem.ReadFile(path.join("Tests", "Fixtures", "multiple-water-planes.gnd"))

describe("RagnarokSPR", function()
	local spr = RagnarokSPR()
	describe("DecodeFileContents", function()
		it("should be able to decode SPR files using version 2.1 of the format", function()
			spr:DecodeFileContents(SPR_WITH_RLE)

			assertEquals(spr.signature, "SP")
			assertEquals(spr.version, 2.1)
			assertEquals(spr.paletteStartOffset, 104233)

			assertEquals(spr.palette.colors[0].red, 255)
			assertEquals(spr.palette.colors[0].green, 0)
			assertEquals(spr.palette.colors[0].blue, 0)
			assertEquals(spr.palette.colors[0].alpha, 0)

			assertEquals(spr.bmpImagesCount, 41) -- TODO 2
			assertEquals(spr.tgaImagesCount, 1) -- TODO 2

			assertEquals(spr.bmpImages[0].pixel_width, 37)
			assertEquals(spr.bmpImages[0].pixel_height, 36)
			assertEquals(spr.bmpImages[0].compressed_buffer_size, 990)

			assertEquals(spr.bmpImages[40].pixel_width, 37)
			assertEquals(spr.bmpImages[40].pixel_height, 36)
			assertEquals(spr.bmpImages[40].compressed_buffer_size, 990)


	-- 		assertEquals(spr.geometryScaleFactor, 10)
	-- 		assertEquals(spr.diffuseTextureCount, 2)
	-- 		assertEquals(spr.texturePathLength, 80)

	-- 		assertEquals(spr.diffuseTexturePaths[0], "TEXTURE1.BMP")
	-- 		assertEquals(spr.diffuseTexturePaths[1], "somedir1\\texture2-01.bmp")

	-- 		assertEquals(spr.lightmapFormat.numSlices, 4)
	-- 		assertEquals(spr.lightmapFormat.pixelWidth, 8)
	-- 		assertEquals(spr.lightmapFormat.pixelHeight, 8)
	-- 		assertEquals(spr.lightmapFormat.pixelFormatID, 1)
	-- 		assertEquals(spr.lightmapSlices[0].ambient_occlusion_texels[0], 255)
	-- 		assertEquals(spr.lightmapSlices[0].baked_lightmap_texels[0], 0)

	-- 		assertEquals(spr.texturedSurfaceCount, 2)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.bottom_left_u, 1)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.bottom_right_u, 1)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.top_left_u, 0)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.top_right_u, 0)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.bottom_left_v, 0)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.bottom_right_v, 1)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.top_left_v, 0)
	-- 		assertEquals(spr.texturedSurfaces[0].uvs.top_right_v, 1)
	-- 		assertEquals(spr.texturedSurfaces[0].texture_id, 0)
	-- 		assertEquals(spr.texturedSurfaces[0].lightmap_slice_id, 0)
	-- 		assertEquals(spr.texturedSurfaces[0].bottom_left_color.red, 255)
	-- 		assertEquals(spr.texturedSurfaces[0].bottom_left_color.blue, 255)
	-- 		assertEquals(spr.texturedSurfaces[0].bottom_left_color.green, 255)
	-- 		assertEquals(spr.texturedSurfaces[0].bottom_left_color.alpha, 255)

	-- 		assertEquals(spr.cubeGrid[0].southwest_corner_altitude, -40)
	-- 		assertEquals(spr.cubeGrid[0].southeast_corner_altitude, -40)
	-- 		assertEquals(spr.cubeGrid[0].northwest_corner_altitude, -40)
	-- 		assertEquals(spr.cubeGrid[0].northeast_corner_altitude, -40)
	-- 		assertEquals(spr.cubeGrid[0].top_surface_id, -1)
	-- 		assertEquals(spr.cubeGrid[0].north_surface_id, -1)
	-- 		assertEquals(spr.cubeGrid[0].east_surface_id, -1)

	-- 		assertEquals(spr.waterPlanesCount, 0)
	-- 		assertEquals(spr.waterGridU, 0)
	-- 		assertEquals(spr.waterGridV, 0)
	-- 	end)

	-- 	it("should be able to decode GND files using version 1.8 of the format", function()
	-- 		gnd:DecodeFileContents(GND_WITH_SINGLE_WATER_PLANE)

	-- 		assertEquals(spr.waterPlanesCount, 1)
	-- 		assertEquals(spr.waterGridU, 1)
	-- 		assertEquals(spr.waterGridV, 1)

	-- 		assertEquals(spr.waterPlaneDefaults.level, 50)
	-- 		assertEquals(spr.waterPlaneDefaults.water_type_id, 0)
	-- 		assertEquals(spr.waterPlaneDefaults.waveform_amplitude, 1)
	-- 		assertEquals(spr.waterPlaneDefaults.waveform_phase, 2)
	-- 		assertEquals(spr.waterPlaneDefaults.surface_curvature_deg, 50)
	-- 		assertEquals(spr.waterPlaneDefaults.texture_cycling_interval, 3)

	-- 		assertEquals(spr.waterPlanes[0].level, 42)
	-- 		assertEquals(spr.waterPlanes[0].water_type_id, 0)
	-- 		assertEquals(spr.waterPlanes[0].waveform_amplitude, 1)
	-- 		assertEquals(spr.waterPlanes[0].waveform_phase, 2)
	-- 		assertEquals(spr.waterPlanes[0].surface_curvature_deg, 50)
	-- 		assertEquals(spr.waterPlanes[0].texture_cycling_interval, 3)
	-- 	end)

	-- 	it("should be able to decode GND files using version 1.9 of the format", function()
	-- 		gnd:DecodeFileContents(GND_WITH_MULTIPLE_WATER_PLANES)
	-- 		assertEquals(spr.waterPlanesCount, 2)
	-- 		assertEquals(spr.waterGridU, 1)
	-- 		assertEquals(spr.waterGridV, 2)

	-- 		assertEquals(spr.waterPlaneDefaults.level, 20)
	-- 		assertEquals(spr.waterPlaneDefaults.water_type_id, 10)
	-- 		assertEquals(spr.waterPlaneDefaults.waveform_amplitude, 1)
	-- 		assertEquals(spr.waterPlaneDefaults.waveform_phase, 1)
	-- 		assertEquals(spr.waterPlaneDefaults.surface_curvature_deg, 50)
	-- 		assertEquals(spr.waterPlaneDefaults.texture_cycling_interval, 3)

	-- 		assertEquals(spr.waterPlanes[0].level, 20)
	-- 		assertEquals(spr.waterPlanes[0].water_type_id, 10)
	-- 		assertEquals(spr.waterPlanes[0].waveform_amplitude, 1)
	-- 		assertEquals(spr.waterPlanes[0].waveform_phase, 1)
	-- 		assertEquals(spr.waterPlanes[0].surface_curvature_deg, 50)
	-- 		assertEquals(spr.waterPlanes[0].texture_cycling_interval, 3)
		end)
	end)
end)
