local Pyramid = require("Core.NativeClient.DebugDraw.Pyramid")

describe("Pyramid", function()
	describe("Construct", function()
		it("should generate a unit pyramid if no additional parameters were passed", function()
			local pyramidGeometry = Pyramid()

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.unit-pyramid-positions")

			assertEquals(pyramidGeometry.vertexPositions, expectedVertexPositions)
			assertEquals(
				pyramidGeometry.triangleConnections,
				{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 12, 14, 15 }
			)
		end)

		it("should generate a scaled pyramid if non-unit dimensions were passed", function()
			local creationOptions = { dimensions = { x = 4, y = 2, z = 3 } }
			local pyramidGeometry = Pyramid(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.scaled-pyramid-positions")

			assertEquals(pyramidGeometry.vertexPositions, expectedVertexPositions)
			assertEquals(
				pyramidGeometry.triangleConnections,
				{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 12, 14, 15 }
			)
		end)

		it("should bake in the translation vector if a table value was passed", function()
			local creationOptions = { translation = { x = 1, y = 2, z = 3 } }
			local pyramidGeometry = Pyramid(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.translated-pyramid-positions")

			assertEquals(pyramidGeometry.vertexPositions, expectedVertexPositions)
			assertEquals(
				pyramidGeometry.triangleConnections,
				{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 12, 14, 15 }
			)
		end)
	end)
end)
