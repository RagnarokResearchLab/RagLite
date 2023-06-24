local ffi = require("ffi")
local glfw = require("glfw")

local NativeClient = require("Core.NativeClient.NativeClient")

describe("NativeClient", function()
	describe("CreateMainWindow", function()
		it("should create a windowed fullscreen window", function()
			local window = NativeClient:CreateMainWindow()

			assertEquals(type(window), "cdata")
			assertTrue(window ~= ffi.NULL)

			-- Not having an assigned monitor in GLFW means it's managed by the OS (i.e., windowed mode is ON)
			local assignedFullscreenMonitor = glfw.bindings.glfw_get_window_monitor(window)
			local hasWindowTakenControlOfDisplay = (assignedFullscreenMonitor ~= ffi.NULL)
			assertFalse(hasWindowTakenControlOfDisplay)
		end)
	end)
end)
