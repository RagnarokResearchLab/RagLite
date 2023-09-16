local WorldAxis = {}

function WorldAxis:Construct()
	local ARROWHEAD_VERTEX_COUNT = 3
	local vertexPositions = {
		-- X-Axis Visualization
		0.0,
		0.0,
		0.0, -- Bottom-left
		2.0,
		0.0,
		0.0, -- Bottom-right
		2.0,
		0.05,
		0.0, -- Top-right
		0.0,
		0.05,
		0.0, -- Top-left
		2.0,
		0.1,
		0, -- Arrowhead.Top
		2.0,
		-0.05,
		0, -- Arrowhead.Bottm
		2.25,
		0.05 / 2,
		0, -- Arrowhead.Tip

		-- Y-Axis Visualization
		0.0,
		0.0,
		0.0, -- Bottom-left
		0.05,
		0.0,
		0.0, -- Bottom-right
		0.05,
		2.0,
		0.0, -- Top-right
		0.0,
		2.0,
		0.0, -- Top-left
		-0.05,
		2,
		0, -- Arrowhead.Top
		0.1,
		2,
		0, -- Arrowhead.Bottom
		0.05 / 2,
		2.25,
		0, -- Arrowhead.Tip

		-- Z-Axis Visualization
		0.0,
		0.0,
		0.0, -- Bottom-left
		0.0,
		0.0,
		2.0, -- Bottom-right
		0.0,
		0.05,
		2.0, -- Top-right
		0.0,
		0.05,
		0.0, -- Top-left
		0,
		0.1,
		2, -- Arrowhead.Top
		0,
		-0.05,
		2, -- Arrowhead.Bottom
		0,
		0.05 / 2,
		2.25, -- Arrowhead.Tip
	}

	local vertexColors = {
		-- X-Axis (Red)
		1.0,
		0.0,
		0.0, -- Bottom-left
		1.0,
		0.0,
		0.0, -- Bottom-right
		1.0,
		0.0,
		0.0, -- Top-right
		1.0,
		0.0,
		0.0, -- Top-left
		1.0,
		0,
		0,
		1.0,
		0,
		0,
		1.0,
		0,
		0,
		-- Arrowhead

		-- Y-Axis (Green)
		0.0,
		1.0,
		0.0, -- Bottom-left
		0.0,
		1.0,
		0.0, -- Bottom-right
		0.0,
		1.0,
		0.0, -- Top-right
		0.0,
		1.0,
		0.0, -- Top-left
		0,
		1.0,
		0,
		0,
		1.0,
		0,
		0,
		1.0,
		0,
		-- Arrowhead

		-- Z-Axis (Blue)
		0.0,
		0.0,
		1.0, -- Bottom-left
		0.0,
		0.0,
		1.0, -- Bottom-right
		0.0,
		0.0,
		1.0, -- Top-right
		0.0,
		0.0,
		1.0, -- Top-left
		0.0,
		0.0,
		1.0,
		0.0,
		0.0,
		1.0,
		0.0,
		0.0,
		1.0, -- Arrowhead
	}

	local vertexIndices = {
		-- X Axis
		0,
		1,
		2,
		0,
		2,
		3,
		3 + 1,
		3 + 2,
		3 + 3,

		-- Y Axis
		3 + 4,
		ARROWHEAD_VERTEX_COUNT + 5,
		ARROWHEAD_VERTEX_COUNT + 6,
		ARROWHEAD_VERTEX_COUNT + 4,
		ARROWHEAD_VERTEX_COUNT + 6,
		ARROWHEAD_VERTEX_COUNT + 7,
		ARROWHEAD_VERTEX_COUNT + 7 + 1,
		ARROWHEAD_VERTEX_COUNT + 7 + 2,
		ARROWHEAD_VERTEX_COUNT + 7 + 3,

		-- Z Axis
		3
			+ 3
			+ 8,
		2 * ARROWHEAD_VERTEX_COUNT + 9,
		2 * ARROWHEAD_VERTEX_COUNT + 10,
		2 * ARROWHEAD_VERTEX_COUNT + 8,
		2 * ARROWHEAD_VERTEX_COUNT + 10,
		2 * ARROWHEAD_VERTEX_COUNT + 11,
		2 * ARROWHEAD_VERTEX_COUNT + 12,
		2 * ARROWHEAD_VERTEX_COUNT + 13,
		2 * ARROWHEAD_VERTEX_COUNT + 14,
	}

	local mesh = {
		vertexPositions = vertexPositions,
		vertexColors = vertexColors,
		triangleConnections = vertexIndices,
	}

	return mesh
end

WorldAxis.__call = WorldAxis.Construct
setmetatable(WorldAxis, WorldAxis)

return WorldAxis
