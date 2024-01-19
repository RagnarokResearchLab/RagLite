local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local GroundMeshMaterial = require("Core.NativeClient.WebGPU.Materials.GroundMeshMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

VirtualGPU:Enable()

describe("GroundMeshMaterial", function()
	it("should use the default rendering pipeline configuration", function()
		assertEquals(GroundMeshMaterial.pipeline, BasicTriangleDrawingPipeline)
	end)

	describe("Compile", function()
		it("should instantiate and assign the default rendering pipeline to all material instances", function()
			local wgpuDevice = new("WGPUDevice") --  Doesn't have to be functional
			local textureFormat = 0 -- Doesn't matter here, either
			GroundMeshMaterial:Compile(wgpuDevice, textureFormat)

			local materialInstanceA = GroundMeshMaterial()
			local materialInstanceB = GroundMeshMaterial()
			assertEquals(materialInstanceA.assignedRenderingPipeline, GroundMeshMaterial.assignedRenderingPipeline)
			assertEquals(materialInstanceB.assignedRenderingPipeline, GroundMeshMaterial.assignedRenderingPipeline)

			assertTrue(instanceof(materialInstanceA.assignedRenderingPipeline, BasicTriangleDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.assignedRenderingPipeline, BasicTriangleDrawingPipeline))
		end)
	end)
end)

VirtualGPU:Disable()
