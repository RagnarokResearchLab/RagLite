local WaterSurfaceMaterial = require("Core.NativeClient.WebGPU.WaterSurfaceMaterial")

describe("WaterSurfaceMaterial", function()
	it("should assign a human-readable display name for debugging purposes", function()
		assertEquals(WaterSurfaceMaterial.displayName, "WaterSurfaceMaterial")
	end)
end)
