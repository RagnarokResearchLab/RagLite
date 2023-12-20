local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")

local table_insert = table.insert

local RagnarokMap = {
	MAP_DATABASE = require("DB.classic-maps"),
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

function RagnarokMap:FetchResourceByID(resourceID)
	if not self.fileSystem then
		error(RagnarokMap.ERROR_INVALID_FILE_SYSTEM, 0)
	end

	return self.fileSystem:Fetch(resourceID)
end

RagnarokMap.__call = RagnarokMap.Construct
setmetatable(RagnarokMap, RagnarokMap)

return RagnarokMap
