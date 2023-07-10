local ffi = require("ffi")
local uv = require("uv")

local ffi_cast = ffi.cast
local ffi_copy = ffi.copy
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof
local ffi_string = ffi.string
local tonumber = tonumber

local RagnarokSPR = {
	cdefs = [[
		#pragma pack(1)
		typedef struct spr_header {
			char signature[2];
			uint8_t version_minor;
			uint8_t version_major;
			uint16_t bmp_images_count;
			uint16_t tga_images_count;
		} spr_header_t;

		typedef struct spr_palette_color {
			uint8_t red;
			uint8_t green;
			uint8_t blue;
			uint8_t alpha;
		} spr_palette_color_t;

		typedef struct spr_palette {
			spr_palette_color_t colors[256];
		} spr_palette_t;

		typedef struct spr_rle_bitmap {
			uint16_t pixel_width;
			uint16_t pixel_height;
			uint16_t compressed_buffer_size;
			uint16_t decompressed_buffer_size;
			unsigned char* rle_encoded_pixels;
		} spr_rle_bitmap_t;
	]],
}

function RagnarokSPR:Construct()
	local instance = {
		bmpImages = {},
-- 		waterPlanes = {},
	}

	setmetatable(instance, self)

	return instance
end

RagnarokSPR.__index = RagnarokSPR
RagnarokSPR.__call = RagnarokSPR.Construct
setmetatable(RagnarokSPR, RagnarokSPR)

function RagnarokSPR:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.fileContents = ffi_cast("char*", fileContents)

	self:DecodeHeader()
	self:DecodeColorPalette(#fileContents)
	self:DecodeIndexedColorBitmapsWithRLE() -- TBD: 2.1 only?
	-- 	self:DecodeTexturedSurfaces()
	-- 	self:DecodeCubeGrid()
	-- 	self:DecodeWaterPlanes()

	self.fileContents = fileContents -- GC anchor for the cdata used internally

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokSPR] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokSPR:DecodeHeader()
	local header = ffi_cast("spr_header_t*", self.fileContents)
	local headerSize = ffi_sizeof(header.signature)

	self.signature = ffi_string(header.signature, headerSize)
	if self.signature ~= "SP" then
		error("Failed to decode SPR header (Signature " .. self.signature .. ' should be "SP")', 0)
	end

	self.version = header.version_major + header.version_minor / 10

	self.bmpImagesCount = tonumber(header.bmp_images_count)
	self.tgaImagesCount = tonumber(header.tga_images_count)
-- 	self.geometryScaleFactor = tonumber(header.geometry_scale_factor)
-- 	self.diffuseTextureCount = tonumber(header.texture_count)
-- 	self.texturePathLength = tonumber(header.texture_path_length)

-- 	assert(self.geometryScaleFactor == 10, "Unexpected geometry scale factor")

	self.fileContents = self.fileContents + ffi_sizeof("spr_header_t")
end

function RagnarokSPR:DecodeColorPalette(endOfFileOffset)
	local paletteStartOffset = endOfFileOffset - ffi_sizeof("spr_palette_t")
	local numSkippedBytes = ffi_sizeof("spr_header_t")
	self.palette = ffi_cast("spr_palette_t*", self.fileContents -  numSkippedBytes + paletteStartOffset)

	self.paletteStartOffset = paletteStartOffset
end

function RagnarokSPR:DecodeIndexedColorBitmapsWithRLE()

	-- if version then early exit

		for index = 0, self.bmpImagesCount - 1, 1 do
			local runLengthEncodedImage = ffi_cast("spr_rle_bitmap_t*", self.fileContents)
			runLengthEncodedImage.decompressed_buffer_size = 1332 -- TODO
			-- rle_encoded_pixels = set ptr, zero copy
			self.bmpImages[index] = runLengthEncodedImage
		end
-- 	self.fileContents = self.fileContents + ffi_sizeof("gnd_lightmap_format_t")

-- 	self.lightmapSlices = ffi_cast("gnd_lightmap_slice_t*", self.fileContents)
-- 	self.fileContents = self.fileContents + lightmapFormatInfo.slice_count * ffi_sizeof("gnd_lightmap_slice_t")

-- 	self.lightmapFormat = {
-- 		numSlices = tonumber(lightmapFormatInfo.slice_count),
-- 		pixelWidth = tonumber(lightmapFormatInfo.slice_width),
-- 		pixelHeight = tonumber(lightmapFormatInfo.slice_height),
-- 		pixelFormatID = tonumber(lightmapFormatInfo.pixel_format),
-- 	}

-- 	-- Basic sanity checks (since other formats aren't supported)
-- 	assert(self.lightmapFormat.pixelFormatID == 1, "Unexpected lightmap pixel format")
-- 	assert(self.lightmapFormat.pixelWidth == 8, "Unexpected lightmap pixel size")
-- 	assert(self.lightmapFormat.pixelHeight == 8, "Unexpected lightmap pixel height")
end

-- function RagnarokSPR:DecodeTexturedSurfaces()
-- 	local numTexturedSurfaces = tonumber(ffi_cast("uint32_t*", self.fileContents)[0])
-- 	self.fileContents = self.fileContents + ffi_sizeof("uint32_t")

-- 	self.texturedSurfaces = ffi_cast("gnd_textured_surface_t*", self.fileContents)
-- 	self.fileContents = self.fileContents + numTexturedSurfaces * ffi_sizeof("gnd_textured_surface_t")

-- 	self.texturedSurfaceCount = numTexturedSurfaces
-- end

-- function RagnarokSPR:DecodeCubeGrid()
-- 	local numGroundMeshCubes = self.gridSizeU * self.gridSizeV

-- 	self.cubeGrid = ffi_cast("gnd_groundmesh_cube_t*", self.fileContents)
-- 	self.fileContents = self.fileContents + numGroundMeshCubes * ffi_sizeof("gnd_groundmesh_cube_t")
-- end

-- function RagnarokSPR:DecodeWaterPlanes()
-- 	if self.version < 1.8 then
-- 		self.waterPlanesCount = 0
-- 		self.waterGridU = 0
-- 		self.waterGridV = 0
-- 		return
-- 	end

-- 	if self.version >= 1.8 then
-- 		self.waterPlaneDefaults = ffi_cast("gnd_water_plane_t*", self.fileContents)
-- 		self.fileContents = self.fileContents + ffi_sizeof("gnd_water_plane_t")

-- 		local gridSizeU = tonumber(ffi_cast("uint32_t*", self.fileContents)[0])
-- 		self.fileContents = self.fileContents + ffi_sizeof("uint32_t")

-- 		local gridSizeV = tonumber(ffi_cast("uint32_t*", self.fileContents)[0])
-- 		self.fileContents = self.fileContents + ffi_sizeof("uint32_t")

-- 		self.waterPlanesCount = gridSizeU * gridSizeV
-- 		self.waterGridU = gridSizeU
-- 		self.waterGridV = gridSizeV
-- 	end

-- 	for waterPlaneIndex = 0, self.waterGridU * self.waterGridV - 1, 1 do
-- 		if self.version == 1.8 then
-- 			local waterPlane = ffi_new("gnd_water_plane_t")
-- 			ffi_copy(waterPlane, self.waterPlaneDefaults, ffi_sizeof("gnd_water_plane_t"))

-- 			waterPlane.level = tonumber(ffi_cast("float*", self.fileContents)[0])
-- 			self.fileContents = self.fileContents + ffi_sizeof("float")

-- 			self.waterPlanes[waterPlaneIndex] = waterPlane
-- 		end

-- 		if self.version >= 1.9 then
-- 			self.waterPlanes[waterPlaneIndex] = ffi_cast("gnd_water_plane_t*", self.fileContents)
-- 			self.fileContents = self.fileContents + self.waterPlanesCount * ffi_sizeof("gnd_water_plane_t")
-- 		end
-- 	end
-- end

ffi.cdef(RagnarokSPR.cdefs)

return RagnarokSPR
