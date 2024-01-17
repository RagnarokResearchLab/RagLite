local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.WidgetDrawingPipeline")

local UserInterfaceMaterial = {
	displayName = "UserInterfaceMaterial",
}

function UserInterfaceMaterial:Compile(graphicsContext)
	printf("Compiling material: %s", self.displayName)

	self.assignedRenderingPipeline =
		WidgetDrawingPipeline(graphicsContext.wgpuDevice, graphicsContext.wgpuSurface.preferredTextureFormat)
end

return UserInterfaceMaterial
