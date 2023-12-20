local Box = require("Core.NativeClient.DebugDraw.Box")
local Cone = require("Core.NativeClient.DebugDraw.Cone")
local Cylinder = require("Core.NativeClient.DebugDraw.Cylinder")
local Plane = require("Core.NativeClient.DebugDraw.Plane")
local Pyramid = require("Core.NativeClient.DebugDraw.Pyramid")
local Sphere = require("Core.NativeClient.DebugDraw.Sphere")
local WorldAxis = require("Core.NativeClient.DebugDraw.WorldAxis")

local oldPyramidMesh = Pyramid()
local worldAxesVisualizationMesh = WorldAxis()

local sphereMesh = Sphere({ resolution = 100, translation = { x = 5, y = 0, z = -5 } })
local cubeMesh = Box({ translation = { x = -5, y = 0, z = -5 } })
local cylinderMesh = Cylinder({ resolution = 100, translation = { x = -5, y = 0, z = 5 } })
local coneMesh = Cone({ resolution = 100, translation = { x = 5, y = 0, z = 5 } })
local pyramidMesh = Pyramid({ dimensions = { x = 1, y = 2, z = 1 }, translation = { x = -7.5, y = 0, z = 0 } })
local boxMesh = Box({ dimensions = { x = 1, y = 2, z = 1 }, translation = { x = 7.5, y = 0, z = 0 } })
local groundMesh = Plane({ dimensions = { x = 20, z = 20 }, translation = { x = 0, y = -2, z = 0 } })

local scene = {
	displayName = "Hello WebGPU (demo)",
	meshes = {
		oldPyramidMesh,
		worldAxesVisualizationMesh,
		sphereMesh,
		cubeMesh,
		cylinderMesh,
		coneMesh,
		pyramidMesh,
		boxMesh,
		groundMesh,
	},
}

return scene
