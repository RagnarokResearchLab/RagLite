local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.Materials.UnlitMeshMaterial")

local uuid = require("uuid")

local Mesh = {}

function Mesh:Construct(name)
	local globallyUniqueID = uuid.createMersenneTwistedUUID() -- Might be overkill, but oh well...
	local instance = {
		displayName = name or globallyUniqueID,
		uniqueID = globallyUniqueID,
		vertexPositions = {},
		triangleConnections = {},
		vertexColors = {},
		diffuseTextureCoords = {},
		material = UnlitMeshMaterial(name and (name .. "Material") or globallyUniqueID),
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

Mesh.__call = Mesh.Construct
Mesh.__index = Mesh
setmetatable(Mesh, Mesh)

return Mesh
