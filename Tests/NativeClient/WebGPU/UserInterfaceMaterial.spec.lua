local WidgetDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.WidgetDrawingPipeline")
local UserInterfaceMaterial = require("Core.NativeClient.WebGPU.Materials.UserInterfaceMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

local uuid = require("uuid")

VirtualGPU:Enable()

describe("UserInterfaceMaterial", function()
	it("should use the UI rendering pipeline configuration", function()
		assertEquals(UserInterfaceMaterial.pipeline, WidgetDrawingPipeline)
	end)

	describe("Construct", function()
		it("should store the given display name if one was provided", function()
			local material = UserInterfaceMaterial("Test123")
			assertEquals(material.displayName, "Test123")
		end)

		it("should assign a unique ID to the returned material instance", function()
			local material = UserInterfaceMaterial("Test123")
			local isUUID = uuid.isCanonical(material.uniqueID)
			assertTrue(isUUID)
		end)

		it("should use the unique ID as the display name if none was provided", function()
			local material = UserInterfaceMaterial()
			assertEquals(material.displayName, material.uniqueID)
		end)
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
