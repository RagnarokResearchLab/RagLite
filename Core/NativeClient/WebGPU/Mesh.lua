local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.Materials.UnlitMeshMaterial")

local uuid = require("uuid")

local Mesh = {
	NUM_BUFFERS_PER_MESH = 5, -- Positions, indices, colors, diffuse UVs, normals
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

	setmetatable(instance, self)

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

Mesh.__call = Mesh.Construct
Mesh.__index = Mesh
setmetatable(Mesh, Mesh)

return Mesh
