local Box = require("Core.NativeClient.DebugDraw.Box")

describe("Box", function()
	describe("Construct", function()
		it("should generate a unit cube if no additional parameters were passed", function()
			local boxGeometry = Box()

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.unit-cube-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.unit-cube-indices")

			assertEquals(boxGeometry.vertexPositions, expectedVertexPositions)
			assertEquals(boxGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should generate a scaled box if non-unit dimensions were passed", function()
			local creationOptions = { dimensions = { x = 4, y = 2, z = 3 } }
			local boxGeometry = Box(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.scaled-cube-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.scaled-cube-indices")

			assertEquals(boxGeometry.vertexPositions, expectedVertexPositions)
			assertEquals(boxGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should bake in the translation vector if a table value was passed", function()
			local creationOptions = { translation = { x = 1, y = 2, z = 3 } }
			local boxGeometry = Box(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.translated-cube-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.translated-cube-indices")

			assertEquals(boxGeometry.vertexPositions, expectedVertexPositions)
			assertEquals(boxGeometry.triangleConnections, expectedVertexIndices)
		end)
	end)
end)
