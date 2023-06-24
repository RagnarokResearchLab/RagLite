local ffi = require("ffi")
local glfw = require("glfw")

local Renderer = require("Core.NativeClient.Renderer")

describe("Renderer", function()
	describe("CreateGraphicsContext", function()
		it("should throw if no window has been provided", function()
			local function createWithoutWindow()
				Renderer:CreateGraphicsContext(nil)
			end

			local expectedErrorMessage =
				"Expected argument nativeWindowHandle to be a cdata value, but received a nil value instead"
			assertThrows(createWithoutWindow, expectedErrorMessage)
		end)

		it("should return a complete WebGPU rendering context for the given window", function()
			glfw.bindings.glfw_init()

			local GLFW_CLIENT_API = glfw.bindings.glfw_find_constant("GLFW_CLIENT_API")
			local GLFW_NO_API = glfw.bindings.glfw_find_constant("GLFW_NO_API")
			glfw.bindings.glfw_window_hint(GLFW_CLIENT_API, GLFW_NO_API)

			local window = glfw.bindings.glfw_create_window(640, 480, "WebGPU Test Window", nil, nil)
			local context = Renderer:CreateGraphicsContext(window)

			assertEquals(context.window, window)

			assertEquals(type(context.instance), "cdata")
			assertTrue(context.instance ~= ffi.NULL)

			assertEquals(type(context.instanceDescriptor), "cdata")
			assertTrue(context.instanceDescriptor ~= ffi.NULL)

			assertEquals(type(context.adapter), "cdata")
			assertTrue(context.adapter ~= ffi.NULL)

			assertEquals(type(context.device), "cdata")
			assertTrue(context.device ~= ffi.NULL)

			assertEquals(type(context.deviceDescriptor), "cdata")
			assertTrue(context.deviceDescriptor ~= ffi.NULL)

			assertEquals(type(context.swapChain), "cdata")
			assertTrue(context.swapChain ~= ffi.NULL)
		end)
	end)
end)
