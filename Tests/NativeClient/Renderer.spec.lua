local etrace = require("Core.RuntimeExtensions.etrace")
local ffi = require("ffi")

local Renderer = require("Core.NativeClient.Renderer")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

describe("Renderer", function()
	-- The renderer wasn't designed to be testable, so a few hacks are currently required...
	Renderer.wgpuDevice = ffi.new("WGPUDevice")

	before(function()
		VirtualGPU:Enable()
		etrace.enable("GPU_TEXTURE_WRITE")
	end)

	after(function()
		etrace.disable("GPU_TEXTURE_WRITE")
		VirtualGPU:Disable()
	end)

	describe("CreateTextureImage", function()
		it("should upload the image data to the GPU", function()
			local rgbaImageBytes, width, height = string.rep("\255\0\0\255", 256 * 256), 256, 256

			Renderer:CreateTextureImage(rgbaImageBytes, width, height)

			local events = etrace.filter("GPU_TEXTURE_WRITE")
			local payload = events[1].payload

			assertEquals(events[1].name, "GPU_TEXTURE_WRITE")
			assertEquals(payload.dataSize, width * height * 4)
			assertEquals(payload.writeSize.width, width)
			assertEquals(payload.writeSize.height, height)
			assertEquals(payload.writeSize.depthOrArrayLayers, 1)

			assertEquals(#payload.data, #rgbaImageBytes) -- More readable errors in case of failure
			assertEquals(payload.data, rgbaImageBytes)

			assertEquals(tonumber(events[1].payload.dataLayout.offset), 0)
			assertEquals(tonumber(events[1].payload.dataLayout.bytesPerRow), width * 4)
			assertEquals(tonumber(events[1].payload.dataLayout.rowsPerImage), height)
		end)
	end)
end)
