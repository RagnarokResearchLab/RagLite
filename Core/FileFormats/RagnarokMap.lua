local AnimatedWaterPlane = require("Core.FileFormats.RSW.AnimatedWaterPlane")
local RagnarokGND = require("Core.FileFormats.RagnarokGND")
local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokRSW = require("Core.FileFormats.RagnarokRSW")

local C_Resources = require("Core.NativeClient.C_Resources")
local Texture = require("Core.NativeClient.WebGPU.Texture")

local NormalsVisualization = require("Core.NativeClient.DebugDraw.NormalsVisualization")

local uv = require("uv")

local format = string.format
local table_insert = table.insert

local RagnarokMap = {
	MAP_DATABASE = require("DB.Maps"),
	ERROR_INVALID_MAP_ID = "No such entry exists in the map database",
	ERROR_INVALID_FILE_SYSTEM = "Cannot fetch resources without a registered file system handler",
	DEBUG_TERRAIN_NORMALS = false,
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

	self:LoadResources(mapID)

	local groundMeshSections = self:LoadTerrainGeometry(mapID)
	for sectionID, groundMeshSection in ipairs(groundMeshSections) do
		table_insert(scene.meshes, groundMeshSection)
		if self.DEBUG_TERRAIN_NORMALS then
			local normalsVisualization = NormalsVisualization(groundMeshSection)
			table_insert(scene.meshes, normalsVisualization)
		end
	end

	local waterPlanes = self:LoadWaterSurface(mapID)
	for segmentID, waterPlane in ipairs(waterPlanes) do
		table_insert(scene.meshes, waterPlane.surfaceGeometry)
	end

	local ambient = {
		red = self.rsw.ambientLight.diffuseColor.red,
		green = self.rsw.ambientLight.diffuseColor.green,
		blue = self.rsw.ambientLight.diffuseColor.blue,
		intensity = 1,
	}
	scene.ambientLight = ambient

	local sun = {
		red = self.rsw.directionalLight.diffuseColor.red,
		green = self.rsw.directionalLight.diffuseColor.green,
		blue = self.rsw.directionalLight.diffuseColor.blue,
		intensity = 1,
		rayDirection = self.rsw.directionalLight.direction,
	}
	scene.directionalLight = sun

	-- Not really testable with how the resource management works currently; should improve later
	scene.fogParameters = C_Resources.PERSISTENT_RESOURCES["data/fogparametertable.txt"][mapID]

	printf("[RagnarokMap] Entering world %s (%s)", mapID, scene.displayName)

	return scene
end

function RagnarokMap:LoadResources(mapID)
	local rsw = RagnarokRSW()
	local rswName = mapID .. ".rsw"
	local rswBytes = self:FetchResourceByID(rswName)
	rsw:DecodeFileContents(rswBytes)

	local gnd = RagnarokGND()
	local gndName = mapID .. ".gnd"
	local gndBytes = self:FetchResourceByID(gndName)
	gnd:DecodeFileContents(gndBytes)

	self.rsw = rsw
	self.gnd = gnd
end

function RagnarokMap:LoadTerrainGeometry(mapID)
	local gnd = self.gnd

	-- GeometryCache:LoadJSON(key)
	local console = require("console")
	-- local json = require("json")
	-- GeometryCache:StoreJSON(key, value)
	-- Do not serialize if loaded from DB (pointless increase)
	-- local cacheEntry = json.prettier(preallocatedGeometryInfo) -- No need to do this, just dump as Lua or even binary?
	local geometryCachePath = path.join("Cache", "CGND")
	local geometryCacheFile = path.join(geometryCachePath, mapID .. ".cgnd")
	-- C_FileSystem.MakeDirectoryTree(geometryCachePath)

	local hasCacheEntry = C_FileSystem.Exists(geometryCacheFile)
	local groundMeshSections = not hasCacheEntry and gnd:GenerateGroundMeshSections() or gnd.groundMeshSections
	if hasCacheEntry then
		console.startTimer("Reading GeometryCache")
		-- Preallocate buffers to reduce loading times
		printf("Loading geometry cache entry for key %s", mapID)
		local binaryCacheEntry = C_FileSystem.ReadFile(geometryCacheFile)
		-- skip version for now
		local BinaryReader = require("Core.FileFormats.BinaryReader")
		local reader = BinaryReader(binaryCacheEntry)
		local numMeshes = reader:GetUnsignedInt32()
		local numVertexPositions = reader:GetUnsignedInt32()
		local numTriangleConnections = reader:GetUnsignedInt32()
		local numVertexColors = reader:GetUnsignedInt32()
		local numDiffuseTextureCoords = reader:GetUnsignedInt32()
		local numSurfaceNormals = reader:GetUnsignedInt32()
		local numLightmapTextureCoords = reader:GetUnsignedInt32()

		for index = 1, numMeshes, 1 do
			groundMeshSections[index].vertexPositions = reader:GetTypedArray("float", numVertexPositions)
			groundMeshSections[index].triangleConnections = reader:GetTypedArray("uint32_t", numTriangleConnections)
			groundMeshSections[index].vertexColors = reader:GetTypedArray("float", numVertexColors)
			groundMeshSections[index].diffuseTextureCoords = reader:GetTypedArray("float", numDiffuseTextureCoords)
			groundMeshSections[index].surfaceNormals = reader:GetTypedArray("float", numSurfaceNormals)
			groundMeshSections[index].lightmapTextureCoords = reader:GetTypedArray("float", numLightmapTextureCoords)
		end
		console.stopTimer("Reading GeometryCache")
	end

	local sharedLightmapTextureImage = gnd:GenerateLightmapTextureImage()
	for sectionID, groundMeshSection in pairs(groundMeshSections) do
		local texturePath = "texture/" .. gnd.diffuseTexturePaths[sectionID]
		local normalizedTextureImagePath = RagnarokGRF:DecodeFileName(texturePath)
		local textureImageBytes = self:FetchResourceByID(normalizedTextureImagePath)
		local rgbaImageBytes, width, height = C_ImageProcessing.DecodeFileContents(textureImageBytes)

		rgbaImageBytes, width, height = Texture:CreateReducedColorImage(rgbaImageBytes, width, height)

		printf(
			"[RagnarokMap] Loading GND ground mesh section %d with diffuse texture %s (%d x %d)",
			sectionID,
			normalizedTextureImagePath,
			width,
			height
		)
		groundMeshSection.diffuseTextureImage = {
			rgbaImageBytes = rgbaImageBytes,
			width = width,
			height = height,
		}

		-- Should only upload once and bind the same texture?
		groundMeshSection.lightmapTextureImage = sharedLightmapTextureImage
	end

	local preallocatedGeometryInfo = {}
	for index, section in ipairs(groundMeshSections) do
		table_insert(preallocatedGeometryInfo, {
			vertexPositions = section.vertexPositions,
			triangleConnections = section.triangleConnections,
			vertexColors = section.vertexColors,
			diffuseTextureCoords = section.diffuseTextureCoords,
			surfaceNormals = section.surfaceNormals,
			lightmapTextureCoords = section.lightmapTextureCoords,
		})
	end

	-- GeometryCache:LoadJSON(key)
	if not hasCacheEntry then
		console.startTimer("Updating GeometryCache")
		-- GeometryCache:StoreJSON(key, value)
		-- Do not serialize if loaded from DB (pointless increase)
		C_FileSystem.MakeDirectoryTree(geometryCachePath)

		-- local binaryCacheEntry = C_FileSystem.ReadFile(geometryCacheFile)
		-- skip version for now
		-- local BinaryReader = require("Core.FileFormats.BinaryReader")
		-- local reader = BinaryReader(binaryCacheEntry)
		local numMeshes = #gnd.groundMeshSections
		local ffi = require("ffi")
		-- skip versionand header (CGND = compiled GND, 4 bytes - version: major.minor.patch = 12 bytes)
		-- Actually, may want to reuse for water = RCMG = compiled mesh geometry
		-- local bufferSize = numMeshes * (numVertexPositions + numTriangleConnections + numVertexColors + numDiffuseTextureCoords+ numSurfaceNormals +numLightmapTextureCoords ) * 4 -- float32, uint32
		local cacheEntry = buffer.new() -- TBD precompute if it matters perf wise?
		cacheEntry:putcdata(ffi.new("uint32_t[1]", numMeshes), ffi.sizeof("uint32_t"))
		for index = 1, numMeshes, 1 do
			local section = gnd.groundMeshSections[index]
			local numVertexPositions = #section.vertexPositions
			local numTriangleConnections = #section.triangleConnections
			local numVertexColors = #section.vertexColors
			local numDiffuseTextureCoords = #section.diffuseTextureCoords
			local numSurfaceNormals = #section.surfaceNormals
			local numLightmapTextureCoords = #section.lightmapTextureCoords -- SKIP for water planes
			-- setmetatable(cachedGeometry, nil) -- Remove JSON object/array tag as it interferes with the class system
			-- local ffi = require("ffi")
			local vertexPositions = ffi.new("float[?]", numVertexPositions, section.vertexPositions)
			local triangleConnections = ffi.new("uint32_t[?]", numTriangleConnections, section.triangleConnections)
			local vertexColors = ffi.new("float[?]", numVertexColors, section.vertexColors)
			local diffuseTextureCoords = ffi.new("float[?]", numDiffuseTextureCoords, section.diffuseTextureCoords)
			local surfaceNormals = ffi.new("float[?]", numSurfaceNormals, section.surfaceNormals)
			local lightmapTextureCoords = ffi.new("float[?]", numLightmapTextureCoords, section.lightmapTextureCoords)

			cacheEntry:putcdata(vertexPositions, ffi.sizeof(vertexPositions))
			cacheEntry:putcdata(triangleConnections, ffi.sizeof(triangleConnections))
			cacheEntry:putcdata(vertexColors, ffi.sizeof(vertexColors))
			cacheEntry:putcdata(diffuseTextureCoords, ffi.sizeof(diffuseTextureCoords))
			cacheEntry:putcdata(surfaceNormals, ffi.sizeof(surfaceNormals))
			cacheEntry:putcdata(lightmapTextureCoords, ffi.sizeof(lightmapTextureCoords))
		end

		printf(
			"Writing GeometryCache entry for key %s: %s (%s)",
			mapID,
			geometryCacheFile,
			string.filesize(#cacheEntry)
		)
		C_FileSystem.WriteFile(geometryCacheFile, tostring(cacheEntry))
		console.stopTimer("Updating GeometryCache")
	end

	return groundMeshSections
end

function RagnarokMap:LoadWaterSurface(mapID)
	-- Water planes may be defined by either RSW or GND file (depending on the version used)
	local gnd = self.gnd
	local rsw = self.rsw

	local waterPlanes = (#gnd.waterPlanes > 0) and gnd.waterPlanes or rsw.waterPlanes
	printf(
		"[RagnarokMap] Loading water surface consisting of %d water plane(s) mapped to the %dx%d cube grid",
		#waterPlanes,
		gnd.gridSizeU,
		gnd.gridSizeV
	)

	for planeID, waterPlane in ipairs(waterPlanes) do
		waterPlane.surfaceGeometry.diffuseTextureImages = {}
		for animationFrameID = 0, AnimatedWaterPlane.NUM_FRAMES_PER_TEXTURE_ANIMATION - 1, 1 do
			local normalizedTextureImagePath =
				format("texture/워터/water%d%02d.jpg", waterPlane.textureTypePrefix, animationFrameID)

			local textureImageBytes = self:FetchResourceByID(normalizedTextureImagePath)
			local rgbaImageBytes, width, height = C_ImageProcessing.DecodeFileContents(textureImageBytes)
			table_insert(waterPlane.surfaceGeometry.diffuseTextureImages, {
				rgbaImageBytes = rgbaImageBytes,
				width = width,
				height = height,
			})
		end
		printf(
			"[RagnarokMap] Loading water plane %d with %d diffuse textures",
			planeID,
			#waterPlane.surfaceGeometry.diffuseTextureImages
		)
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

		if waterPlane:IsLavaTexture() then
			waterPlane.surfaceGeometry.material.diffuseColor.red = rsw.ambientLight.diffuseColor.red
			waterPlane.surfaceGeometry.material.diffuseColor.green = rsw.ambientLight.diffuseColor.green
			waterPlane.surfaceGeometry.material.diffuseColor.blue = rsw.ambientLight.diffuseColor.blue
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
