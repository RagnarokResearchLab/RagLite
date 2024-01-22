local Mesh = require("Core.NativeClient.WebGPU.Mesh")
local UnlitMeshMaterial = require("Core.NativeClient.WebGPU.Materials.UnlitMeshMaterial")

local uuid = require("uuid")

describe("Mesh", function()
	describe("Construct", function()
		it("should store the given display name if one was provided", function()
			local mesh = Mesh("Test123")
			assertEquals(mesh.displayName, "Test123")
		end)

		it("should assign a unique ID to the returned mesh instance", function()
			local mesh = Mesh("Test123")
			local isUUID = uuid.isCanonical(mesh.uniqueID)
			assertTrue(isUUID)
		end)

		it("should use the unique ID as the display name if none was provided", function()
			local mesh = Mesh()
			assertEquals(mesh.displayName, mesh.uniqueID)
		end)

		it("should create empty buffers for the geometry", function()
			local mesh = Mesh()
			assertEquals(mesh.vertexPositions, {})
			assertEquals(mesh.triangleConnections, {})
			assertEquals(mesh.vertexColors, {})
			assertEquals(mesh.diffuseTextureCoords, {})
		end)

		it("should assign a material that uses the default rendering pipeline", function()
			local mesh = Mesh()
			assertTrue(instanceof(mesh.material, UnlitMeshMaterial))
		end)

		it("should not register any animations with the rendering system", function()
			local mesh = Mesh()
			assertEquals(mesh.keyframeAnimations, {})
		end)

		it("should create a hook for delta time updates", function()
			-- Should replace with a proper event system later
			local mesh = Mesh()
			assertEquals(type(mesh.OnUpdate), "function")
		end)
	end)

	describe("__tostring", function()
		it("should return a human-readable representation of the mesh geometry", function()
			local mesh = Mesh("Hello")
			local stringifiedMesh = mesh:__tostring()
			local meshInfo = {
				displayName = mesh.displayName,
				uniqueID = mesh.uniqueID,
			}
			local expectedRepresentation = debug.dump(meshInfo, { silent = true })
			assertEquals(stringifiedMesh, expectedRepresentation)
		end)
	end)
end)
