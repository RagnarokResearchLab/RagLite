local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")

local WaterSurfaceMaterial = {
	displayName = "WaterSurfaceMaterial",
}

function WaterSurfaceMaterial:Compile(wgpuDevice, textureFormat)
	printf("Compiling material: %s", self.displayName)
	self.assignedRenderingPipeline = BasicTriangleDrawingPipeline(wgpuDevice, textureFormat)
end

return WaterSurfaceMaterial
