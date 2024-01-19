local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.InvisibleBaseMaterial")

local UnlitMeshMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
}

class("UnlitMeshMaterial", UnlitMeshMaterial)
extend(UnlitMeshMaterial, InvisibleBaseMaterial)

return UnlitMeshMaterial
