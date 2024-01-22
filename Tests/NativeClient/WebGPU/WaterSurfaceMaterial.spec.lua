local WaterPlaneDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WaterPlaneDrawingPipeline")
local WaterSurfaceMaterial = require("Core.NativeClient.WebGPU.Materials.WaterSurfaceMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

local uuid = require("uuid")

VirtualGPU:Enable()

describe("WaterSurfaceMaterial", function()
	it("should use the default rendering pipeline configuration", function()
		assertEquals(WaterSurfaceMaterial.pipeline, WaterPlaneDrawingPipeline)
	end)

	describe("Construct", function()
		it("should store the given display name if one was provided", function()
			local material = WaterSurfaceMaterial("Test123")
			assertEquals(material.displayName, "Test123")
		end)

		it("should assign a unique ID to the returned material instance", function()
			local material = WaterSurfaceMaterial("Test123")
			local isUUID = uuid.isCanonical(material.uniqueID)
			assertTrue(isUUID)
		end)

		it("should use the unique ID as the display name if none was provided", function()
			local material = WaterSurfaceMaterial()
			assertEquals(material.displayName, material.uniqueID)
		end)
	end)

	describe("Compile", function()
		it("should instantiate and assign the default rendering pipeline to all material instances", function()
			local wgpuDevice = new("WGPUDevice") --  Doesn't have to be functional
			local textureFormat = 0 -- Doesn't matter here, either
			WaterSurfaceMaterial:Compile(wgpuDevice, textureFormat)

			local materialInstanceA = WaterSurfaceMaterial()
			local materialInstanceB = WaterSurfaceMaterial()
			assertEquals(materialInstanceA.assignedRenderingPipeline, WaterSurfaceMaterial.assignedRenderingPipeline)
			assertEquals(materialInstanceB.assignedRenderingPipeline, WaterSurfaceMaterial.assignedRenderingPipeline)

			assertTrue(instanceof(materialInstanceA.assignedRenderingPipeline, WaterPlaneDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.assignedRenderingPipeline, WaterPlaneDrawingPipeline))
		end)
	end)
end)

VirtualGPU:Disable()
