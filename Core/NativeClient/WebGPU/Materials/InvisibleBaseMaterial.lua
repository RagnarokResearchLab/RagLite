local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.BasicTriangleDrawingPipeline")

local uuid = require("uuid")

local InvisibleBaseMaterial = {
	-- No mesh is expected to actually use the material, but all others should default to this pipeline
	pipeline = BasicTriangleDrawingPipeline,
}

function InvisibleBaseMaterial:Construct(name)
	local globallyUniqueID = uuid.create()
	local instance = {
		displayName = name or globallyUniqueID,
		uniqueID = globallyUniqueID,
	}

	local inheritanceLookupMetatable = {
		__index = self,
	}
	setmetatable(instance, inheritanceLookupMetatable)

	return instance
end

function InvisibleBaseMaterial:Compile(wgpuDevice, textureFormat)
	printf("Compiling material: %s", classname(self))
	self.assignedRenderingPipeline = self.pipeline:Construct(wgpuDevice, textureFormat)
end

class("InvisibleBaseMaterial", InvisibleBaseMaterial)

return InvisibleBaseMaterial
