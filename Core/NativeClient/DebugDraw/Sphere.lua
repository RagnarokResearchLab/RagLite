local math_cos = math.cos
local math_pi = math.pi
local math_sin = math.sin
local tinsert = table.insert

local Sphere = {}

function Sphere:Construct(creationOptions)
	creationOptions = creationOptions or {}
	local diameter = creationOptions.diameter or 1
	local segments = creationOptions.resolution or 10
	local translation = creationOptions.translation or { x = 0, y = 0, z = 0 }

	local radius = diameter / 2
	local stacks = segments
	local slices = segments

	local vertexPositions = {}
	local vertexColors = {}
	local vertexIndices = {}

	for i = 0, stacks do
		local theta = i * math_pi / stacks
		local sinTheta = math_sin(theta)
		local cosTheta = math_cos(theta)

		for j = 0, slices do
			local phi = j * 2 * math.pi / slices
			local sinPhi = math_sin(phi)
			local cosPhi = math_cos(phi)

			local x = radius * cosPhi * sinTheta
			local y = radius * cosTheta
			local z = radius * sinPhi * sinTheta

			tinsert(vertexPositions, x + translation.x)
			tinsert(vertexPositions, y + translation.y)
			tinsert(vertexPositions, z + translation.z)

			local red = (sinTheta + 1) / 2
			local green = (sinPhi + 1) / 2
			local blue = (cosTheta + 1) / 2

			tinsert(vertexColors, red)
			tinsert(vertexColors, green)
			tinsert(vertexColors, blue)
		end
	end

	for i = 0, stacks - 1 do
		for j = 0, slices - 1 do
			local first = (i * (slices + 1)) + j
			local second = first + slices + 1

			tinsert(vertexIndices, first)
			tinsert(vertexIndices, second)
			tinsert(vertexIndices, first + 1)

			tinsert(vertexIndices, second)
			tinsert(vertexIndices, second + 1)
			tinsert(vertexIndices, first + 1)
		end
	end

	local mesh = {
		vertexPositions = vertexPositions,
		triangleConnections = vertexIndices,
		vertexColors = vertexColors,
	}

	return mesh
end

Sphere.__call = Sphere.Construct
setmetatable(Sphere, Sphere)

return Sphere
