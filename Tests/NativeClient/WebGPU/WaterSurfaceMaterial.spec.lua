local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local WaterSurfaceMaterial = require("Core.NativeClient.WebGPU.Materials.WaterSurfaceMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

VirtualGPU:Enable()

describe("WaterSurfaceMaterial", function()
	it("should use the default rendering pipeline configuration", function()
		assertEquals(WaterSurfaceMaterial.pipeline, BasicTriangleDrawingPipeline)
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

			assertTrue(instanceof(materialInstanceA.assignedRenderingPipeline, BasicTriangleDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.assignedRenderingPipeline, BasicTriangleDrawingPipeline))
		end)
	end)
end)

VirtualGPU:Disable()
