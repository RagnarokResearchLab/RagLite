local Box = require("Core.NativeClient.DebugDraw.Box")
local NormalsVisualization = require("Core.NativeClient.DebugDraw.NormalsVisualization")

local function table_fill(value, count)
	local filledTable = table.new(count, 0)
	for index = 1, count, 1 do
		filledTable[index] = value
	end
	return filledTable
end

describe("NormalsVisualization", function()
	describe("Construct", function()
		it("should return a new mesh that includes triangles aligned with all normals of the input mesh", function()
			local box = Box()
			local visualizationMesh = NormalsVisualization(box)

			assertEquals(visualizationMesh.displayName, "BoxNormalsVisualization")
			assertEquals(
				visualizationMesh.vertexPositions,
				require("Tests.Fixtures.Snapshots.normals-visualization-positions")
			)
			assertEquals(
				visualizationMesh.triangleConnections,
				require("Tests.Fixtures.Snapshots.normals-visualization-indices")
			)

			local expectedColors = {}
			for index = 1, #visualizationMesh.vertexPositions / 3, 1 do
				table.insert(expectedColors, NormalsVisualization.color.red)
				table.insert(expectedColors, NormalsVisualization.color.green)
				table.insert(expectedColors, NormalsVisualization.color.blue)
			end
			assertEquals(visualizationMesh.vertexColors, expectedColors)
			assertEquals(
				visualizationMesh.diffuseTextureCoords,
				table_fill(0, 2 * #visualizationMesh.vertexPositions / 3)
			)
			assertEquals(visualizationMesh.surfaceNormals, table_fill(0, 3 * #visualizationMesh.vertexPositions / 3))
		end)
	end)
end)
