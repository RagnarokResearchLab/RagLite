local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local GroundMeshMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
	opacity = 1,
}

class("GroundMeshMaterial", GroundMeshMaterial)
extend(GroundMeshMaterial, InvisibleBaseMaterial)

return GroundMeshMaterial
