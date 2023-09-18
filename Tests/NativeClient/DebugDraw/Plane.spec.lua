local Plane = require("Core.NativeClient.DebugDraw.Plane")

describe("Plane", function()
	describe("Construct", function()
		it("should generate a unit plane if no additional parameters were passed", function()
			local planeGeometry = Plane()
			assertEquals(planeGeometry.vertexPositions, { -0.5, 0, -0.5, 0.5, 0, -0.5, 0.5, 0, 0.5, -0.5, 0, 0.5 })
			assertEquals(planeGeometry.triangleConnections, { 0, 1, 2, 2, 3, 0 })
		end)

		it("should generate a rectangular plane if non-unit dimensions were passed", function()
			local creationOptions = {
				dimensions = { x = 2, z = 3 },
			}
			local planeGeometry = Plane(creationOptions)
			assertEquals(planeGeometry.vertexPositions, { -1, 0, -1.5, 1, 0, -1.5, 1, 0, 1.5, -1, 0, 1.5 })
			assertEquals(planeGeometry.triangleConnections, { 0, 1, 2, 2, 3, 0 })
		end)

		it("should bake in the translation vector if a table value was passed", function()
			local creationOptions = {
				translation = { x = 1, y = 2, z = 3 },
			}
			local planeGeometry = Plane(creationOptions)
			assertEquals(planeGeometry.vertexPositions, { 0.5, 2, 2.5, 1.5, 2, 2.5, 1.5, 2, 3.5, 0.5, 2, 3.5 })
			assertEquals(planeGeometry.triangleConnections, { 0, 1, 2, 2, 3, 0 })
		end)

		it("should generate a set of diffuse texture coordinates", function()
			local planeGeometry = Plane()
			local expectedTextureCoords = { 0, 1, 1, 1, 1, 0, 0, 0 }
			assertEquals(planeGeometry.diffuseTextureCoords, expectedTextureCoords)
		end)
	end)
end)
