local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.WidgetDrawingPipeline")

local UserInterfaceMaterial = {
	displayName = "UserInterfaceMaterial",
}

function UserInterfaceMaterial:Compile(wgpuDevice, textureFormat)
	printf("Compiling material: %s", self.displayName)
	self.assignedRenderingPipeline = WidgetDrawingPipeline(wgpuDevice, textureFormat)
end

return UserInterfaceMaterial
