local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.UnlitMeshMaterial")

describe("UnlitMeshMaterial", function()
	it("should assign a human-readable display name for debugging purposes", function()
		assertEquals(UnlitMeshMaterial.displayName, "UnlitMeshMaterial")
	end)
end)
