local Vector3D = require("Core.VectorMath.Vector3D")

local ipairs = ipairs
local tinsert = table.insert

local Plane = {}

function Plane:Construct(creationOptions)
	creationOptions = creationOptions or {}
	local dimensions = creationOptions.dimensions or { x = 1, y = 1, z = 1 }
	local translation = creationOptions.translation or { x = 0, y = 0, z = 0 }

	local halfWidth = dimensions.x / 2.0
	local halfDepth = dimensions.z / 2.0

	local cornerVertices = {
		Vector3D(-halfWidth + translation.x, 0 + translation.y, -halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, 0 + translation.y, -halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, 0 + translation.y, halfDepth + translation.z),
		Vector3D(-halfWidth + translation.x, 0 + translation.y, halfDepth + translation.z),
	}

	local normalizedDiffuseTextureCoords = {
		{ 0, 0 }, -- Bottom-left
		{ 1, 0 }, -- Bottom-right
		{ 1, 1 }, -- Top-right
		{ 0, 1 }, -- Top-left
	}

	local faceColor = { red = 0.5, green = 0.5, blue = 0.5 }

	local vertexPositions = {}
	local vertexColors = {}
	local vertexIndices = {}
	local diffuseTextureCoords = {}

	for index, vertex in ipairs(cornerVertices) do
		tinsert(vertexPositions, vertex.x)
		tinsert(vertexPositions, vertex.y)
		tinsert(vertexPositions, vertex.z)

		tinsert(vertexColors, faceColor.red)
		tinsert(vertexColors, faceColor.green)
		tinsert(vertexColors, faceColor.blue)

		-- WebGPU coordinates start at the top left, but I'd rather use normalized Uvs for everything
		local wgpuTextureCoordinate = {
			u = normalizedDiffuseTextureCoords[index][1],
			v = 1 - normalizedDiffuseTextureCoords[index][2],
		}
		tinsert(diffuseTextureCoords, wgpuTextureCoordinate.u)
		tinsert(diffuseTextureCoords, wgpuTextureCoordinate.v)
	end

	tinsert(vertexIndices, 0)
	tinsert(vertexIndices, 1)
	tinsert(vertexIndices, 2)

	tinsert(vertexIndices, 2)
	tinsert(vertexIndices, 3)
	tinsert(vertexIndices, 0)

	local mesh = {
		vertexPositions = vertexPositions,
		vertexColors = vertexColors,
		triangleConnections = vertexIndices,
		diffuseTextureCoords = diffuseTextureCoords,
	}

	return mesh
end

Plane.__call = Plane.Construct
setmetatable(Plane, Plane)

return Plane
