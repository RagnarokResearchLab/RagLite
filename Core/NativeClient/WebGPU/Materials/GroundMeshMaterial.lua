local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local GroundMeshMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
	opacity = 1,
	diffuseColor = {
		red = 1,
		green = 1,
		blue = 1,
	},
}

function GroundMeshMaterial:Construct(...)
	return self.super.Construct(self, ...)
end

class("GroundMeshMaterial", GroundMeshMaterial)
extend(GroundMeshMaterial, InvisibleBaseMaterial)

return GroundMeshMaterial
