local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local GroundMeshMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
}

class("GroundMeshMaterial", GroundMeshMaterial)
extend(GroundMeshMaterial, InvisibleBaseMaterial)

return GroundMeshMaterial
