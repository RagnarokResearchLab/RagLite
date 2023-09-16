local Color = require("Core.NativeClient.DebugDraw.Color")

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

	local vertexPositions = {}
	local vertexColors = {}
	local vertexIndices = {}

	for i = 0, segments - 1 do
		local angle = i * 2 * math.pi / segments
		local x = radius * math_cos(angle)
		local z = radius * math_sin(angle)

		tinsert(vertexPositions, x + translation.x)
		tinsert(vertexPositions, height + translation.y)
		tinsert(vertexPositions, z + translation.z)

		tinsert(vertexPositions, x + translation.x)
		tinsert(vertexPositions, translation.y)
		tinsert(vertexPositions, z + translation.z)

		tinsert(vertexColors, mantleColor.red)
		tinsert(vertexColors, mantleColor.green)
		tinsert(vertexColors, mantleColor.blue)

		tinsert(vertexColors, mantleColor.red)
		tinsert(vertexColors, mantleColor.green)
		tinsert(vertexColors, mantleColor.blue)

		local baseIndex = i * 2
		local nextBaseIndex = (i + 1) % segments * 2

		tinsert(vertexIndices, baseIndex)
		tinsert(vertexIndices, nextBaseIndex)
		tinsert(vertexIndices, baseIndex + 1)

		tinsert(vertexIndices, nextBaseIndex)
		tinsert(vertexIndices, nextBaseIndex + 1)
		tinsert(vertexIndices, baseIndex + 1)
	end

	local centerTopIndex = #vertexPositions / 3
	tinsert(vertexPositions, 0 + translation.x)
	tinsert(vertexPositions, height + translation.y)
	tinsert(vertexPositions, 0 + translation.z)

	tinsert(vertexColors, baseColor.red)
	tinsert(vertexColors, baseColor.green)
	tinsert(vertexColors, baseColor.blue)

	local centerBottomIndex = #vertexPositions / 3
	tinsert(vertexPositions, 0 + translation.x)
	tinsert(vertexPositions, translation.y)
	tinsert(vertexPositions, 0 + translation.z)

	tinsert(vertexColors, baseColor.red)
	tinsert(vertexColors, baseColor.green)
	tinsert(vertexColors, baseColor.blue)

	for i = 0, segments - 1 do
		local baseIndex = i * 2
		local nextBaseIndex = (i + 1) % segments * 2

		tinsert(vertexIndices, centerTopIndex)
		tinsert(vertexIndices, nextBaseIndex)
		tinsert(vertexIndices, baseIndex)

		tinsert(vertexIndices, centerBottomIndex)
		tinsert(vertexIndices, baseIndex + 1)
		tinsert(vertexIndices, nextBaseIndex + 1)
	end

	local mesh = {
		vertexPositions = vertexPositions,
		vertexColors = vertexColors,
		triangleConnections = vertexIndices,
	}

	return mesh
end

Cylinder.__call = Cylinder.Construct
setmetatable(Cylinder, Cylinder)

return Cylinder
