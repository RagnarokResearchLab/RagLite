local Color = require("Core.NativeClient.DebugDraw.Color")
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

	local vertexPositions = {}
	local vertexColors = {}
	local vertexIndices = {}
	local diffuseTexCoords = {}

	for faceID, face in ipairs(faceIndices) do
		local faceColor = faceColors[faceID]
		for _, index in ipairs(face) do
			local vertex = cornerVertices[index]
			tinsert(vertexPositions, vertex.x)
			tinsert(vertexPositions, vertex.y)
			tinsert(vertexPositions, vertex.z)

			tinsert(vertexColors, faceColor.red)
			tinsert(vertexColors, faceColor.green)
			tinsert(vertexColors, faceColor.blue)
		end

		local baseIndex = (faceID - 1) * 4
		tinsert(vertexIndices, baseIndex)
		tinsert(vertexIndices, baseIndex + 1)
		tinsert(vertexIndices, baseIndex + 2)
		tinsert(vertexIndices, baseIndex)
		tinsert(vertexIndices, baseIndex + 2)
		tinsert(vertexIndices, baseIndex + 3)
	end

	for _ = 1, #vertexPositions / 3 do
		tinsert(diffuseTexCoords, 0)
		tinsert(diffuseTexCoords, 0)
	end

	local mesh = {
		vertexPositions = vertexPositions,
		vertexColors = vertexColors,
		triangleConnections = vertexIndices,
		diffuseTextureCoords = diffuseTexCoords,
	}

	return mesh
end

Box.__call = Box.Construct
setmetatable(Box, Box)

return Box
