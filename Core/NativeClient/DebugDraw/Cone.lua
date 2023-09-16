local Color = require("Core.NativeClient.DebugDraw.Color")

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

	local vertexPositions = {}
	local vertexColors = {}
	local vertexIndices = {}

	local baseCenterIndex = #vertexPositions / 3
	tinsert(vertexPositions, 0 + translation.x)
	tinsert(vertexPositions, 0 + translation.y)
	tinsert(vertexPositions, 0 + translation.z)

	tinsert(vertexColors, baseColor.red)
	tinsert(vertexColors, baseColor.green)
	tinsert(vertexColors, baseColor.blue)

	for i = 0, segments - 1 do
		local angle = i * 2 * MATH_PI / segments
		local x = radius * math_cos(angle)
		local z = radius * math_sin(angle)

		tinsert(vertexPositions, x + translation.x)
		tinsert(vertexPositions, 0 + translation.y)
		tinsert(vertexPositions, z + translation.z)

		tinsert(vertexColors, baseColor.red)
		tinsert(vertexColors, baseColor.green)
		tinsert(vertexColors, baseColor.blue)

		local nextIndex = baseCenterIndex + ((i + 1) % segments) + 1
		tinsert(vertexIndices, baseCenterIndex)
		tinsert(vertexIndices, nextIndex)
		tinsert(vertexIndices, baseCenterIndex + i + 1)
	end

	local tipIndex = #vertexPositions / 3
	tinsert(vertexPositions, 0 + translation.x)
	tinsert(vertexPositions, height + translation.y)
	tinsert(vertexPositions, 0 + translation.z)

	tinsert(vertexColors, tipColor.red)
	tinsert(vertexColors, tipColor.green)
	tinsert(vertexColors, tipColor.blue)

	for i = 0, segments - 1 do
		local baseIndex = baseCenterIndex + i + 1
		local nextBaseIndex = baseCenterIndex + ((i + 1) % segments) + 1
		tinsert(vertexIndices, tipIndex)
		tinsert(vertexIndices, nextBaseIndex)
		tinsert(vertexIndices, baseIndex)
	end

	local mesh = {
		vertexPositions = vertexPositions,
		vertexColors = vertexColors,
		triangleConnections = vertexIndices,
	}

	return mesh
end

Cone.__call = Cone.Construct
setmetatable(Cone, Cone)

return Cone
