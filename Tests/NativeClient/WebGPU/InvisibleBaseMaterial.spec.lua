local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local InvisibleBaseMaterial = require("Core.NativeClient.WebGPU.Materials.InvisibleBaseMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

local uuid = require("uuid")

VirtualGPU:Enable()

describe("InvisibleBaseMaterial", function()
	it("should use the default rendering pipeline configuration", function()
		assertEquals(InvisibleBaseMaterial.pipeline, BasicTriangleDrawingPipeline)
	end)

	describe("Construct", function()
		it("should store the given display name if one was provided", function()
			local material = InvisibleBaseMaterial("Test123")
			assertEquals(material.displayName, "Test123")
		end)

		it("should assign a unique ID to the returned material instance", function()
			local material = InvisibleBaseMaterial("Test123")
			local isUUID = uuid.isCanonical(material.uniqueID)
			assertTrue(isUUID)
		end)

		it("should use the unique ID as the display name if none was provided", function()
			local material = InvisibleBaseMaterial()
			assertEquals(material.displayName, material.uniqueID)
		end)
	end)

	describe("Compile", function()
		it("should instantiate and assign the default rendering pipeline to all material instances", function()
			local wgpuDevice = new("WGPUDevice") --  Doesn't have to be functional
			local textureFormat = 0 -- Doesn't matter here, either
			InvisibleBaseMaterial:Compile(wgpuDevice, textureFormat)

			local materialInstanceA = InvisibleBaseMaterial()
			local materialInstanceB = InvisibleBaseMaterial()
			assertEquals(materialInstanceA.surfaceRenderingPipeline, InvisibleBaseMaterial.surfaceRenderingPipeline)
			assertEquals(materialInstanceB.surfaceRenderingPipeline, InvisibleBaseMaterial.surfaceRenderingPipeline)

			assertTrue(instanceof(materialInstanceA.surfaceRenderingPipeline, BasicTriangleDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.surfaceRenderingPipeline, BasicTriangleDrawingPipeline))
		end)

		it("should instantiate and assign the default capture pipeline to all material instances", function()
			local wgpuDevice = new("WGPUDevice") --  Doesn't have to be functional
			local textureFormat = 0 -- Doesn't matter here, either
			InvisibleBaseMaterial:Compile(wgpuDevice, textureFormat)

			local materialInstanceA = InvisibleBaseMaterial()
			local materialInstanceB = InvisibleBaseMaterial()
			assertEquals(materialInstanceA.offlineRenderingPipeline, InvisibleBaseMaterial.offlineRenderingPipeline)
			assertEquals(materialInstanceB.offlineRenderingPipeline, InvisibleBaseMaterial.offlineRenderingPipeline)

			assertTrue(instanceof(materialInstanceA.offlineRenderingPipeline, BasicTriangleDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.offlineRenderingPipeline, BasicTriangleDrawingPipeline))
		end)
	end)
end)

VirtualGPU:Disable()
