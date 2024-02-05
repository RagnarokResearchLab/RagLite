local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.Materials.UnlitMeshMaterial")

local uuid = require("uuid")

local Mesh = {
	MAX_BUFFER_COUNT_PER_MESH = 6, -- Positions, indices, colors, diffuse UVs, normals, lightmap UVs
}

function Mesh:Construct(name)
	local globallyUniqueID = uuid.createMersenneTwistedUUID() -- Might be overkill, but oh well...
	local instance = {
		displayName = name or globallyUniqueID,
		uniqueID = globallyUniqueID,
		vertexPositions = {},
		triangleConnections = {},
		vertexColors = {},
		diffuseTextureCoords = {},
		surfaceNormals = {},
		material = UnlitMeshMaterial(name and (name .. "Material") or globallyUniqueID),
		keyframeAnimations = {},
	}

	local inheritanceLookupMetatable = {
		__index = self,
	}
	setmetatable(instance, inheritanceLookupMetatable)

	return instance
end

function Mesh:__tostring()
	local meshInfo = {
		displayName = self.displayName,
		uniqueID = self.uniqueID,
	}

	return debug.dump(meshInfo, { silent = true })
end

-- Should replace with an event, once a proper event system is implemented
function Mesh:OnUpdate(deltaTimeInMilliseconds)
	-- NOOP by default (for performance reasons; the JIT will almost certainly optimize this out)
end

function Mesh:GetGeometryBufferSizes()
	return {
		vertexPositions = #self.vertexPositions,
		triangleConnections = #self.triangleConnections,
		vertexColors = #self.vertexColors,
		diffuseTextureCoords = #self.diffuseTextureCoords,
		surfaceNormals = #self.surfaceNormals,
		lightmapTextureCoords = rawget(self, "lightmapTextureCoords") and #self.lightmapTextureCoords or 0,
	}
end

class("Mesh", Mesh)

return Mesh
