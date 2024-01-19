local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.InvisibleBaseMaterial")

local GroundMeshMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
}

class("GroundMeshMaterial", GroundMeshMaterial)
extend(GroundMeshMaterial, InvisibleBaseMaterial)

return GroundMeshMaterial
