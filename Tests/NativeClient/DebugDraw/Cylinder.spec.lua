local Cylinder = require("Core.NativeClient.DebugDraw.Cylinder")

describe("Cylinder", function()
	describe("Construct", function()
		it("should generate a unit cylinder if no additional parameters were passed", function()
			local cylinderGeometry = Cylinder()

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.unit-cylinder-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.unit-cylinder-indices")

			for index, computedPosition in ipairs(cylinderGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedVertexPositions[index], 1E-3)
			end
			assertEquals(cylinderGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should generate a scaled cylinder if non-unit height or diameter was passed", function()
			local creationOptions = { height = 3, diameter = 5 }
			local cylinderGeometry = Cylinder(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.scaled-cylinder-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.scaled-cylinder-indices")

			for index, computedPosition in ipairs(cylinderGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedVertexPositions[index], 1E-3)
			end
			assertEquals(cylinderGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should bake in the translation vector if a table value was passed", function()
			local creationOptions = { translation = { x = 1, y = 2, z = 3 } }
			local cylinderGeometry = Cylinder(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.translated-cylinder-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.translated-cylinder-indices")

			for index, computedPosition in ipairs(cylinderGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedVertexPositions[index], 1E-3)
			end
			assertEquals(cylinderGeometry.triangleConnections, expectedVertexIndices)
		end)

		it("should adjust the number of approximated segments if a resolution was passed", function()
			local creationOptions = { resolution = 3 }
			local cylinderGeometry = Cylinder(creationOptions)

			local expectedVertexPositions = require("Tests.Fixtures.Snapshots.lowres-cylinder-positions")
			local expectedVertexIndices = require("Tests.Fixtures.Snapshots.lowres-cylinder-indices")

			for index, computedPosition in ipairs(cylinderGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedVertexPositions[index], 1E-3)
			end
			assertEquals(cylinderGeometry.triangleConnections, expectedVertexIndices)
		end)
	end)
end)
