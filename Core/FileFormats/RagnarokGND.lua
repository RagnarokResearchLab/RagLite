local BinaryReader = require("Core.FileFormats.BinaryReader")

local ffi = require("ffi")
local uv = require("uv")

local ffi_copy = ffi.copy
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof
local tonumber = tonumber

local RagnarokGND = {
	DEFAULT_GEOMETRY_SCALE_FACTOR = 10,
	NORMALIZING_SCALE_FACTOR = 1 / (10 / 2), -- 1/(geometryScale / numTilesPerSurface)
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

	self.reader = BinaryReader(fileContents)

	self:DecodeHeader()
	self:DecodeTexturePaths()
	self:DecodeLightmapSlices()
	self:DecodeTexturedSurfaces()
	self:DecodeCubeGrid()
	self:DecodeWaterPlanes()

	local endTime = uv.hrtime()
	local decodingTimeInMilliseconds = (endTime - startTime) / 10E5
	printf("[RagnarokGND] Finished decoding file contents in %.2f ms", decodingTimeInMilliseconds)
end

function RagnarokGND:DecodeHeader()
	local reader = self.reader

	self.signature = reader:GetCountedString(4)
	if self.signature ~= "GRGN" then
		error("Failed to decode GND header (Signature " .. self.signature .. ' should be "GRGN")', 0)
	end

	local majorVersion = reader:GetUnsignedInt8()
	local minorVersion = reader:GetUnsignedInt8()
	self.version = majorVersion + minorVersion / 10
	if self.version < 1.7 or self.version > 1.9 then
		error(format("Unsupported GND version %.1f", self.version), 0)
	end

	self.gridSizeU = reader:GetUnsignedInt32()
	self.gridSizeV = reader:GetUnsignedInt32()
	self.geometryScaleFactor = reader:GetFloat()
	self.diffuseTextureCount = reader:GetUnsignedInt32()
	self.texturePathLength = reader:GetUnsignedInt32()

	if self.geometryScaleFactor ~= self.DEFAULT_GEOMETRY_SCALE_FACTOR then
		error(
			format(
				"Unexpected geometry scale factor %s (should be %s)",
				self.geometryScaleFactor,
				self.DEFAULT_GEOMETRY_SCALE_FACTOR
			),
			0
		)
	end
end

function RagnarokGND:DecodeTexturePaths()
	for textureIndex = 0, self.diffuseTextureCount - 1, 1 do
		local windowsPathString = self.reader:GetNullTerminatedString(self.texturePathLength)
		self.diffuseTexturePaths[textureIndex] = windowsPathString
	end
end

function RagnarokGND:DecodeLightmapSlices()
	local lightmapFormatInfo = self.reader:GetTypedArray("gnd_lightmap_format_t")
	self.lightmapSlices = self.reader:GetTypedArray("gnd_lightmap_slice_t", lightmapFormatInfo.slice_count)

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
	local reader = self.reader
	local numTexturedSurfaces = reader:GetUnsignedInt32()
	self.texturedSurfaceCount = numTexturedSurfaces

	self.texturedSurfaces = reader:GetTypedArray("gnd_textured_surface_t", numTexturedSurfaces)
end

function RagnarokGND:DecodeCubeGrid()
	local numGroundMeshCubes = self.gridSizeU * self.gridSizeV
	self.cubeGrid = self.reader:GetTypedArray("gnd_groundmesh_cube_t", numGroundMeshCubes)
end

function RagnarokGND:DecodeWaterPlanes()
	if self.version < 1.8 then
		self.waterPlanesCount = 0
		self.waterGridU = 0
		self.waterGridV = 0
		return
	end

	local reader = self.reader

	if self.version >= 1.8 then
		self.waterPlaneDefaults = reader:GetTypedArray("gnd_water_plane_t")

		local gridSizeU = reader:GetUnsignedInt32()
		local gridSizeV = reader:GetUnsignedInt32()

		self.waterPlanesCount = gridSizeU * gridSizeV
		self.waterGridU = gridSizeU
		self.waterGridV = gridSizeV
	end

	for waterPlaneIndex = 0, self.waterGridU * self.waterGridV - 1, 1 do
		if self.version == 1.8 then
			local waterPlane = ffi_new("gnd_water_plane_t")
			ffi_copy(waterPlane, self.waterPlaneDefaults, ffi_sizeof("gnd_water_plane_t"))
			self.waterPlanes[waterPlaneIndex] = waterPlane

			waterPlane.level = reader:GetFloat()
		end

		if self.version >= 1.9 then
			self.waterPlanes[waterPlaneIndex] = reader:GetTypedArray("gnd_water_plane_t")
		end
	end
end

ffi.cdef(RagnarokGND.cdefs)

return RagnarokGND
