local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local WaterSurfaceMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
}

class("WaterSurfaceMaterial", WaterSurfaceMaterial)
extend(WaterSurfaceMaterial, InvisibleBaseMaterial)

return WaterSurfaceMaterial
