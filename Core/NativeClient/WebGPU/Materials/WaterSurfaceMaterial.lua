local WaterPlaneDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WaterPlaneDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local WaterSurfaceMaterial = {
	pipeline = WaterPlaneDrawingPipeline,
	opacity = 144 / 255, -- Source: Borf
}

class("WaterSurfaceMaterial", WaterSurfaceMaterial)
extend(WaterSurfaceMaterial, InvisibleBaseMaterial)

return WaterSurfaceMaterial
