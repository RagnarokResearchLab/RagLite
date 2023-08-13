local ffi = require("ffi")
local uv = require("uv")

local ffi_cast = ffi.cast
local ffi_copy = ffi.copy
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof
local ffi_string = ffi.string
local tonumber = tonumber

local RagnarokGND = {
	cdefs = [[
		#pragma pack(1)
		typedef struct gnd_header {
			char signature[4];
			uint8_t version_major;
			uint8_t version_minor;
			uint32_t grid_size_u;
			uint32_t grid_size_v;
			float geometry_scale_factor;
			uint32_t texture_count;
			uint32_t texture_path_length;
		} gnd_header_t;

		typedef struct gnd_lightmap_format {
			uint32_t slice_count;
			uint32_t slice_width;
			uint32_t slice_height;
			int32_t pixel_format;
		} gnd_lightmap_format_t;

		typedef struct vertex_color {
			uint8_t blue;
			uint8_t green;
			uint8_t red;
			uint8_t alpha;
		} vertex_color_t;

		typedef struct gnd_lightmap_slice {
			// Hardcoded since the format is unlikely to change
			uint8_t ambient_occlusion_texels[64];
			uint8_t baked_lightmap_texels[192];
		} gnd_lightmap_slice_t;

		typedef struct gnd_texture_coords {
			float bottom_left_u;
			float bottom_right_u;
			float top_left_u;
			float top_right_u;
			float bottom_left_v;
			float bottom_right_v;
			float top_left_v;
			float top_right_v;
		} gnd_texture_coords_t;

		typedef struct gnd_textured_surface {
			gnd_texture_coords_t uvs;
			int16_t texture_id;
			uint16_t lightmap_slice_id;
			vertex_color_t bottom_left_color;
		} gnd_textured_surface_t;

		typedef struct gnd_groundmesh_cube {
			float southwest_corner_altitude;
			float southeast_corner_altitude;
			float northwest_corner_altitude;
			float northeast_corner_altitude;
			int32_t top_surface_id;
			int32_t north_surface_id;
			int32_t east_surface_id;
		} gnd_groundmesh_cube_t;

		typedef struct gnd_water_plane {
			float level;
			int32_t water_type_id;
			float waveform_amplitude;
			float waveform_phase;
			float surface_curvature_deg;
			int32_t texture_cycling_interval;
		} gnd_water_plane_t;

	]],
}

function RagnarokGND:Construct()
	local instance = {
		diffuseTexturePaths = {},
		waterPlanes = {},
	}

	setmetatable(instance, self)

	return instance
end

RagnarokGND.__index = RagnarokGND
RagnarokGND.__call = RagnarokGND.Construct
setmetatable(RagnarokGND, RagnarokGND)

function RagnarokGND:DecodeFileContents(fileContents)
	local startTime = uv.hrtime()

	self.fileContents = ffi_cast("char*", fileContents)

	self:DecodeHeader()
	self:DecodeTexturePaths()
	self:DecodeLightmapSlices()
	self:DecodeTexturedSurfaces()
	self:DecodeCubeGrid()
	self:DecodeWaterPlanes()

	self.fileContents = fileContents -- GC anchor for the cdata used internally

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokGND] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokGND:DecodeHeader()
	local header = ffi_cast("gnd_header_t*", self.fileContents)
	local headerSize = ffi_sizeof(header.signature)

	self.signature = ffi_string(header.signature, headerSize)
	if self.signature ~= "GRGN" then
		error("Failed to decode GND header (Signature " .. self.signature .. ' should be "GRGN")', 0)
	end

	self.version = header.version_major + header.version_minor / 10

	self.gridSizeU = tonumber(header.grid_size_u)
	self.gridSizeV = tonumber(header.grid_size_v)
	self.geometryScaleFactor = tonumber(header.geometry_scale_factor)
	self.diffuseTextureCount = tonumber(header.texture_count)
	self.texturePathLength = tonumber(header.texture_path_length)

	assert(self.geometryScaleFactor == 10, "Unexpected geometry scale factor")

	self.fileContents = self.fileContents + ffi_sizeof("gnd_header_t")
end

function RagnarokGND:DecodeTexturePaths()
	for textureIndex = 0, self.diffuseTextureCount - 1, 1 do
		local windowsPathString = ffi_string(self.fileContents)
		self.diffuseTexturePaths[textureIndex] = windowsPathString
		self.fileContents = self.fileContents + self.texturePathLength
	end
end

function RagnarokGND:DecodeLightmapSlices()
	local lightmapFormatInfo = ffi_cast("gnd_lightmap_format_t*", self.fileContents)
	self.fileContents = self.fileContents + ffi_sizeof("gnd_lightmap_format_t")

	self.lightmapSlices = ffi_cast("gnd_lightmap_slice_t*", self.fileContents)
	self.fileContents = self.fileContents + lightmapFormatInfo.slice_count * ffi_sizeof("gnd_lightmap_slice_t")

	self.lightmapFormat = {
		numSlices = tonumber(lightmapFormatInfo.slice_count),
		pixelWidth = tonumber(lightmapFormatInfo.slice_width),
		pixelHeight = tonumber(lightmapFormatInfo.slice_height),
		pixelFormatID = tonumber(lightmapFormatInfo.pixel_format),
	}

	-- Basic sanity checks (since other formats aren't supported)
	assert(self.lightmapFormat.pixelFormatID == 1, "Unexpected lightmap pixel format")
	assert(self.lightmapFormat.pixelWidth == 8, "Unexpected lightmap pixel size")
	assert(self.lightmapFormat.pixelHeight == 8, "Unexpected lightmap pixel height")
end

function RagnarokGND:DecodeTexturedSurfaces()
	local numTexturedSurfaces = tonumber(ffi_cast("uint32_t*", self.fileContents)[0])
	self.fileContents = self.fileContents + ffi_sizeof("uint32_t")

	self.texturedSurfaces = ffi_cast("gnd_textured_surface_t*", self.fileContents)
	self.fileContents = self.fileContents + numTexturedSurfaces * ffi_sizeof("gnd_textured_surface_t")

	self.texturedSurfaceCount = numTexturedSurfaces
end

function RagnarokGND:DecodeCubeGrid()
	local numGroundMeshCubes = self.gridSizeU * self.gridSizeV

	self.cubeGrid = ffi_cast("gnd_groundmesh_cube_t*", self.fileContents)
	self.fileContents = self.fileContents + numGroundMeshCubes * ffi_sizeof("gnd_groundmesh_cube_t")
end

function RagnarokGND:DecodeWaterPlanes()
	if self.version < 1.8 then
		self.waterPlanesCount = 0
		self.waterGridU = 0
		self.waterGridV = 0
		return
	end

	if self.version >= 1.8 then
		self.waterPlaneDefaults = ffi_cast("gnd_water_plane_t*", self.fileContents)
		self.fileContents = self.fileContents + ffi_sizeof("gnd_water_plane_t")

		local gridSizeU = tonumber(ffi_cast("uint32_t*", self.fileContents)[0])
		self.fileContents = self.fileContents + ffi_sizeof("uint32_t")

		local gridSizeV = tonumber(ffi_cast("uint32_t*", self.fileContents)[0])
		self.fileContents = self.fileContents + ffi_sizeof("uint32_t")

		self.waterPlanesCount = gridSizeU * gridSizeV
		self.waterGridU = gridSizeU
		self.waterGridV = gridSizeV
	end

	for waterPlaneIndex = 0, self.waterGridU * self.waterGridV - 1, 1 do
		if self.version == 1.8 then
			local waterPlane = ffi_new("gnd_water_plane_t")
			ffi_copy(waterPlane, self.waterPlaneDefaults, ffi_sizeof("gnd_water_plane_t"))

			waterPlane.level = tonumber(ffi_cast("float*", self.fileContents)[0])
			self.fileContents = self.fileContents + ffi_sizeof("float")

			self.waterPlanes[waterPlaneIndex] = waterPlane
		end

		if self.version >= 1.9 then
			self.waterPlanes[waterPlaneIndex] = ffi_cast("gnd_water_plane_t*", self.fileContents)
			self.fileContents = self.fileContents + self.waterPlanesCount * ffi_sizeof("gnd_water_plane_t")
		end
	end
end

ffi.cdef(RagnarokGND.cdefs)

return RagnarokGND
