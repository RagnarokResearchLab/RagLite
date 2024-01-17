local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WidgetDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")

local UserInterfaceMaterial = {
	pipeline = WidgetDrawingPipeline,
}

class("UserInterfaceMaterial", UserInterfaceMaterial)
extend(UserInterfaceMaterial, InvisibleBaseMaterial)

return UserInterfaceMaterial