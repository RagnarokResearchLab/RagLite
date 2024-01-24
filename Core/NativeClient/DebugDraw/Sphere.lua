local Mesh = require("Core.NativeClient.WebGPU.Mesh")

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

	local sphereMesh = Mesh("Sphere")

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

			tinsert(sphereMesh.vertexPositions, x + translation.x)
			tinsert(sphereMesh.vertexPositions, y + translation.y)
			tinsert(sphereMesh.vertexPositions, z + translation.z)

			local red = (sinTheta + 1) / 2
			local green = (sinPhi + 1) / 2
			local blue = (cosTheta + 1) / 2

			tinsert(sphereMesh.vertexColors, red)
			tinsert(sphereMesh.vertexColors, green)
			tinsert(sphereMesh.vertexColors, blue)
		end
	end

	for i = 0, stacks - 1 do
		for j = 0, slices - 1 do
			local first = (i * (slices + 1)) + j
			local second = first + slices + 1

			tinsert(sphereMesh.triangleConnections, first)
			tinsert(sphereMesh.triangleConnections, second)
			tinsert(sphereMesh.triangleConnections, first + 1)

			tinsert(sphereMesh.triangleConnections, second)
			tinsert(sphereMesh.triangleConnections, second + 1)
			tinsert(sphereMesh.triangleConnections, first + 1)
		end
	end

	for _ = 1, #sphereMesh.vertexPositions / 3 do
		tinsert(sphereMesh.diffuseTextureCoords, 0)
		tinsert(sphereMesh.diffuseTextureCoords, 0)
		tinsert(sphereMesh.surfaceNormals, 0)
		tinsert(sphereMesh.surfaceNormals, 1) -- Placeholder (uses unlit material, anyway)
		tinsert(sphereMesh.surfaceNormals, 0)
	end

	return sphereMesh
end

Sphere.__call = Sphere.Construct
setmetatable(Sphere, Sphere)

return Sphere
