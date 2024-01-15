local Mesh = require("Core.NativeClient.WebGPU.Mesh")

require("table.new")

local math_ceil = math.ceil
local math_min = math.min
local table_insert = table.insert

local AnimatedWaterPlane = {
	TEXTURE_ANIMATION_SPEED_IN_FRAMES_PER_SECOND = 60,
	NUM_FRAMES_PER_TEXTURE_ANIMATION = 32, -- Highest possible frame ID
	GEOMETRY_DEBUG_INSET = 0,
}
function AnimatedWaterPlane:Construct(tileSlotU, tileSlotV, surfaceProperties)
	surfaceProperties = surfaceProperties or {}

	local instance = {
		surfaceRegion = {
			tileSlotU = tileSlotU or 1,
			tileSlotV = tileSlotV or 1,
			minU = 0,
			minV = 0,
			maxU = 0,
			maxV = 0,
		},
		surfaceGeometry = Mesh(format("AnimatedWaterPlane%dx%d", tileSlotU or 1, tileSlotV or 1)),
		normalizedSeaLevel = surfaceProperties.normalizedSeaLevel or 0,
		textureTypePrefix = surfaceProperties.textureTypePrefix or 1,
		waveformAmplitudeScalingFactor = surfaceProperties.waveformAmplitudeScalingFactor or 1,
		waveformPhaseShiftInDegreesPerFrame = surfaceProperties.waveformPhaseShiftInDegreesPerFrame or 2,
		waveformFrequencyInDegrees = surfaceProperties.waveformFrequencyInDegrees or 50,
		textureDisplayDurationInFrames = surfaceProperties.textureDisplayDurationInFrames or 3,
	}

	-- These estimates need refinement (see https://github.com/RagnarokResearchLab/RagLite/issues/281)
	instance.surfaceGeometry.vertexPositions = table.new(75000, 0)
	instance.surfaceGeometry.triangleConnections = table.new(10000, 0)
	instance.surfaceGeometry.vertexColors = table.new(10000, 0)
	instance.surfaceGeometry.diffuseTextureCoords = table.new(10000, 0)

	setmetatable(instance, self)

	return instance
end

-- Normalizing timings serves to decouple animation speed from the actual frame rate
function AnimatedWaterPlane:GetTextureAnimationDuration(textureDisplayDurationInFrames)
	local framesPerAnimationCycle = textureDisplayDurationInFrames * self.NUM_FRAMES_PER_TEXTURE_ANIMATION
	local normalizedCycleTimeInSeconds = framesPerAnimationCycle / self.TEXTURE_ANIMATION_SPEED_IN_FRAMES_PER_SECOND
	local normalizedCycleTimeInMilliseconds = normalizedCycleTimeInSeconds * 1000
	return normalizedCycleTimeInMilliseconds
end

function AnimatedWaterPlane:GetExpectedTextureDimensions(textureTypeID)
	textureTypeID = textureTypeID or self.textureTypePrefix

	-- I guess one could query the texture dimensions here, but that seems excessively paranoid...
	if textureTypeID == 4 or textureTypeID == 6 then -- Lava (Classic or Renewal)
		return 256
	else
		return 128
	end
end

function AnimatedWaterPlane:AlignWithGroundMesh(gnd)
	local waterSegmentSizeU = math_ceil(gnd.gridSizeU / gnd.numWaterPlanesU)
	local waterSegmentSizeV = math_ceil(gnd.gridSizeV / gnd.numWaterPlanesV)

	self.surfaceRegion.minU = (self.surfaceRegion.tileSlotU - 1) * waterSegmentSizeU + 1
	self.surfaceRegion.minV = (self.surfaceRegion.tileSlotV - 1) * waterSegmentSizeV + 1
	self.surfaceRegion.maxU = (self.surfaceRegion.tileSlotU - 0) * waterSegmentSizeU + 1
	self.surfaceRegion.maxV = (self.surfaceRegion.tileSlotV - 0) * waterSegmentSizeV + 1

	-- Uneven tile sizes may lead to rounding errors accumulating enough to reach OOB coordinates
	self.surfaceRegion.maxU = math_min(self.surfaceRegion.maxU, gnd.gridSizeU)
	self.surfaceRegion.maxV = math_min(self.surfaceRegion.maxV, gnd.gridSizeV)
end

function AnimatedWaterPlane:GenerateWaterVertices(gnd, gridU, gridV)
	local cubeID, errorMessage = gnd:GridPositionToCubeID(gridU, gridV)
	if not cubeID then
		error(errorMessage, 0)
	end

	local cube = gnd.cubeGrid[cubeID]
	-- No point in rendering water where there's no terrain to begin with
	local hasGroundSurface = (cube.top_surface_id >= 0)
	if not hasGroundSurface then
		return
	end

	-- Can normalize on decode to save some redundant computations here? (Needs benchmarking = deferred)
	local normalizedTerrainAltitude = {
		southwest = -1 * cube.southwest_corner_altitude * gnd.NORMALIZING_SCALE_FACTOR,
		southeast = -1 * cube.southeast_corner_altitude * gnd.NORMALIZING_SCALE_FACTOR,
		northeast = -1 * cube.northeast_corner_altitude * gnd.NORMALIZING_SCALE_FACTOR,
		northwest = -1 * cube.northwest_corner_altitude * gnd.NORMALIZING_SCALE_FACTOR,
	}
	-- There's only three possible types of terrain: Underwater, above water, or partially submerged
	-- All corners above sea level: Water can't be seen from a regular camera position (looks glitched otherwise)
	-- No corner above sea level: Terrain is completely submerged, must render water (and the underwater terrain)
	-- One to three corners above sea level: Sloped terrain next to a body of water; must render here to look right
	local isCornerAboveSeaLevel = {
		southwest = (normalizedTerrainAltitude.southwest >= self.normalizedSeaLevel),
		southeast = (normalizedTerrainAltitude.southeast >= self.normalizedSeaLevel),
		northeast = (normalizedTerrainAltitude.northeast >= self.normalizedSeaLevel),
		northwest = (normalizedTerrainAltitude.northwest >= self.normalizedSeaLevel),
	}
	local isTerrainAboveSeaLevel = isCornerAboveSeaLevel.southwest
		and isCornerAboveSeaLevel.southeast
		and isCornerAboveSeaLevel.northeast
		and isCornerAboveSeaLevel.northwest

	-- Rendering water here would look wrong (if it's visible at all... otherwise, still a waste of resources)
	if isTerrainAboveSeaLevel then
		return
	end

	-- Can't this be eliminated if it's certain the function only gets valid grid positions? (Benchmark later)
	local isGridCoordinateWithinWaterPlane = (gridU >= self.surfaceRegion.minU and gridU < self.surfaceRegion.maxU)
		and (gridV >= self.surfaceRegion.minV and gridV < self.surfaceRegion.maxV)
	if not isGridCoordinateWithinWaterPlane then
		return
	end

	local mesh = self.surfaceGeometry
	local southWestCornerVertex = {
		x = (gridU - 1) * gnd.GAT_TILES_PER_GND_SURFACE,
		y = self.normalizedSeaLevel,
		z = (gridV - 1) * gnd.GAT_TILES_PER_GND_SURFACE,
	}
	local southEastCornerVertex = {
		x = gridU * gnd.GAT_TILES_PER_GND_SURFACE,
		y = self.normalizedSeaLevel,
		z = (gridV - 1) * gnd.GAT_TILES_PER_GND_SURFACE,
	}
	local northWestCornerVertex = {
		x = (gridU - 1) * gnd.GAT_TILES_PER_GND_SURFACE,
		y = self.normalizedSeaLevel,
		z = gridV * gnd.GAT_TILES_PER_GND_SURFACE,
	}
	local northEastCornerVertex = {
		x = gridU * gnd.GAT_TILES_PER_GND_SURFACE,
		y = self.normalizedSeaLevel,
		z = gridV * gnd.GAT_TILES_PER_GND_SURFACE,
	}

	local DEBUG_OFFSET = AnimatedWaterPlane.GEOMETRY_DEBUG_INSET
	southWestCornerVertex.x = southWestCornerVertex.x + DEBUG_OFFSET
	southWestCornerVertex.z = southWestCornerVertex.z + DEBUG_OFFSET
	southEastCornerVertex.x = southEastCornerVertex.x - DEBUG_OFFSET
	southEastCornerVertex.z = southEastCornerVertex.z + DEBUG_OFFSET
	northWestCornerVertex.x = northWestCornerVertex.x + DEBUG_OFFSET
	northWestCornerVertex.z = northWestCornerVertex.z - DEBUG_OFFSET
	northEastCornerVertex.x = northEastCornerVertex.x - DEBUG_OFFSET
	northEastCornerVertex.z = northEastCornerVertex.z - DEBUG_OFFSET

	local nextAvailableVertexID = #mesh.vertexPositions / 3
	table_insert(mesh.vertexPositions, southWestCornerVertex.x)
	table_insert(mesh.vertexPositions, southWestCornerVertex.y)
	table_insert(mesh.vertexPositions, southWestCornerVertex.z)
	table_insert(mesh.vertexPositions, southEastCornerVertex.x)
	table_insert(mesh.vertexPositions, southEastCornerVertex.y)
	table_insert(mesh.vertexPositions, southEastCornerVertex.z)
	table_insert(mesh.vertexPositions, northWestCornerVertex.x)
	table_insert(mesh.vertexPositions, northWestCornerVertex.y)
	table_insert(mesh.vertexPositions, northWestCornerVertex.z)
	table_insert(mesh.vertexPositions, northEastCornerVertex.x)
	table_insert(mesh.vertexPositions, northEastCornerVertex.y)
	table_insert(mesh.vertexPositions, northEastCornerVertex.z)

	table_insert(mesh.triangleConnections, nextAvailableVertexID)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 1)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 2)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 1)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 3)
	table_insert(mesh.triangleConnections, nextAvailableVertexID + 2)

	local surfaceColor = { red = 255 / 255, green = 255 / 255, blue = 255 / 255 }
	for i = 1, 4, 1 do
		table_insert(mesh.vertexColors, surfaceColor.red)
		table_insert(mesh.vertexColors, surfaceColor.green)
		table_insert(mesh.vertexColors, surfaceColor.blue)
	end

	local textureSizeInPixels = self:GetExpectedTextureDimensions()
	local surfaceSizeInPixels = gnd.TEXTURED_SURFACE_SIZE_IN_PIXELS

	local numTextureSlices = textureSizeInPixels / surfaceSizeInPixels
	local textureSliceU = (gridU - 1) % numTextureSlices + 1
	local textureSliceV = (gridV - 1) % numTextureSlices + 1
	local maxU = numTextureSlices
	local maxV = numTextureSlices

	local diffuseTextureCoords = self:ComputeNormalizedTextureCoordinates(textureSliceU, textureSliceV, maxU, maxV)
	for index, coordinate in ipairs(diffuseTextureCoords) do
		table_insert(mesh.diffuseTextureCoords, coordinate)
	end
end

function AnimatedWaterPlane:ComputeNormalizedTextureCoordinates(sliceU, sliceV, maxSliceU, maxSliceV)
	-- One of the various coordinate systems is inverted between DirectX and WebGPU (investigate later?)
	local dxTexCoords = {
		(sliceU - 1) / maxSliceU,
		(sliceV - 1) / maxSliceV,
		(sliceU - 0) / maxSliceU,
		(sliceV - 1) / maxSliceV,
		(sliceU - 1) / maxSliceU,
		(sliceV - 0) / maxSliceV,
		(sliceU - 0) / maxSliceU,
		(sliceV - 0) / maxSliceV,
	}

	local wgpuTexCoords = {
		dxTexCoords[1],
		1 - dxTexCoords[2],
		dxTexCoords[3],
		1 - dxTexCoords[4],
		dxTexCoords[5],
		1 - dxTexCoords[6],
		dxTexCoords[7],
		1 - dxTexCoords[8],
	}

	return wgpuTexCoords
end

AnimatedWaterPlane.__call = AnimatedWaterPlane.Construct
AnimatedWaterPlane.__index = AnimatedWaterPlane
setmetatable(AnimatedWaterPlane, AnimatedWaterPlane)

return AnimatedWaterPlane
