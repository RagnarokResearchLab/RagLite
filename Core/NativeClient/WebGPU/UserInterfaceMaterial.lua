local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.WidgetDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.InvisibleBaseMaterial")

local UserInterfaceMaterial = {
	pipeline = WidgetDrawingPipeline,
}

class("UserInterfaceMaterial", UserInterfaceMaterial)
extend(UserInterfaceMaterial, InvisibleBaseMaterial)

return UserInterfaceMaterial
