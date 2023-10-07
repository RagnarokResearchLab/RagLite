local ffi = require("ffi")

local RagnarokGND = require("Core.FileFormats.RagnarokGND")

local SIZEOF_FLOAT = ffi.sizeof("float")

local QuadTreeRange = {
	-- 4 quadrants per level ~> 4^5 (1024) objects = max. capacity/storage limit of the tree
	MAX_QUADTREE_RECURSION_DEPTH = 5,
}

function QuadTreeRange:Construct(reader, recursionDepth, normalize)
	recursionDepth = recursionDepth or 0

	local instance = {
		quadrants = {},
		axisAlignedBoundingBox = {},
		recursionDepth = recursionDepth,
		isLeafNode = (recursionDepth == self.MAX_QUADTREE_RECURSION_DEPTH),
	}

	instance.axisAlignedBoundingBox = {
		bottom = {
			x = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			y = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			z = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		},
		top = {
			x = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			y = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			z = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		},
		diameter = {
			x = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			y = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			z = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		},
		center = {
			x = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			y = -1 * reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
			z = reader:GetFloat() * RagnarokGND.NORMALIZING_SCALE_FACTOR,
		},
	}

	setmetatable(instance, self)

	if instance.isLeafNode then
		return instance
	end

	instance.quadrants.bottomLeft = QuadTreeRange(reader, recursionDepth + 1)
	instance.quadrants.bottomRight = QuadTreeRange(reader, recursionDepth + 1)
	instance.quadrants.topLeft = QuadTreeRange(reader, recursionDepth + 1)
	instance.quadrants.topRight = QuadTreeRange(reader, recursionDepth + 1)

	return instance
end

function QuadTreeRange:GetBinaryStorageSizePerLevel(recursionLevel)
	local numNodes = math.pow(4, recursionLevel)
	local requiredStorageSize = numNodes * 12 * SIZEOF_FLOAT
	return requiredStorageSize
end

function QuadTreeRange:GetBinaryStorageSize(maxRecursionDepth)
	maxRecursionDepth = maxRecursionDepth or self.MAX_QUADTREE_RECURSION_DEPTH
	local totalStorageSize = 0

	for recursionLevel = 0, maxRecursionDepth, 1 do
		local numNodes = math.pow(4, recursionLevel)
		local requiredStorageSize = numNodes * 12 * SIZEOF_FLOAT
		totalStorageSize = totalStorageSize + requiredStorageSize
		printf(
			"[QuadTreeRange] Level %d: %s - %s bytes (%s total)",
			recursionLevel,
			(numNodes ~= 1 and format("%d nodes", numNodes) or "1 node"),
			requiredStorageSize,
			totalStorageSize
		)
	end

	return totalStorageSize
end

local preallocatedFloatBuffer = ffi.new("float[1]")
function QuadTreeRange:RecursivelySerializeBoundingBoxes(outputBuffer)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.bottom.x
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.bottom.y
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.bottom.z
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)

	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.top.x
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.top.y
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.top.z
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)

	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.diameter.x
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.diameter.y
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.diameter.z
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)

	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.center.x
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.center.y
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)
	preallocatedFloatBuffer[0] = self.axisAlignedBoundingBox.center.z
	outputBuffer:putcdata(preallocatedFloatBuffer, SIZEOF_FLOAT)

	if self.isLeafNode then
		return
	end

	self.quadrants.bottomLeft:RecursivelySerializeBoundingBoxes(outputBuffer)
	self.quadrants.bottomRight:RecursivelySerializeBoundingBoxes(outputBuffer)
	self.quadrants.topLeft:RecursivelySerializeBoundingBoxes(outputBuffer)
	self.quadrants.topRight:RecursivelySerializeBoundingBoxes(outputBuffer)
end

function QuadTreeRange:ToString(indentLevel)
	indentLevel = indentLevel or 0
	local indent = string.rep("\t", indentLevel)

	-- Convert the current node's information into a string format
	local str = string.format(
		"%sAABB (max: {x = %.2f, y = %.2f, z = %.2f}, min: {x = %.2f, y = %.2f, z = %.2f})\n",
		indent,
		self.axisAlignedBoundingBox.bottom.x,
		self.axisAlignedBoundingBox.bottom.y,
		self.axisAlignedBoundingBox.bottom.z,
		self.axisAlignedBoundingBox.top.x,
		self.axisAlignedBoundingBox.top.y,
		self.axisAlignedBoundingBox.top.z
	)

	if not self.isLeafNode then
		str = str .. string.format("%sbottomLeft:\n%s", indent, self.quadrants.bottomLeft:ToString(indentLevel + 1))
		str = str .. string.format("%sbottomRight:\n%s", indent, self.quadrants.bottomRight:ToString(indentLevel + 1))
		str = str .. string.format("%stopLeft:\n%s", indent, self.quadrants.topLeft:ToString(indentLevel + 1))
		str = str .. string.format("%stopRight:\n%s", indent, self.quadrants.topRight:ToString(indentLevel + 1))
	end

	return str
end

function QuadTreeRange:ToGraphVizDot(maxDepth)
	local nodes = {}
	local edges = {}
	local currentDepth = 0
	maxDepth = maxDepth or 1

	local function nodeToDot(node, parentId, depth)
		if depth > maxDepth then
			return
		end

		local id = #nodes + 1
		local label = string.format(
			"AABB\nmax: (%.2f, %.2f, %.2f)\nmin: (%.2f, %.2f, %.2f)",
			node.axisAlignedBoundingBox.bottom.x,
			node.axisAlignedBoundingBox.bottom.y,
			node.axisAlignedBoundingBox.bottom.z,
			node.axisAlignedBoundingBox.top.x,
			node.axisAlignedBoundingBox.top.y,
			node.axisAlignedBoundingBox.top.z
		)

		table.insert(nodes, string.format('  node%d [label="%s"];', id, label))

		if parentId then
			table.insert(edges, string.format("  node%d -> node%d;", parentId, id))
		end

		if not node.isLeafNode then
			nodeToDot(node.quadrants.bottomLeft, id, depth + 1)
			nodeToDot(node.quadrants.bottomRight, id, depth + 1)
			nodeToDot(node.quadrants.topLeft, id, depth + 1)
			nodeToDot(node.quadrants.topRight, id, depth + 1)
		end
	end

	nodeToDot(self, nil, currentDepth)

	return "digraph QuadTree {\n" .. table.concat(nodes, "\n") .. "\n" .. table.concat(edges, "\n") .. "\n}"
end

-- This is only useful for testing; instead of storing trees for each fixture, simply generate it on the fly
function QuadTreeRange:CreateDebugTree()
	local x = "\000\000\122\068" -- 1000
	local y = "\000\000\122\068" -- 1000
	local z = "\000\000\122\068" -- 1000
	return string.rep(x .. y .. z, 65520 / 12)
end

function QuadTreeRange:CreateNormalizedDebugTree()
	local x = "\000\000\072\067" -- 200
	local y = "\000\000\072\195" -- -200
	local z = "\000\000\072\067" -- 200
	return string.rep(x .. y .. z, 65520 / 12)
end

QuadTreeRange.__call = QuadTreeRange.Construct
QuadTreeRange.__index = QuadTreeRange
setmetatable(QuadTreeRange, QuadTreeRange)

return QuadTreeRange
