local Mesh = require("Core.NativeClient.WebGPU.Mesh")
local Plane = require("Core.NativeClient.DebugDraw.Plane")
local NormalsVisualization = require("Core.NativeClient.DebugDraw.NormalsVisualization")
local WorldAxis = require("Core.NativeClient.DebugDraw.WorldAxis")

local worldAxesVisualizationMesh = WorldAxis()

local groundMesh = Plane({ dimensions = { x = 4, z = 4 }, translation = { x = 0, y = 0, z = 0 } })

local function createWallSurfaceEast()
	local wallEast = Mesh("WallEast")

	wallEast.vertexPositions = { 2, 0, -2, 2, 2, -2, 2, 2, 2, 2, 0, 2 }
	wallEast.triangleConnections = { 0, 1, 2, 0, 2, 3 }
	wallEast.vertexColors = { 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 }
	wallEast.surfaceNormals = { -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0 }
	wallEast.diffuseTextureCoords = { 0, 0, 0, 0, 0, 0, 0, 0 }

	return wallEast
end

local function createWallSurfaceNorth()
	local wallNorth = Mesh("WallNorth")

	wallNorth.vertexPositions = { -2, -2, -2, -2, 0, -2, 2, 0, -2, 2, -2, -2 }
	wallNorth.triangleConnections = { 0, 1, 2, 0, 2, 3 }
	wallNorth.vertexColors = { 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 }
	wallNorth.surfaceNormals = { 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1 }
	wallNorth.diffuseTextureCoords = { 0, 0, 0, 0, 0, 0, 0, 0 }

	return wallNorth
end

local wallEast = createWallSurfaceEast()
local normalsVisualizationEast = NormalsVisualization(wallEast)
local wallNorth = createWallSurfaceNorth()
local normalsVisualizationNorth = NormalsVisualization(wallNorth)

local scene = {
	displayName = "Visualization of Wall Surfaces",
	meshes = {
		worldAxesVisualizationMesh,
		groundMesh,
		wallEast,
		wallNorth,
		normalsVisualizationEast,
		normalsVisualizationNorth,
	},
}

return scene
