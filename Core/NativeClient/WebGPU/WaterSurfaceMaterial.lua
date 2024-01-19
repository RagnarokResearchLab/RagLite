local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.InvisibleBaseMaterial")

local WaterSurfaceMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
}

class("WaterSurfaceMaterial", WaterSurfaceMaterial)
extend(WaterSurfaceMaterial, InvisibleBaseMaterial)

return WaterSurfaceMaterial
