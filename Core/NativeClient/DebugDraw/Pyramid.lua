local Color = require("Core.NativeClient.DebugDraw.Color")
local Mesh = require("Core.NativeClient.WebGPU.Mesh")
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

	local pyramidMesh = Mesh("Pyramid")

	for faceIndex, face in ipairs(faceIndices) do
		local faceColor = faceColors[faceIndex]
		for _, vertexIndex in ipairs(face) do
			local vertex = cornerVertices[vertexIndex]
			tinsert(pyramidMesh.vertexPositions, vertex.x)
			tinsert(pyramidMesh.vertexPositions, vertex.y)
			tinsert(pyramidMesh.vertexPositions, vertex.z)

			tinsert(pyramidMesh.vertexColors, faceColor.red)
			tinsert(pyramidMesh.vertexColors, faceColor.green)
			tinsert(pyramidMesh.vertexColors, faceColor.blue)
		end

		local baseIndex = (#pyramidMesh.vertexPositions / 3) - #face
		if #face == 4 then -- Base of the pyramid
			tinsert(pyramidMesh.triangleConnections, baseIndex)
			tinsert(pyramidMesh.triangleConnections, baseIndex + 1)
			tinsert(pyramidMesh.triangleConnections, baseIndex + 2)
			tinsert(pyramidMesh.triangleConnections, baseIndex)
			tinsert(pyramidMesh.triangleConnections, baseIndex + 2)
			tinsert(pyramidMesh.triangleConnections, baseIndex + 3)
		else -- One of the sides
			tinsert(pyramidMesh.triangleConnections, baseIndex)
			tinsert(pyramidMesh.triangleConnections, baseIndex + 1)
			tinsert(pyramidMesh.triangleConnections, baseIndex + 2)
		end
	end

	for _ = 1, #pyramidMesh.vertexPositions / 3 do
		tinsert(pyramidMesh.diffuseTextureCoords, 0)
		tinsert(pyramidMesh.diffuseTextureCoords, 0)
	end

	return pyramidMesh
end

Pyramid.__call = Pyramid.Construct
setmetatable(Pyramid, Pyramid)

return Pyramid
