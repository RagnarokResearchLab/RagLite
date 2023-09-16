local Cone = require("Core.NativeClient.DebugDraw.Cone")

describe("Cone", function()
	describe("Construct", function()
		it("should generate a unit cone if no additional parameters were passed", function()
			local coneGeometry = Cone()

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.unit-cone-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.unit-cone-indices")

			for index, computedPosition in ipairs(coneGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedVertexPositions[index], 1E-3)
			end
			assertEquals(coneGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should generate a scaled cone if non-unit height or diameter was passed", function()
			local creationOptions = { height = 3, diameter = 5 }
			local coneGeometry = Cone(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.scaled-cone-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.scaled-cone-indices")

			for index, computedPosition in ipairs(coneGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedVertexPositions[index], 1E-3)
			end
			assertEquals(coneGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should bake in the translation vector if a table value was passed", function()
			local creationOptions = { translation = { x = 1, y = 2, z = 3 } }
			local coneGeometry = Cone(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.translated-cone-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.translated-cone-indices")

			for index, computedPosition in ipairs(coneGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedVertexPositions[index], 1E-3)
			end
			assertEquals(coneGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should adjust the number of approximated segments if a resolution was passed", function()
			local creationOptions = { resolution = 3 }
			local coneGeometry = Cone(creationOptions)

			local expectedPositions =
				{ 0, 0, 0, 0.5, 0, 0, -0.25, 0, 0.43301270189222, -0.25, 0, -0.43301270189222, 0, 1, 0 }
			for index, computedPosition in ipairs(coneGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedPositions[index], 1E-3)
			end

			local expectedIndices = { 0, 2, 1, 0, 3, 2, 0, 1, 3, 4, 2, 1, 4, 3, 2, 4, 1, 3 }
			assertEquals(coneGeometry.triangleConnections, expectedIndices)
		end)
	end)
end)
