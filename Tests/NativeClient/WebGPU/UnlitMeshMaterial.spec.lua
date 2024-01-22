local BasicTriangleDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.BasicTriangleDrawingPipeline")
local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.Materials.UnlitMeshMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

local uuid = require("uuid")

VirtualGPU:Enable()

describe("UnlitMeshMaterial", function()
	it("should use the default rendering pipeline configuration", function()
		assertEquals(UnlitMeshMaterial.pipeline, BasicTriangleDrawingPipeline)
	end)

	describe("Construct", function()
		it("should store the given display name if one was provided", function()
			local material = UnlitMeshMaterial("Test123")
			assertEquals(material.displayName, "Test123")
		end)

		it("should assign a unique ID to the returned material instance", function()
			local material = UnlitMeshMaterial("Test123")
			local isUUID = uuid.isCanonical(material.uniqueID)
			assertTrue(isUUID)
		end)

		it("should use the unique ID as the display name if none was provided", function()
			local material = UnlitMeshMaterial()
			assertEquals(material.displayName, material.uniqueID)
		end)
	end)

	describe("Compile", function()
		it("should instantiate and assign the default rendering pipeline to all material instances", function()
			local wgpuDevice = new("WGPUDevice") --  Doesn't have to be functional
			local textureFormat = 0 -- Doesn't matter here, either
			UnlitMeshMaterial:Compile(wgpuDevice, textureFormat)

			local materialInstanceA = UnlitMeshMaterial()
			local materialInstanceB = UnlitMeshMaterial()
			assertEquals(materialInstanceA.assignedRenderingPipeline, UnlitMeshMaterial.assignedRenderingPipeline)
			assertEquals(materialInstanceB.assignedRenderingPipeline, UnlitMeshMaterial.assignedRenderingPipeline)

			assertTrue(instanceof(materialInstanceA.assignedRenderingPipeline, BasicTriangleDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.assignedRenderingPipeline, BasicTriangleDrawingPipeline))
		end)
	end)
end)

VirtualGPU:Disable()
