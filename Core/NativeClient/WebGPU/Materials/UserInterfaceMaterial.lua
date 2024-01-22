local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WidgetDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local UserInterfaceMaterial = {
	pipeline = WidgetDrawingPipeline,
	opacity = 1,
	diffuseColor = {
		red = 1,
		green = 1,
		blue = 1,
	},
}

function UserInterfaceMaterial:Construct(...)
	return self.super.Construct(self, ...)
end

class("UserInterfaceMaterial", UserInterfaceMaterial)
extend(UserInterfaceMaterial, InvisibleBaseMaterial)

return UserInterfaceMaterial
