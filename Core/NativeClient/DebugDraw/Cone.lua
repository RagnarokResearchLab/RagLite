local Color = require("Core.NativeClient.DebugDraw.Color")
local Mesh = require("Core.NativeClient.WebGPU.Mesh")

local MATH_PI = math.pi
local math_cos = math.cos
local math_sin = math.sin
local tinsert = table.insert

local Cone = {}

function Cone:Construct(creationOptions)
	creationOptions = creationOptions or {}
	local diameter = creationOptions.diameter or 1
	local height = creationOptions.height or 1
	local segments = creationOptions.resolution or 10
	local translation = creationOptions.translation or { x = 0, y = 0, z = 0 }

	local radius = diameter / 2

	local tipColor = Color.BLUE
	local baseColor = Color.RED

	local coneMesh = Mesh("Cone")

	local baseCenterIndex = #coneMesh.vertexPositions / 3
	tinsert(coneMesh.vertexPositions, 0 + translation.x)
	tinsert(coneMesh.vertexPositions, 0 + translation.y)
	tinsert(coneMesh.vertexPositions, 0 + translation.z)

	tinsert(coneMesh.vertexColors, baseColor.red)
	tinsert(coneMesh.vertexColors, baseColor.green)
	tinsert(coneMesh.vertexColors, baseColor.blue)

	for i = 0, segments - 1 do
		local angle = i * 2 * MATH_PI / segments
		local x = radius * math_cos(angle)
		local z = radius * math_sin(angle)

		tinsert(coneMesh.vertexPositions, x + translation.x)
		tinsert(coneMesh.vertexPositions, 0 + translation.y)
		tinsert(coneMesh.vertexPositions, z + translation.z)

		tinsert(coneMesh.vertexColors, baseColor.red)
		tinsert(coneMesh.vertexColors, baseColor.green)
		tinsert(coneMesh.vertexColors, baseColor.blue)

		local nextIndex = baseCenterIndex + ((i + 1) % segments) + 1
		tinsert(coneMesh.triangleConnections, baseCenterIndex)
		tinsert(coneMesh.triangleConnections, nextIndex)
		tinsert(coneMesh.triangleConnections, baseCenterIndex + i + 1)
	end

	local tipIndex = #coneMesh.vertexPositions / 3
	tinsert(coneMesh.vertexPositions, 0 + translation.x)
	tinsert(coneMesh.vertexPositions, height + translation.y)
	tinsert(coneMesh.vertexPositions, 0 + translation.z)

	tinsert(coneMesh.vertexColors, tipColor.red)
	tinsert(coneMesh.vertexColors, tipColor.green)
	tinsert(coneMesh.vertexColors, tipColor.blue)

	for i = 0, segments - 1 do
		local baseIndex = baseCenterIndex + i + 1
		local nextBaseIndex = baseCenterIndex + ((i + 1) % segments) + 1
		tinsert(coneMesh.triangleConnections, tipIndex)
		tinsert(coneMesh.triangleConnections, nextBaseIndex)
		tinsert(coneMesh.triangleConnections, baseIndex)
	end

	for _ = 1, #coneMesh.vertexPositions / 3 do
		tinsert(coneMesh.diffuseTextureCoords, 0)
		tinsert(coneMesh.diffuseTextureCoords, 0)
	end

	return coneMesh
end

Cone.__call = Cone.Construct
setmetatable(Cone, Cone)

return Cone
