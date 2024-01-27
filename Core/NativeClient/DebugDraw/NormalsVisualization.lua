local Mesh = require("Core.NativeClient.WebGPU.Mesh")

local table_insert = table.insert

local NormalsVisualization = {
	TRIANGLE_WIDTH = 0.1,
	TRIANGLE_LENGTH = 1,
	color = {
		red = 1,
		green = 0x7F / 255,
		blue = 1,
	},
}
function NormalsVisualization:Construct(mesh)
	local visualizationMesh = Mesh(mesh.displayName .. "NormalsVisualization")

	for index = 1, #mesh.surfaceNormals, 3 do
		local vertex = {
			x = mesh.vertexPositions[index + 0],
			y = mesh.vertexPositions[index + 1],
			z = mesh.vertexPositions[index + 2],
		}
		local surfaceNormal = {
			x = mesh.surfaceNormals[index + 0],
			y = mesh.surfaceNormals[index + 1],
			z = mesh.surfaceNormals[index + 2],
		}

		local nextAvailableVertexID = #visualizationMesh.vertexPositions / 3
		table_insert(visualizationMesh.vertexPositions, vertex.x)
		table_insert(visualizationMesh.vertexPositions, vertex.y)
		table_insert(visualizationMesh.vertexPositions, vertex.z)
		table_insert(visualizationMesh.vertexPositions, vertex.x + surfaceNormal.x * self.TRIANGLE_LENGTH)
		-- There's no ceilings, so all flat surfaces must be facing up (normal will have a positive Y component)
		table_insert(visualizationMesh.vertexPositions, vertex.y + surfaceNormal.y * self.TRIANGLE_LENGTH)
		table_insert(visualizationMesh.vertexPositions, vertex.z + surfaceNormal.z * self.TRIANGLE_LENGTH)
		table_insert(visualizationMesh.vertexPositions, vertex.x - self.TRIANGLE_WIDTH)
		table_insert(visualizationMesh.vertexPositions, vertex.y - self.TRIANGLE_WIDTH)
		table_insert(visualizationMesh.vertexPositions, vertex.z - self.TRIANGLE_WIDTH)

		for i = 1, 3, 1 do
			table_insert(visualizationMesh.vertexColors, self.color.red)
			table_insert(visualizationMesh.vertexColors, self.color.green)
			table_insert(visualizationMesh.vertexColors, self.color.blue)
		end

		table_insert(visualizationMesh.triangleConnections, nextAvailableVertexID)
		table_insert(visualizationMesh.triangleConnections, nextAvailableVertexID + 1)
		table_insert(visualizationMesh.triangleConnections, nextAvailableVertexID + 2)

		for i = 1, 3, 1 do
			table_insert(visualizationMesh.diffuseTextureCoords, 0)
			table_insert(visualizationMesh.diffuseTextureCoords, 0)
		end

		for i = 1, 3, 1 do
			-- Not used (material is unlit)
			table_insert(visualizationMesh.surfaceNormals, 0)
			table_insert(visualizationMesh.surfaceNormals, 0)
			table_insert(visualizationMesh.surfaceNormals, 0)
		end
	end

	return visualizationMesh
end

NormalsVisualization.__call = NormalsVisualization.Construct
NormalsVisualization.__index = NormalsVisualization
setmetatable(NormalsVisualization, NormalsVisualization)

return NormalsVisualization
