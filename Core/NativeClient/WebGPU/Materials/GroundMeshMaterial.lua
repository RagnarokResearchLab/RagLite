local GroundMeshDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.GroundMeshDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local GroundMeshMaterial = {
	pipeline = GroundMeshDrawingPipeline,
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

function GroundMeshMaterial:AssignLightmapTexture(texture)
	-- It's probably safe to use the diffuse bind group layout here, at least for now?
	self.lightmapTextureBindGroup = self:CreateMaterialPropertiesBindGroup(texture)
	self.lightmapTexture = texture
end

class("GroundMeshMaterial", GroundMeshMaterial)
extend(GroundMeshMaterial, InvisibleBaseMaterial)

return GroundMeshMaterial
