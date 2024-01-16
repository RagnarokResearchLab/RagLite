local Color = require("Core.NativeClient.DebugDraw.Color")
local Mesh = require("Core.NativeClient.WebGPU.Mesh")

local math_cos = math.cos
local math_sin = math.sin
local tinsert = table.insert

local Cylinder = {}

function Cylinder:Construct(creationOptions)
	creationOptions = creationOptions or {}
	local diameter = creationOptions.diameter or 1
	local height = creationOptions.height or 1
	local segments = creationOptions.resolution or 10
	local translation = creationOptions.translation or { x = 0, y = 0, z = 0 }

	local radius = diameter / 2

	local mantleColor = Color.RED
	local baseColor = Color.YELLOW

	local cylinderMesh = Mesh("Cylinder")
	for i = 0, segments - 1 do
		local angle = i * 2 * math.pi / segments
		local x = radius * math_cos(angle)
		local z = radius * math_sin(angle)

		tinsert(cylinderMesh.vertexPositions, x + translation.x)
		tinsert(cylinderMesh.vertexPositions, height + translation.y)
		tinsert(cylinderMesh.vertexPositions, z + translation.z)

		tinsert(cylinderMesh.vertexPositions, x + translation.x)
		tinsert(cylinderMesh.vertexPositions, translation.y)
		tinsert(cylinderMesh.vertexPositions, z + translation.z)

		tinsert(cylinderMesh.vertexColors, mantleColor.red)
		tinsert(cylinderMesh.vertexColors, mantleColor.green)
		tinsert(cylinderMesh.vertexColors, mantleColor.blue)

		tinsert(cylinderMesh.vertexColors, mantleColor.red)
		tinsert(cylinderMesh.vertexColors, mantleColor.green)
		tinsert(cylinderMesh.vertexColors, mantleColor.blue)

		local baseIndex = i * 2
		local nextBaseIndex = (i + 1) % segments * 2

		tinsert(cylinderMesh.triangleConnections, baseIndex)
		tinsert(cylinderMesh.triangleConnections, nextBaseIndex)
		tinsert(cylinderMesh.triangleConnections, baseIndex + 1)

		tinsert(cylinderMesh.triangleConnections, nextBaseIndex)
		tinsert(cylinderMesh.triangleConnections, nextBaseIndex + 1)
		tinsert(cylinderMesh.triangleConnections, baseIndex + 1)
	end

	local centerTopIndex = #cylinderMesh.vertexPositions / 3
	tinsert(cylinderMesh.vertexPositions, 0 + translation.x)
	tinsert(cylinderMesh.vertexPositions, height + translation.y)
	tinsert(cylinderMesh.vertexPositions, 0 + translation.z)

	tinsert(cylinderMesh.vertexColors, baseColor.red)
	tinsert(cylinderMesh.vertexColors, baseColor.green)
	tinsert(cylinderMesh.vertexColors, baseColor.blue)

	local centerBottomIndex = #cylinderMesh.vertexPositions / 3
	tinsert(cylinderMesh.vertexPositions, 0 + translation.x)
	tinsert(cylinderMesh.vertexPositions, translation.y)
	tinsert(cylinderMesh.vertexPositions, 0 + translation.z)

	tinsert(cylinderMesh.vertexColors, baseColor.red)
	tinsert(cylinderMesh.vertexColors, baseColor.green)
	tinsert(cylinderMesh.vertexColors, baseColor.blue)

	for i = 0, segments - 1 do
		local baseIndex = i * 2
		local nextBaseIndex = (i + 1) % segments * 2

		tinsert(cylinderMesh.triangleConnections, centerTopIndex)
		tinsert(cylinderMesh.triangleConnections, nextBaseIndex)
		tinsert(cylinderMesh.triangleConnections, baseIndex)

		tinsert(cylinderMesh.triangleConnections, centerBottomIndex)
		tinsert(cylinderMesh.triangleConnections, baseIndex + 1)
		tinsert(cylinderMesh.triangleConnections, nextBaseIndex + 1)
	end

	for _ = 1, #cylinderMesh.vertexPositions / 3 do
		tinsert(cylinderMesh.diffuseTextureCoords, 0)
		tinsert(cylinderMesh.diffuseTextureCoords, 0)
	end

	return cylinderMesh
end

Cylinder.__call = Cylinder.Construct
setmetatable(Cylinder, Cylinder)

return Cylinder
