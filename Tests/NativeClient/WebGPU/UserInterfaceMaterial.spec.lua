local UserInterfaceMaterial = require("Core.NativeClient.WebGPU.UserInterfaceMaterial")

describe("UserInterfaceMaterial", function()
	it("should assign a human-readable display name for debugging purposes", function()
		assertEquals(UserInterfaceMaterial.displayName, "UserInterfaceMaterial")
	end)
end)
