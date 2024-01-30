local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local BinaryReader = require("Core.FileFormats.BinaryReader")
local Mesh = require("Core.NativeClient.WebGPU.Mesh")
local GroundMeshMaterial = require("Core.NativeClient.WebGPU.Materials.GroundMeshMaterial")
local Vector3D = require("Core.VectorMath.Vector3D")

local bit = require("bit")
local console = require("console")
local ffi = require("ffi")
local uv = require("uv")

local assert = assert
local math_floor = math.floor
local format = string.format
local table_insert = table.insert
local tonumber = tonumber

local RagnarokGND = {
	GAT_TILES_PER_GND_SURFACE = 2,
	DEFAULT_GEOMETRY_SCALE_FACTOR = 10,
	TEXTURED_SURFACE_SIZE_IN_PIXELS = 64, -- 2 GAT tiles at 32 pixels each (grid.tga texture dimensions)
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
		computedVertexPositions = {},
		computedFlatNormals = {
			right = {},
			left = {},
		},
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

		local groundMeshSection = Mesh("GroundMeshSection" .. textureIndex)
		groundMeshSection.material = GroundMeshMaterial("GroundMeshSection" .. textureIndex .. "Material")
		-- Should preallocate based on observed sizes here? (same as for the other buffers)
		groundMeshSection.lightmapTextureCoords = {}
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
	self.computedVertexPositions = table.new(numGroundMeshCubes, 0)
	self.computedFlatNormals.left = table.new(numGroundMeshCubes, 0)
	self.computedFlatNormals.right = table.new(numGroundMeshCubes, 0)
end

function RagnarokGND:DecodeWaterPlanes()
	if self.version < 1.8 then
		self.numWaterPlanesU = 1
		self.numWaterPlanesV = 1
		return -- Legacy format: Water plane is stored in the RSW file instead
	end

	local reader = self.reader
	local waterPlaneDefaults = {
		normalizedSeaLevel = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		textureTypePrefix = reader:GetInt32(),
		waveformAmplitudeScalingFactor = reader:GetFloat(),
		waveformPhaseShiftInDegreesPerFrame = reader:GetFloat(),
		waveformFrequencyInDegrees = reader:GetFloat(),
		textureDisplayDurationInFrames = reader:GetInt32(),
	}

	local numWaterPlanesU = reader:GetUnsignedInt32()
	local numWaterPlanesV = reader:GetUnsignedInt32()

	for waterPlaneV = 1, numWaterPlanesV, 1 do
		for waterPlaneU = 1, numWaterPlanesU, 1 do
			local waterPlane = AnimatedWaterPlane(waterPlaneU, waterPlaneV, waterPlaneDefaults)
			waterPlane.normalizedSeaLevel = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR

			if self.version >= 1.9 then
				waterPlane = AnimatedWaterPlane(waterPlaneU, waterPlaneV, {
					normalizedSeaLevel = waterPlane.normalizedSeaLevel,
					textureTypePrefix = reader:GetInt32(),
					waveformAmplitudeScalingFactor = reader:GetFloat(),
					waveformPhaseShiftInDegreesPerFrame = reader:GetFloat(),
					waveformFrequencyInDegrees = reader:GetFloat(),
					textureDisplayDurationInFrames = reader:GetInt32(),
				})
			end

			table_insert(self.waterPlanes, waterPlane)
		end
	end

	self.waterPlaneDefaults = waterPlaneDefaults
	self.numWaterPlanesU = numWaterPlanesU
	self.numWaterPlanesV = numWaterPlanesV
end

function RagnarokGND:GenerateGroundMeshSections()
	local startTime = uv.hrtime()

	for gridV = 1, self.gridSizeV do
		for gridU = 1, self.gridSizeU do
			local cubeID = self:GridPositionToCubeID(gridU, gridV)
			assert(cubeID < self.gridSizeU * self.gridSizeV)
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

function RagnarokGND:GridCoordinatesToWorldPosition(gridU, gridV)
	if gridU <= 0 or gridV <= 0 or gridU > self.gridSizeU or gridV > self.gridSizeV then
		return nil, format("Grid position (%d, %d) is out of bounds", gridU, gridV)
	end

	local cubeID = self:GridPositionToCubeID(gridU, gridV)
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

	local center = {}
	center.x = (bottomRightCorner.x + bottomLeftCorner.x) / 2
	center.y = (bottomLeftCorner.y + bottomRightCorner.y + topLeftCorner.y + topRightCorner.y) / 4
	center.z = (topRightCorner.z + bottomLeftCorner.z) / 2

	return {
		center = center,
		bottomLeftCorner = bottomLeftCorner,
		bottomRightCorner = bottomRightCorner,
		topLeftCorner = topLeftCorner,
		topRightCorner = topRightCorner,
	}
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

	local lightmapTextureCoords = self:ComputeLightmapTextureCoords(surface.lightmap_slice_id)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.bottomLeftU)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.bottomLeftV)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.bottomRightU)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.bottomRightV)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.topLeftU)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.topLeftV)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.topRightU)
	table_insert(mesh.lightmapTextureCoords, lightmapTextureCoords.topRightV)

	if surfaceConstructionInfo.facing == RagnarokGND.SURFACE_DIRECTION_UP then
		local flatFaceNormalLeft = self:ComputeFlatFaceNormalLeft(gridU, gridV)
		local flatFaceNormalRight = self:ComputeFlatFaceNormalRight(gridU, gridV)

		local flatNormals = {}
		local smoothNormals = {}
		local tinsert = table_insert -- Shorthand to improve readability (single-line inserts after autoformat)

		-- Bottom left corner vertex
		tinsert(flatNormals, flatFaceNormalLeft)
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU - 1, gridV))
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU - 1, gridV))
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU - 1, gridV - 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU, gridV - 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU, gridV - 1))
		smoothNormals.bottomLeft = self:ComputeSmoothNormal(flatNormals)

		-- Bottom right corner vertex
		flatNormals = {}
		tinsert(flatNormals, flatFaceNormalRight)
		tinsert(flatNormals, flatFaceNormalLeft)
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU, gridV - 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU + 1, gridV - 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU + 1, gridV - 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU + 1, gridV))
		smoothNormals.bottomRight = self:ComputeSmoothNormal(flatNormals)

		-- Top left corner vertex
		flatNormals = {}
		tinsert(flatNormals, flatFaceNormalRight)
		tinsert(flatNormals, flatFaceNormalLeft)
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU, gridV + 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU - 1, gridV + 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU - 1, gridV + 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU - 1, gridV))
		smoothNormals.topLeft = self:ComputeSmoothNormal(flatNormals)

		-- Top right corner vertex
		flatNormals = {}
		tinsert(flatNormals, flatFaceNormalRight)
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU + 1, gridV + 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU, gridV + 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU, gridV + 1))
		tinsert(flatNormals, self:ComputeFlatFaceNormalLeft(gridU + 1, gridV))
		tinsert(flatNormals, self:ComputeFlatFaceNormalRight(gridU + 1, gridV))
		smoothNormals.topRight = self:ComputeSmoothNormal(flatNormals)

		-- Vertices that share triangles must be blended in order to smooth the surface when lit
		local averagedFlatNormals = {
			bottomLeft = smoothNormals.bottomLeft,
			bottomRight = smoothNormals.bottomRight,
			topLeft = smoothNormals.topLeft,
			topRight = smoothNormals.topRight,
		}

		-- These have to be stored so that smooth normals can be generated from them
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.bottomLeft.x)
		tinsert(mesh.surfaceNormals, averagedFlatNormals.bottomLeft.y)
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.bottomLeft.z)
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.bottomRight.x)
		tinsert(mesh.surfaceNormals, averagedFlatNormals.bottomRight.y)
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.bottomRight.z)
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.topLeft.x)
		tinsert(mesh.surfaceNormals, averagedFlatNormals.topLeft.y)
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.topLeft.z)
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.topRight.x)
		tinsert(mesh.surfaceNormals, averagedFlatNormals.topRight.y)
		tinsert(mesh.surfaceNormals, -averagedFlatNormals.topRight.z)
	elseif surfaceConstructionInfo.facing == RagnarokGND.SURFACE_DIRECTION_NORTH then
		--  Walls will always be drawn from the higher of the two adjacent cubes to the lower one, at a 90 DEG angle
		local cubeID = self:GridPositionToCubeID(gridU, gridV)
		local cube = self.cubeGrid[cubeID]
		local adjacentCubeID = self:GridPositionToCubeID(gridU, gridV + 1)
		local adjacentCube = self.cubeGrid[adjacentCubeID]

		local isTerrainRising = cube.northwest_corner_altitude >= adjacentCube.southwest_corner_altitude
		-- Altitudes aren't normalized (inverted Y)
		local normalDirection = isTerrainRising and -1 or 1
		for i = 1, 4, 1 do
			table_insert(mesh.surfaceNormals, 0)
			table_insert(mesh.surfaceNormals, 0)
			table_insert(mesh.surfaceNormals, normalDirection)
		end
	else -- Implicit: SURFACE_DIRECTION_EAST
		local cubeID = self:GridPositionToCubeID(gridU, gridV)
		local cube = self.cubeGrid[cubeID]
		local adjacentCubeID = self:GridPositionToCubeID(gridU + 1, gridV)
		local adjacentCube = self.cubeGrid[adjacentCubeID]
		-- Altitudes aren't normalized (inverted Y)
		local isTerrainRising = cube.northeast_corner_altitude >= adjacentCube.northwest_corner_altitude
		local normalDirection = isTerrainRising and -1 or 1
		for i = 1, 4, 1 do
			table_insert(mesh.surfaceNormals, normalDirection)
			table_insert(mesh.surfaceNormals, 0)
			table_insert(mesh.surfaceNormals, 0)
		end
	end
end

function RagnarokGND:ComputeSmoothNormal(flatNormalsToAverage)
	local smoothNormal = Vector3D()

	-- Some may be nil (if no adjacent face exists); they shouldn't affect the average
	for index, adjacentFaceNormal in ipairs(flatNormalsToAverage) do
		smoothNormal = smoothNormal:Add(adjacentFaceNormal)
	end

	smoothNormal:Scale(1 / #flatNormalsToAverage)

	return smoothNormal
end

function RagnarokGND:GenerateGroundVertices(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)

	if cubeID == nil then
		return nil, format("Failed to generate GROUND surface at (%d, %d)", gridU, gridV)
	end

	if self.computedVertexPositions[cubeID] then
		return unpack(self.computedVertexPositions[cubeID])
	end

	assert(cubeID < self.gridSizeU * self.gridSizeV)
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

	self.computedVertexPositions[cubeID] = { bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner }

	return bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner
end

function RagnarokGND:GenerateWallVerticesNorth(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)
	local adjacentCubeNorthID = self:GridPositionToCubeID(gridU, gridV + 1)
	assert(cubeID < self.gridSizeU * self.gridSizeV)
	assert(adjacentCubeNorthID < self.gridSizeU * self.gridSizeV)

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

	assert(cubeID < self.gridSizeU * self.gridSizeV)
	assert(adjacentCubeEastID < self.gridSizeU * self.gridSizeV)

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

	assert(cubeID < self.gridSizeU * self.gridSizeV)
	local cube = self.cubeGrid[cubeID]
	if cube.top_surface_id == -1 then
		-- No GROUND surface to copy from
		return RagnarokGND.FALLBACK_VERTEX_COLOR
	end

	assert(cube.top_surface_id <= self.texturedSurfaceCount)
	local surface = self.texturedSurfaces[cube.top_surface_id]
	return {
		red = surface.bottom_left_color.red,
		green = surface.bottom_left_color.green,
		blue = surface.bottom_left_color.blue,
		alpha = surface.bottom_left_color.alpha,
	}
end

function RagnarokGND:ComputeFlatFaceNormalLeft(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)
	if self.computedFlatNormals.left[cubeID] then
		return self.computedFlatNormals.left[cubeID]
	end

	local bottomLeftCorner, bottomRightCorner, topLeftCorner = self:GenerateGroundVertices(gridU, gridV)

	if not bottomLeftCorner then -- The others probably don't exist either due to OOB access
		return nil
	end

	local displacementBC = {
		x = topLeftCorner.x - bottomRightCorner.x,
		y = -1 * (topLeftCorner.y - bottomRightCorner.y),
		z = topLeftCorner.z - bottomRightCorner.z,
	}

	local displacementAC = {
		x = topLeftCorner.x - bottomLeftCorner.x,
		y = -1 * (topLeftCorner.y - bottomLeftCorner.y),
		z = topLeftCorner.z - bottomLeftCorner.z,
	}
	-- (top left - bottom right) X (top left - bottom left)
	local leftFaceNormal = Vector3D(
		displacementBC.y * displacementAC.z - displacementBC.z * displacementAC.y,
		displacementBC.z * displacementAC.x - displacementBC.x * displacementAC.z,
		displacementBC.x * displacementAC.y - displacementBC.y * displacementAC.x
	)

	leftFaceNormal:Normalize()
	self.computedFlatNormals.left[cubeID] = leftFaceNormal
	return leftFaceNormal
end

function RagnarokGND:ComputeFlatFaceNormalRight(gridU, gridV)
	local cubeID = self:GridPositionToCubeID(gridU, gridV)
	if self.computedFlatNormals.right[cubeID] then
		return self.computedFlatNormals.right[cubeID]
	end

	local bottomLeftCorner, bottomRightCorner, topLeftCorner, topRightCorner = self:GenerateGroundVertices(gridU, gridV)

	if not bottomLeftCorner then -- The others probably don't exist either due to OOB access
		return nil
	end

	-- (top right - bottom right) X (top right - top left)
	local displacementBD = {
		x = topRightCorner.x - bottomRightCorner.x,
		y = -1 * (topRightCorner.y - bottomRightCorner.y),
		z = topRightCorner.z - bottomRightCorner.z,
	}

	local displacementCD = {
		x = topRightCorner.x - topLeftCorner.x,
		y = -1 * (topRightCorner.y - topLeftCorner.y),
		z = topRightCorner.z - topLeftCorner.z,
	}
	local rightFaceNormal = Vector3D(
		displacementBD.y * displacementCD.z - displacementBD.z * displacementCD.y,
		displacementBD.z * displacementCD.x - displacementBD.x * displacementCD.z,
		displacementBD.x * displacementCD.y - displacementBD.y * displacementCD.x
	)

	rightFaceNormal:Normalize()
	self.computedFlatNormals.right[cubeID] = rightFaceNormal
	return rightFaceNormal
end

local function nextPowerOfTwo(n)
	if n <= 0 then
		return 1
	end

	if bit.band(n, (n - 1)) == 0 then
		return n
	end

	local power = 1
	while power < n do
		power = power * 2
	end

	return power
end

function RagnarokGND:GenerateLightmapTextureImage()
	console.startTimer("Generate combined lightmap texture image")

	local width = 2048 -- TBD: Should use MAX_TEXTURE_DIMENSION?
	local numSlicesPerRow = 2048 / 8
	local numRows = math.ceil(self.lightmapFormat.numSlices / numSlicesPerRow)
	local height = nextPowerOfTwo(numRows * 8)

	printf("[RagnarokGND] Computed lightmap texture dimensions: %dx%d", width, height)
	local numBytesWritten = 0
	local rgbaImageBytes = buffer.new(width * height * 4)
	local bufferStartPointer, reservedlength = rgbaImageBytes:reserve(width * height * 4)
	for pixelV = 0, height - 1, 1 do
		local sliceV = math_floor(pixelV / 8)
		for pixelU = 0, width - 1, 1 do
			local sliceU = math_floor(pixelU / 8)
			local sliceID = sliceV * numSlicesPerRow + sliceU
			local offsetU = pixelU % 8
			local offsetV = pixelV % 8
			local lightmapStartIndex = (offsetU + offsetV * 8) * 3
			local shadowmapStartIndex = (offsetU + offsetV * 8)
			local writableAreaStartIndex = (pixelV * width + pixelU) * 4

			if sliceID < self.lightmapFormat.numSlices then
				local shadowmapTexels = self.lightmapSlices[sliceID].ambient_occlusion_texels
				local lightmapTexels = self.lightmapSlices[sliceID].baked_lightmap_texels
				local red = lightmapTexels[lightmapStartIndex + 0]
				local green = lightmapTexels[lightmapStartIndex + 1]
				local blue = lightmapTexels[lightmapStartIndex + 2]
				local alpha = shadowmapTexels[shadowmapStartIndex]
				bufferStartPointer[writableAreaStartIndex + 0] = red
				bufferStartPointer[writableAreaStartIndex + 1] = green
				bufferStartPointer[writableAreaStartIndex + 2] = blue
				bufferStartPointer[writableAreaStartIndex + 3] = alpha
			else -- Slightly wasteful, but the determinism enables testing (and it's barely noticeable anyway)
				bufferStartPointer[writableAreaStartIndex + 0] = 255
				bufferStartPointer[writableAreaStartIndex + 1] = 0
				bufferStartPointer[writableAreaStartIndex + 2] = 255
				bufferStartPointer[writableAreaStartIndex + 3] = 255
			end
			numBytesWritten = numBytesWritten + 4
		end
	end

	assert(numBytesWritten <= reservedlength, "Buffer overrun while writing lightmap pixels?")
	rgbaImageBytes:commit(numBytesWritten)

	local lightmapTextureImage = {
		rgbaImageBytes = rgbaImageBytes,
		width = width,
		height = height,
	}
	console.stopTimer("Generate combined lightmap texture image")

	return lightmapTextureImage
end

function RagnarokGND:ComputeLightmapTextureCoords(lightmapSliceID)
	local textureWidth = 2048 -- TBD: Should use MAX_TEXTURE_DIMENSION?
	local numSlicesPerRow = 2048 / 8
	local numRows = math.ceil(self.lightmapFormat.numSlices / numSlicesPerRow)
	local textureHeight = nextPowerOfTwo(numRows * 8)
	local sliceSize = 8

	local sliceU = lightmapSliceID % numSlicesPerRow
	local sliceV = math.floor(lightmapSliceID / numSlicesPerRow)

	local pixelOffsetU = 1 / textureWidth
	local pixelOffsetV = 1 / textureHeight

	local bottomLeftU = sliceU * sliceSize / textureWidth + pixelOffsetU
	local bottomLeftV = sliceV * sliceSize / textureHeight + pixelOffsetV

	local topRightU = (sliceU + 1) * sliceSize / textureWidth - pixelOffsetU
	local topRightV = (sliceV + 1) * sliceSize / textureHeight - pixelOffsetV

	return {
		bottomLeftU = bottomLeftU,
		bottomLeftV = bottomLeftV,
		bottomRightU = topRightU,
		bottomRightV = bottomLeftV,
		topLeftU = bottomLeftU,
		topLeftV = topRightV,
		topRightU = topRightU,
		topRightV = topRightV,
	}
end

ffi.cdef(RagnarokGND.cdefs)

return RagnarokGND
