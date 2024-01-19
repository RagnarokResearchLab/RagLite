local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.WidgetDrawingPipeline")
local UserInterfaceMaterial = require("Core.NativeClient.WebGPU.Materials.UserInterfaceMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

VirtualGPU:Enable()

describe("UserInterfaceMaterial", function()
	it("should use the UI rendering pipeline configuration", function()
		assertEquals(UserInterfaceMaterial.pipeline, WidgetDrawingPipeline)
	end)

	describe("Compile", function()
		it("should instantiate and assign the UI rendering pipeline to all material instances", function()
			local wgpuDevice = new("WGPUDevice") --  Doesn't have to be functional
			local textureFormat = 0 -- Doesn't matter here, either
			UserInterfaceMaterial:Compile(wgpuDevice, textureFormat)

			local materialInstanceA = UserInterfaceMaterial()
			local materialInstanceB = UserInterfaceMaterial()
			assertEquals(materialInstanceA.assignedRenderingPipeline, UserInterfaceMaterial.assignedRenderingPipeline)
			assertEquals(materialInstanceB.assignedRenderingPipeline, UserInterfaceMaterial.assignedRenderingPipeline)

			assertTrue(instanceof(materialInstanceA.assignedRenderingPipeline, WidgetDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.assignedRenderingPipeline, WidgetDrawingPipeline))
		end)
	end)
end)

VirtualGPU:Disable()
