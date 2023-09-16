local Sphere = require("Core.NativeClient.DebugDraw.Sphere")

describe("Sphere", function()
	describe("Construct", function()
		it("should generate a unit sphere if no additional parameters were passed", function()
			local sphereGeometry = Sphere()

			local expectedPositions = require("Tests.Fixtures.Snapshots.unit-sphere-positions")
			local expectedIndices = require("Tests.Fixtures.Snapshots.unit-sphere-indices")

			for index, computedPosition in ipairs(sphereGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedPositions[index], 1E-3)
			end
			assertEquals(sphereGeometry.triangleConnections, expectedIndices)
		end)

		it("should generate a scaled sphere if non-unit diameter was passed", function()
			local creationOptions = { diameter = 5 }
			local sphereGeometry = Sphere(creationOptions)

			local expectedPositions = require("Tests.Fixtures.Snapshots.scaled-sphere-positions")
			local expectedIndices = require("Tests.Fixtures.Snapshots.scaled-sphere-indices")

			for index, computedPosition in ipairs(sphereGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedPositions[index], 1E-3)
			end
			assertEquals(sphereGeometry.triangleConnections, expectedIndices)
		end)

		it("should bake in the translation vector if a table value was passed", function()
			local creationOptions = { translation = { x = 1, y = 2, z = 3 } }
			local sphereGeometry = Sphere(creationOptions)

			local expectedPositions = require("Tests.Fixtures.Snapshots.translated-sphere-positions")
			local expectedIndices = require("Tests.Fixtures.Snapshots.translated-sphere-indices")

			for index, computedPosition in ipairs(sphereGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedPositions[index], 1E-3)
			end
			assertEquals(sphereGeometry.triangleConnections, expectedIndices)
		end)

		it("should adjust the number of approximated segments if a resolution was passed", function()
			local creationOptions = { resolution = 3 }
			local sphereGeometry = Sphere(creationOptions)

			local expectedPositions = require("Tests.Fixtures.Snapshots.lowres-sphere-positions")
			local expectedIndices = require("Tests.Fixtures.Snapshots.lowres-sphere-indices")

			for index, computedPosition in ipairs(sphereGeometry.vertexPositions) do
				assertEqualNumbers(computedPosition, expectedPositions[index], 1E-3)
			end
			assertEquals(sphereGeometry.triangleConnections, expectedIndices)
		end)
	end)
end)
