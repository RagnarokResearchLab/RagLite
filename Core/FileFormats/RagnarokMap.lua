local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")

local uv = require("uv")

local format = string.format
local table_insert = table.insert

local RagnarokMap = {
	MAP_DATABASE = require("DB.Maps"),
	ERROR_INVALID_MAP_ID = "No such entry exists in the map database",
	ERROR_INVALID_FILE_SYSTEM = "Cannot fetch resources without a registered file system handler",
}

function RagnarokMap:Construct(mapID, fileSystem)
	local mapInfo = RagnarokMap.MAP_DATABASE[mapID]
	if not mapInfo then
		return nil, RagnarokMap.ERROR_INVALID_MAP_ID
	end

	self.fileSystem = fileSystem

	local scene = {
		mapID = mapID,
		displayName = mapInfo and mapInfo.displayName or "Unknown",
		meshes = {},
	}

	local groundMeshSections = self:LoadTerrainGeometry(mapID)
	for sectionID, groundMeshSection in ipairs(groundMeshSections) do
		table_insert(scene.meshes, groundMeshSection)
	end

	local waterPlanes = self:LoadWaterSurface(mapID)
	for segmentID, waterPlane in ipairs(waterPlanes) do
		table_insert(scene.meshes, waterPlane.surfaceGeometry)
	end

	printf("[RagnarokMap] Entering world %s (%s)", mapID, scene.displayName)

	return scene
end

function RagnarokMap:LoadTerrainGeometry(mapID)
	local gnd = RagnarokGND()
	local gndName = mapID .. ".gnd"
	local gndBytes = self:FetchResourceByID(gndName)
	gnd:DecodeFileContents(gndBytes)

	local groundMeshSections = gnd:GenerateGroundMeshSections()
	for sectionID, groundMeshSection in pairs(groundMeshSections) do
		local texturePath = "texture/" .. gnd.diffuseTexturePaths[sectionID]
		local normalizedTextureImagePath = RagnarokGRF:DecodeFileName(texturePath)
		local textureImageBytes = self:FetchResourceByID(normalizedTextureImagePath)
		local rgbaImageBytes, width, height = C_ImageProcessing.DecodeFileContents(textureImageBytes)

		printf(
			"[RagnarokMap] Loading GND ground mesh section %d with diffuse texture %s (%d x %d)",
			sectionID,
			normalizedTextureImagePath,
			width,
			height
		)
		groundMeshSection.diffuseTexture = {
			rgbaImageBytes = rgbaImageBytes,
			width = width,
			height = height,
		}
	end

	return groundMeshSections
end

function RagnarokMap:LoadWaterSurface(mapID)
	-- Water planes may be defined by either RSW or GND file (depending on the version used)
	local gnd = RagnarokGND()
	local gndName = mapID .. ".gnd"
	local gndBytes = self:FetchResourceByID(gndName)
	gnd:DecodeFileContents(gndBytes)

	local rsw = RagnarokRSW()
	local rswName = mapID .. ".rsw"
	local rswBytes = self:FetchResourceByID(rswName)
	rsw:DecodeFileContents(rswBytes)

	local waterPlanes = (#gnd.waterPlanes > 0) and gnd.waterPlanes or rsw.waterPlanes
	printf(
		"[RagnarokMap] Loading water surface consisting of %d water plane(s) mapped to the %dx%d cube grid",
		#waterPlanes,
		gnd.gridSizeU,
		gnd.gridSizeV
	)

	for planeID, waterPlane in ipairs(waterPlanes) do
		local animationFrameID = 0 -- Texture animation is NYI (will have to update this later)
		local normalizedTextureImagePath =
			format("texture/워터/water%d%02d.jpg", waterPlane.textureTypePrefix, animationFrameID)

		local textureImageBytes = self:FetchResourceByID(normalizedTextureImagePath)
		local rgbaImageBytes, width, height = C_ImageProcessing.DecodeFileContents(textureImageBytes)

		printf(
			"[RagnarokMap] Loading water plane %d with diffuse texture %s (%d x %d)",
			planeID,
			normalizedTextureImagePath,
			width,
			height
		)
		waterPlane.surfaceGeometry.diffuseTexture = {
			rgbaImageBytes = rgbaImageBytes,
			width = width,
			height = height,
		}
	end

	local startTime = uv.hrtime()
	for waterPlaneID = 1, #waterPlanes, 1 do
		local waterPlane = waterPlanes[waterPlaneID]
		printf(
			"Generating geometry for water plane %d within grid coordinates (%d, %d) to (%d, %d)",
			waterPlaneID,
			waterPlane.surfaceRegion.minU,
			waterPlane.surfaceRegion.minV,
			waterPlane.surfaceRegion.maxU,
			waterPlane.surfaceRegion.maxV
		)
		waterPlane:AlignWithGroundMesh(gnd)
		for gridV = waterPlane.surfaceRegion.minV, waterPlane.surfaceRegion.maxV do
			for gridU = waterPlane.surfaceRegion.minU, waterPlane.surfaceRegion.maxU do
				waterPlane:GenerateWaterVertices(gnd, gridU, gridV)
			end
		end
	end

	local endTime = uv.hrtime()
	local geometryGenerationTimeInMilliseconds = (endTime - startTime) / 10E5
	printf(
		"[RagnarokMap] Finished generating surface geometry for %d water plane segment(s) in %.2f ms",
		#waterPlanes,
		geometryGenerationTimeInMilliseconds
	)

	return waterPlanes
end

function RagnarokMap:FetchResourceByID(resourceID)
	if not self.fileSystem then
		error(RagnarokMap.ERROR_INVALID_FILE_SYSTEM, 0)
	end

	return self.fileSystem:Fetch(resourceID)
end

RagnarokMap.__call = RagnarokMap.Construct
setmetatable(RagnarokMap, RagnarokMap)

return RagnarokMap
