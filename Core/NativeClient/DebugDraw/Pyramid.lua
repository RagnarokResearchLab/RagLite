local Color = require("Core.NativeClient.DebugDraw.Color")
local Vector3D = require("Core.VectorMath.Vector3D")

local ipairs = ipairs
local tinsert = table.insert

local Pyramid = {}

function Pyramid:Construct(creationOptions)
	creationOptions = creationOptions or {}
	local dimensions = creationOptions.dimensions or { x = 1, y = 1, z = 1 }
	local translation = creationOptions.translation or { x = 0, y = 0, z = 0 }

	local halfWidth = dimensions.x / 2
	local halfDepth = dimensions.z / 2

	local cornerVertices = {
		Vector3D(-halfWidth + translation.x, translation.y, -halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, translation.y, -halfDepth + translation.z),
		Vector3D(halfWidth + translation.x, translation.y, halfDepth + translation.z),
		Vector3D(-halfWidth + translation.x, translation.y, halfDepth + translation.z),
		Vector3D(translation.x, dimensions.y + translation.y, translation.z),
	}

	local faceColors = {
		Color.RED,
		Color.GREEN,
		Color.BLUE,
		Color.YELLOW,
		Color.MAGENTA,
	}

	local faceIndices = {
		{ 1, 2, 5 }, -- Front
		{ 3, 4, 5 }, -- Back
		{ 2, 3, 5 }, -- Right
		{ 4, 1, 5 }, -- Left
		{ 1, 2, 3, 4 }, -- Base
	}

	local vertexPositions = {}
	local vertexColors = {}
	local vertexIndices = {}

	for faceIndex, face in ipairs(faceIndices) do
		local faceColor = faceColors[faceIndex]
		for _, vertexIndex in ipairs(face) do
			local vertex = cornerVertices[vertexIndex]
			tinsert(vertexPositions, vertex.x)
			tinsert(vertexPositions, vertex.y)
			tinsert(vertexPositions, vertex.z)

			tinsert(vertexColors, faceColor.red)
			tinsert(vertexColors, faceColor.green)
			tinsert(vertexColors, faceColor.blue)
		end

		local baseIndex = (#vertexPositions / 3) - #face
		if #face == 4 then -- Base of the pyramid
			tinsert(vertexIndices, baseIndex)
			tinsert(vertexIndices, baseIndex + 1)
			tinsert(vertexIndices, baseIndex + 2)
			tinsert(vertexIndices, baseIndex)
			tinsert(vertexIndices, baseIndex + 2)
			tinsert(vertexIndices, baseIndex + 3)
		else -- One of the sides
			tinsert(vertexIndices, baseIndex)
			tinsert(vertexIndices, baseIndex + 1)
			tinsert(vertexIndices, baseIndex + 2)
		end
	end

	local mesh = {
		vertexPositions = vertexPositions,
		vertexColors = vertexColors,
		triangleConnections = vertexIndices,
	}

	return mesh
end

Pyramid.__call = Pyramid.Construct
setmetatable(Pyramid, Pyramid)

return Pyramid
