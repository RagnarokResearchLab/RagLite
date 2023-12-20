local Box = require("Core.NativeClient.DebugDraw.Box")
local Plane = require("Core.NativeClient.DebugDraw.Plane")
local WorldAxis = require("Core.NativeClient.DebugDraw.WorldAxis")

local worldAxesVisualizationMesh = WorldAxis()

local cubeMesh = Box({ translation = { x = 0, y = 0, z = 0 } })
local groundMesh = Plane({ dimensions = { x = 20, z = 20 }, translation = { x = 0, y = -2, z = 0 } })

local scene = {
	displayName = "Cube3D (demo)",
	meshes = {
		worldAxesVisualizationMesh,
		cubeMesh,
		groundMesh,
	},
}

return scene
