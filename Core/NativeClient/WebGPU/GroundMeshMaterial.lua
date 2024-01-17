local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")

local GroundMeshMaterial = {
	displayName = "GroundMeshMaterial",
}

function GroundMeshMaterial:Compile(wgpuDevice, textureFormat)
	printf("Compiling material: %s", self.displayName)
	self.assignedRenderingPipeline = BasicTriangleDrawingPipeline(wgpuDevice, textureFormat)
end

return GroundMeshMaterial
