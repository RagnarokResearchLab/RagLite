local Box = require("Core.NativeClient.DebugDraw.Box")
local Plane = require("Core.NativeClient.DebugDraw.Plane")
local WorldAxis = require("Core.NativeClient.DebugDraw.WorldAxis")

local worldAxesVisualizationMesh = WorldAxis()

local MAP_SIZE = 200
local groundMesh = Plane({ dimensions = { x = MAP_SIZE, z = MAP_SIZE }, translation = { x = 0, y = -2, z = 0 } })

local scene = {
	displayName = "Legion (demo)",
	meshes = {
		worldAxesVisualizationMesh,
		groundMesh,
	},
}

math.randomseed(os.clock())

local numInstancesToSpawn = 2500
for index = 1, numInstancesToSpawn, 1 do
	local randomOffset = {
		x = math.random(0, MAP_SIZE - 1) - MAP_SIZE / 2 + 1 / 2,
		y = 0,
		z = math.random(0, MAP_SIZE - 1) - MAP_SIZE / 2 + 1 / 2,
	}
	local cubeMesh = Box({ translation = randomOffset })
	table.insert(scene.meshes, cubeMesh)
end

return scene
