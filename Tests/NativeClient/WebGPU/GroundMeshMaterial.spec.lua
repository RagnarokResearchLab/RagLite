local GroundMeshMaterial = require("Core.NativeClient.WebGPU.GroundMeshMaterial")

describe("GroundMeshMaterial", function()
	it("should assign a human-readable display name for debugging purposes", function()
		assertEquals(GroundMeshMaterial.displayName, "GroundMeshMaterial")
	end)
end)
