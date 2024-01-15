local Mesh = require("Core.NativeClient.WebGPU.Mesh")
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

	local planeMesh = Mesh("Plane")

	for index, vertex in ipairs(cornerVertices) do
		tinsert(planeMesh.vertexPositions, vertex.x)
		tinsert(planeMesh.vertexPositions, vertex.y)
		tinsert(planeMesh.vertexPositions, vertex.z)

		tinsert(planeMesh.vertexColors, faceColor.red)
		tinsert(planeMesh.vertexColors, faceColor.green)
		tinsert(planeMesh.vertexColors, faceColor.blue)

		-- WebGPU coordinates start at the top left, but I'd rather use normalized Uvs for everything
		local wgpuTextureCoordinate = {
			u = normalizedDiffuseTextureCoords[index][1],
			v = 1 - normalizedDiffuseTextureCoords[index][2],
		}
		tinsert(planeMesh.diffuseTextureCoords, wgpuTextureCoordinate.u)
		tinsert(planeMesh.diffuseTextureCoords, wgpuTextureCoordinate.v)
	end

	tinsert(planeMesh.triangleConnections, 0)
	tinsert(planeMesh.triangleConnections, 1)
	tinsert(planeMesh.triangleConnections, 2)

	tinsert(planeMesh.triangleConnections, 2)
	tinsert(planeMesh.triangleConnections, 3)
	tinsert(planeMesh.triangleConnections, 0)

	return planeMesh
end

Plane.__call = Plane.Construct
setmetatable(Plane, Plane)

return Plane
