local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local UnlitMeshMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
}

class("UnlitMeshMaterial", UnlitMeshMaterial)
extend(UnlitMeshMaterial, InvisibleBaseMaterial)

return UnlitMeshMaterial
