local BinaryReader = require("Core.FileFormats.BinaryReader")

local ffi = require("ffi")
local uv = require("uv")

local assert = assert
local ffi_copy = ffi.copy
local ffi_new = ffi.new
local ffi_sizeof = ffi.sizeof
local format = string.format
local table_insert = table.insert
local tonumber = tonumber

local RagnarokGND = {
	GAT_TILES_PER_GND_SURFACE = 2,
	DEFAULT_GEOMETRY_SCALE_FACTOR = 10,
	SURFACE_DIRECTION_UP = 0,
	SURFACE_DIRECTION_EAST = 1,
	SURFACE_DIRECTION_NORTH = 2,
	FALLBACK_VERTEX_COLOR = {
		red = 0,
		green = 0,
		blue = 0,
		alpha = 255,
	},
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

local worldUnitsPerSurface = RagnarokGND.DEFAULT_GEOMETRY_SCALE_FACTOR
local worldUnitsPerTile = worldUnitsPerSurface / RagnarokGND.GAT_TILES_PER_GND_SURFACE
RagnarokGND.NORMALIZING_SCALE_FACTOR = 1 / worldUnitsPerTile

function RagnarokGND:Construct()
	local instance = {
		diffuseTexturePaths = {},
		groundMeshSections = {},
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

	local numBytesRemaining = self.reader.endOfFilePointer - self.reader.virtualFilePointer
	local eofErrorMessage = format("Detected %s leftover bytes at the end of the structure!", numBytesRemaining)
	assert(self.reader:HasReachedEOF(), eofErrorMessage)

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
	for textureIndex = 1, self.diffuseTextureCount, 1 do
		local windowsPathString = self.reader:GetNullTerminatedString(self.texturePathLength)
		table_insert(self.diffuseTexturePaths, windowsPathString)

		local groundMeshSection = {
			vertexPositions = {},
			vertexColors = {},
			triangleConnections = {},
			diffuseTextureCoords = {},
		}
		table_insert(self.groundMeshSections, groundMeshSection)
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

function RagnarokGND:GenerateGroundMeshSections()
	local startTime = uv.hrtime()

	for gridV = 1, self.gridSizeV do
		for gridU = 1, self.gridSizeU do
			local cubeID = self:GridPositionToCubeID(gridU, gridV)
			local cube = self.cubeGrid[cubeID]

			-- Walls can't be raised if there's no adjacent cube to connect the surface to
			local isOnMapBoundaryU = (gridU == self.gridSizeU)
			local isOnMapBoundaryV = (gridV == self.gridSizeV)

			-- Despite this fact, EAST/NORTH surfaces sometimes appear on map boundaries (e.g., in c_tower4 and juperos_01)
			-- Since that doesn't make any sense and is probably an oversight, just ignore them completely here ¯\_(ツ)_/¯
			local hasGroundSurface = (cube.top_surface_id >= 0)
			local hasWallSurfaceNorth = (cube.north_surface_id >= 0) and not isOnMapBoundaryV
			local hasWallSurfaceEast = (cube.east_surface_id >= 0) and not isOnMapBoundaryU

			assert(cube.top_surface_id < self.texturedSurfaceCount)
			assert(cube.north_surface_id < self.texturedSurfaceCount)
			assert(cube.east_surface_id < self.texturedSurfaceCount)

			local groundSurface = self.texturedSurfaces[cube.top_surface_id]
			local wallSurfaceNorth = self.texturedSurfaces[cube.north_surface_id]
			local wallSurfaceEast = self.texturedSurfaces[cube.east_surface_id]

			if hasGroundSurface then
				self:GenerateSurfaceGeometry({
					surfaceDefinition = groundSurface,
					gridU = gridU,
					gridV = gridV,
					facing = RagnarokGND.SURFACE_DIRECTION_UP,
				})
			end

			if hasWallSurfaceNorth then
				self:GenerateSurfaceGeometry({
					surfaceDefinition = wallSurfaceNorth,
					gridU = gridU,
					gridV = gridV,
					facing = RagnarokGND.SURFACE_DIRECTION_NORTH,
				})
			end

			if hasWallSurfaceEast then
				self:GenerateSurfaceGeometry({
					surfaceDefinition = wallSurfaceEast,
					gridU = gridU,
					gridV = gridV,
					facing = RagnarokGND.SURFACE_DIRECTION_EAST,
				})
			end
		end
	end

	local endTime = uv.hrtime()
	local terrainGenerationTimeInMilliseconds = (endTime - startTime) / 10E5
	printf(
		"[RagnarokGND] Finished generating terrain geometry for %d ground mesh section(s) in %.2f ms",
		self.diffuseTextureCount,
		terrainGenerationTimeInMilliseconds
	)

	return self.groundMeshSections
end

function RagnarokGND:GridPositionToCubeID(gridU, gridV)
	if gridU <= 0 or gridV <= 0 or gridU > self.gridSizeU or gridV > self.gridSizeV then
		return nil, format("Grid position (%d, %d) is out of bounds", gridU, gridV)
	end

	return (gridU - 1) + (gridV - 1) * self.gridSizeU
end

function RagnarokGND:GenerateSurfaceGeometry(surfaceConstructionInfo)
	local gridU = surfaceConstructionInfo.gridU
	local gridV = surfaceConstructionInfo.gridV

	local bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner
	local bottomLeftVertexColor, bottomRightVertexColor, topLeftVertexColor, topRightVertexColor

	if surfaceConstructionInfo.facing == RagnarokGND.SURFACE_DIRECTION_UP then
		bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner = self:GenerateGroundVertices(gridU, gridV)

		bottomLeftVertexColor = self:PickVertexColor(gridU, gridV)
		bottomRightVertexColor = self:PickVertexColor(gridU + 1, gridV)
		topLeftVertexColor = self:PickVertexColor(gridU, gridV + 1)
		topRightVertexColor = self:PickVertexColor(gridU + 1, gridV + 1)
	elseif surfaceConstructionInfo.facing == RagnarokGND.SURFACE_DIRECTION_NORTH then
		bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner =
			self:GenerateWallVerticesNorth(gridU, gridV)

		bottomLeftVertexColor = self:PickVertexColor(gridU, gridV + 1)
		bottomRightVertexColor = self:PickVertexColor(gridU + 1, gridV + 1)
		topLeftVertexColor = self:PickVertexColor(gridU, gridV + 1)
		topRightVertexColor = self:PickVertexColor(gridU + 1, gridV + 1)
	else -- Implicit: SURFACE_DIRECTION_EAST
		bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner = self:GenerateWallVerticesEast(gridU, gridV)

		bottomLeftVertexColor = self:PickVertexColor(gridU + 1, gridV + 1)
		bottomRightVertexColor = self:PickVertexColor(gridU + 1, gridV)
		topLeftVertexColor = self:PickVertexColor(gridU + 1, gridV + 1)
		topRightVertexColor = self:PickVertexColor(gridU + 1, gridV)
	end

	local surface = surfaceConstructionInfo.surfaceDefinition
	local mesh = self.groundMeshSections[surface.texture_id + 1]
	local nextAvailableVertexID = #mesh.vertexPositions / 3

	table_insert(mesh.vertexPositions, bottomLeftCorner.x)
	table_insert(mesh.vertexPositions, bottomLeftCorner.y)
	table_insert(mesh.vertexPositions, bottomLeftCorner.z)
	table_insert(mesh.vertexPositions, bottomRightCorner.x)
	table_insert(mesh.vertexPositions, bottomRightCorner.y)
	table_insert(mesh.vertexPositions, bottomRightCorner.z)
	table_insert(mesh.vertexPositions, topLeftCorner.x)
	table_insert(mesh.vertexPositions, topLeftCorner.y)
	table_insert(mesh.vertexPositions, topLeftCorner.z)
	table_insert(mesh.vertexPositions, topRightCorner.x)
	table_insert(mesh.vertexPositions, topRightCorner.y)
	table_insert(mesh.vertexPositions, topRightCorner.z)

	table_insert(mesh.vertexColors, bottomLeftVertexColor.red / 255)
	table_insert(mesh.vertexColors, bottomLeftVertexColor.green / 255)
	table_insert(mesh.vertexColors, bottomLeftVertexColor.blue / 255)
	table_insert(mesh.vertexColors, bottomRightVertexColor.red / 255)
	table_insert(mesh.vertexColors, bottomRightVertexColor.green / 255)
	table_insert(mesh.vertexColors, bottomRightVertexColor.blue / 255)
	table_insert(mesh.vertexColors, topLeftVertexColor.red / 255)
	table_insert(mesh.vertexColors, topLeftVertexColor.green / 255)
	table_insert(mesh.vertexColors, topLeftVertexColor.blue / 255)
	table_insert(mesh.vertexColors, topRightVertexColor.red / 255)
	table_insert(mesh.vertexColors, topRightVertexColor.green / 255)
	table_insert(mesh.vertexColors, topRightVertexColor.blue / 255)

	table_insert(mesh.triangleConnections, nextAvailableVertexID)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 1)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 2)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 1)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 3)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 2)

	table_insert(mesh.diffuseTextureCoords, surface.uvs.bottom_left_u)
	table_insert(mesh.diffuseTextureCoords, surface.uvs.bottom_left_v)
	table_insert(mesh.diffuseTextureCoords, surface.uvs.bottom_right_u)
	table_insert(mesh.diffuseTextureCoords, surface.uvs.bottom_right_v)
	table_insert(mesh.diffuseTextureCoords, surface.uvs.top_left_u)
	table_insert(mesh.diffuseTextureCoords, surface.uvs.top_left_v)
	table_insert(mesh.diffuseTextureCoords, surface.uvs.top_right_u)
	table_insert(mesh.diffuseTextureCoords, surface.uvs.top_right_v)
end

function RagnarokGND:GenerateGroundVertices(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)

	assert(cubeID ~= nil, format("Failed to generate GROUND surface at (%d, %d)", gridU, gridV))

	local cube = self.cubeGrid[cubeID]

	local bottomLeftCorner = {}
	local bottomRightCorner = {}
	local topLeftCorner = {}
	local topRightCorner = {}

	bottomLeftCorner.x = (gridU - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	bottomLeftCorner.y = -1 * cube.southwest_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	bottomLeftCorner.z = (gridV - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	bottomRightCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	bottomRightCorner.y = -1 * cube.southeast_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	bottomRightCorner.z = (gridV - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	topLeftCorner.x = (gridU - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	topLeftCorner.y = -1 * cube.northwest_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	topLeftCorner.z = (gridV + 0) * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	topRightCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	topRightCorner.y = -1 * cube.northeast_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	topRightCorner.z = gridV * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	return bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner
end

function RagnarokGND:GenerateWallVerticesNorth(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)
	local adjacentCubeNorthID = self:GridPositionToCubeID(gridU, gridV + 1)

	assert(cubeID ~= nil, format("Failed to generate EAST surface at (%d, %d)", gridU, gridV))
	assert(adjacentCubeNorthID ~= nil, format("Failed to generate EAST surface at (%d, %d)", gridU, gridV))

	local cube = self.cubeGrid[cubeID]
	local adjacentCubeNorth = self.cubeGrid[adjacentCubeNorthID]

	local bottomLeftCorner = {}
	local bottomRightCorner = {}
	local topLeftCorner = {}
	local topRightCorner = {}

	bottomLeftCorner.x = (gridU - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	bottomLeftCorner.y = -1 * cube.northwest_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	bottomLeftCorner.z = gridV * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	bottomRightCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	bottomRightCorner.y = -1 * cube.northeast_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	bottomRightCorner.z = gridV * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	topLeftCorner.x = (gridU - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	topLeftCorner.y = -1 * adjacentCubeNorth.southwest_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	topLeftCorner.z = gridV * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	topRightCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	topRightCorner.y = -1 * adjacentCubeNorth.southeast_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	topRightCorner.z = gridV * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	return bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner
end

function RagnarokGND:GenerateWallVerticesEast(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)
	local adjacentCubeEastID = self:GridPositionToCubeID(gridU + 1, gridV)

	assert(cubeID ~= nil, format("Failed to generate EAST surface at (%d, %d)", gridU, gridV))
	assert(adjacentCubeEastID ~= nil, format("Failed to generate EAST surface at (%d, %d)", gridU, gridV))

	local cube = self.cubeGrid[cubeID]
	local adjacentCubeEast = self.cubeGrid[adjacentCubeEastID]

	local bottomLeftCorner = {}
	local bottomRightCorner = {}
	local topLeftCorner = {}
	local topRightCorner = {}

	bottomLeftCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	bottomLeftCorner.y = -1 * cube.northeast_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	bottomLeftCorner.z = gridV * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	bottomRightCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	bottomRightCorner.y = -1 * cube.southeast_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	bottomRightCorner.z = (gridV - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	topLeftCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	topLeftCorner.y = -1 * adjacentCubeEast.northwest_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	topLeftCorner.z = gridV * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	topRightCorner.x = gridU * RagnarokGND.GAT_TILES_PER_GND_SURFACE
	topRightCorner.y = -1 * adjacentCubeEast.southwest_corner_altitude * self.NORMALIZING_SCALE_FACTOR
	topRightCorner.z = (gridV - 1) * RagnarokGND.GAT_TILES_PER_GND_SURFACE

	return bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner
end

function RagnarokGND:PickVertexColor(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)
	if not cubeID then
		-- No adjacent cube (grid position is out of bounds)
		return RagnarokGND.FALLBACK_VERTEX_COLOR
	end

	local cube = self.cubeGrid[cubeID]
	if cube.top_surface_id == -1 then
		-- No GROUND surface to copy from
		return RagnarokGND.FALLBACK_VERTEX_COLOR
	end

	local surface = self.texturedSurfaces[cube.top_surface_id]
	return {
		red = surface.bottom_left_color.red,
		green = surface.bottom_left_color.green,
		blue = surface.bottom_left_color.blue,
		alpha = surface.bottom_left_color.alpha,
	}
end

ffi.cdef(RagnarokGND.cdefs)

return RagnarokGND
