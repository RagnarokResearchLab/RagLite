local Color = require("Core.NativeClient.DebugDraw.Color")
local Mesh = require("Core.NativeClient.WebGPU.Mesh")
local Vector3D = require("Core.VectorMath.Vector3D")

local ipairs = ipairs
local tinsert = table.insert

local Box = {}

function Box:Construct(creationOptions)
	creationOptions = creationOptions or {}
	local dimensions = creationOptions.dimensions or { x = 1, y = 1, z = 1 }
	local translation = creationOptions.translation or { x = 0, y = 0, z = 0 }

	local halfWidth = dimensions.x / 2
	local halfHeight = dimensions.y / 2
	local halfDepth = dimensions.z / 2

	local cornerVertices = {
		Vector3D(-halfWidth + translation.x, -halfHeight + translation.y, -halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, -halfHeight + translation.y, -halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, halfHeight + translation.y, -halfDepth + translation.z),
		Vector3D(-halfWidth + translation.x, halfHeight + translation.y, -halfDepth + translation.z),
		Vector3D(-halfWidth + translation.x, -halfHeight + translation.y, halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, -halfHeight + translation.y, halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, halfHeight + translation.y, halfDepth + translation.z),
		Vector3D(-halfWidth + translation.x, halfHeight + translation.y, halfDepth + translation.z),
	}

	local faceNormals = {
		Vector3D(0, 0, -1), -- Front
		Vector3D(0, 0, 1), -- Back
		Vector3D(0, -1, 0), -- Bottom
		Vector3D(0, 1, 0), -- Top
		Vector3D(-1, 0, 0), -- Left
		Vector3D(1, 0, 0), -- Right
	}

	local faceColors = {
		Color.RED,
		Color.GREEN,
		Color.BLUE,
		Color.YELLOW,
		Color.MAGENTA,
		Color.CYAN,
	}

	local faceIndices = {
		{ 1, 2, 3, 4 }, -- Front
		{ 5, 6, 7, 8 }, -- Back
		{ 1, 2, 6, 5 }, -- Bottom
		{ 3, 4, 8, 7 }, -- Top
		{ 1, 4, 8, 5 }, -- Left
		{ 2, 3, 7, 6 }, -- Right
	}

	local boxMesh = Mesh("Box")

	for faceID, face in ipairs(faceIndices) do
		local faceColor = faceColors[faceID]
		local normal = faceNormals[faceID]
		for _, index in ipairs(face) do
			local vertex = cornerVertices[index]
			tinsert(boxMesh.vertexPositions, vertex.x)
			tinsert(boxMesh.vertexPositions, vertex.y)
			tinsert(boxMesh.vertexPositions, vertex.z)

			tinsert(boxMesh.vertexColors, faceColor.red)
			tinsert(boxMesh.vertexColors, faceColor.green)
			tinsert(boxMesh.vertexColors, faceColor.blue)

			tinsert(boxMesh.surfaceNormals, normal.x)
			tinsert(boxMesh.surfaceNormals, normal.y)
			tinsert(boxMesh.surfaceNormals, normal.z)
		end

		local baseIndex = (faceID - 1) * 4
		tinsert(boxMesh.triangleConnections, baseIndex)
		tinsert(boxMesh.triangleConnections, baseIndex + 1)
		tinsert(boxMesh.triangleConnections, baseIndex + 2)
		tinsert(boxMesh.triangleConnections, baseIndex)
		tinsert(boxMesh.triangleConnections, baseIndex + 2)
		tinsert(boxMesh.triangleConnections, baseIndex + 3)
	end

	for _ = 1, #boxMesh.vertexPositions / 3 do
		tinsert(boxMesh.diffuseTextureCoords, 0)
		tinsert(boxMesh.diffuseTextureCoords, 0)
	end

	return boxMesh
end

Box.__call = Box.Construct
setmetatable(Box, Box)

return Box
