local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local UnlitMeshMaterial = {
	pipeline = BasicTriangleDrawingPipeline,
	opacity = 1,
	diffuseColor = {
		red = 1,
		green = 1,
		blue = 1,
	},
}

function UnlitMeshMaterial:Construct(...)
	return self.super.Construct(self, ...)
end

class("UnlitMeshMaterial", UnlitMeshMaterial)
extend(UnlitMeshMaterial, InvisibleBaseMaterial)

return UnlitMeshMaterial
