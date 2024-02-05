local Surface = require("Core.NativeClient.WebGPU.Surface")

local ffi = require("ffi")

describe("Surface", function()
	describe("ValidateTextureStatus", function()
		it("should throw if the texture status change can't be handled cleanly", function()
			assertThrows(function()
				Surface:ValidateTextureStatus(ffi.C.WGPUSurfaceGetCurrentTextureStatus_Force32)
			end, Surface.errorStrings.UNKNOWN_TEXTURE_STATUS)

			assertThrows(function()
				Surface:ValidateTextureStatus(ffi.C.WGPUSurfaceGetCurrentTextureStatus_DeviceLost)
			end, Surface.errorStrings.GPU_DEVICE_LOST)

			assertThrows(function()
				Surface:ValidateTextureStatus(ffi.C.WGPUSurfaceGetCurrentTextureStatus_OutOfMemory)
			end, Surface.errorStrings.GPU_MEMORY_EXHAUSTED)
		end)

		it("should fail if the status indicates that the surface needs to be reconfigured", function()
			assertFailure(function()
				return Surface:ValidateTextureStatus(ffi.C.WGPUSurfaceGetCurrentTextureStatus_Lost)
			end, Surface.errorStrings.BACKING_SURFACE_LOST)

			assertFailure(function()
				return Surface:ValidateTextureStatus(ffi.C.WGPUSurfaceGetCurrentTextureStatus_Outdated)
			end, Surface.errorStrings.BACKING_SURFACE_OUTDATED)

			assertFailure(function()
				return Surface:ValidateTextureStatus(ffi.C.WGPUSurfaceGetCurrentTextureStatus_Timeout)
			end, Surface.errorStrings.BACKING_SURFACE_TIMEOUT)
		end)

		it("should return true if the status indicates that the texture is ready to use", function()
			assertTrue(Surface:ValidateTextureStatus(ffi.C.WGPUSurfaceGetCurrentTextureStatus_Success))
		end)
	end)
end)
