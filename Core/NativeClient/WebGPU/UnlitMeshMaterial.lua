local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")

local UnlitMeshMaterial = {
	displayName = "UnlitMeshMaterial",
}

function UnlitMeshMaterial:Compile(wgpuDevice, textureFormat)
	printf("Compiling material: %s", self.displayName)
	self.assignedRenderingPipeline = BasicTriangleDrawingPipeline(wgpuDevice, textureFormat)
end

return UnlitMeshMaterial
