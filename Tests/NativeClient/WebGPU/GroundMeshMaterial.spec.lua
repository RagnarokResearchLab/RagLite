local GroundMeshDrawingPipeline = require("Core.NativeClient.WebGPU.Pipelines.GroundMeshDrawingPipeline")
local GroundMeshMaterial = require("Core.NativeClient.WebGPU.Materials.GroundMeshMaterial")
local VirtualGPU = require("Core.NativeClient.WebGPU.VirtualGPU")

local uuid = require("uuid")

VirtualGPU:Enable()

describe("GroundMeshMaterial", function()
	it("should use a dedicated rendering pipeline configuration", function()
		assertEquals(GroundMeshMaterial.pipeline, GroundMeshDrawingPipeline)
	end)

	describe("Construct", function()
		it("should store the given display name if one was provided", function()
			local material = GroundMeshMaterial("Test123")
			assertEquals(material.displayName, "Test123")
		end)

		it("should assign a unique ID to the returned material instance", function()
			local material = GroundMeshMaterial("Test123")
			local isUUID = uuid.isCanonical(material.uniqueID)
			assertTrue(isUUID)
		end)

		it("should use the unique ID as the display name if none was provided", function()
			local material = GroundMeshMaterial()
			assertEquals(material.displayName, material.uniqueID)
		end)
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

			assertTrue(instanceof(materialInstanceA.assignedRenderingPipeline, GroundMeshDrawingPipeline))
			assertTrue(instanceof(materialInstanceB.assignedRenderingPipeline, GroundMeshDrawingPipeline))
		end)
	end)
end)

VirtualGPU:Disable()
