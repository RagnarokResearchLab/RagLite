local Matrix4D = require("Core.VectorMath.Matrix4D")

describe("Matrix4D", function()
	it("should return an empty 4x4 matrix in row-major notation", function()
		local matrix = Matrix4D()

		assertEquals(matrix.x1, 0)
		assertEquals(matrix.x2, 0)
		assertEquals(matrix.x3, 0)
		assertEquals(matrix.x4, 0)
		assertEquals(matrix.y1, 0)
		assertEquals(matrix.y2, 0)
		assertEquals(matrix.y3, 0)
		assertEquals(matrix.y4, 0)
		assertEquals(matrix.z1, 0)
		assertEquals(matrix.z2, 0)
		assertEquals(matrix.z3, 0)
		assertEquals(matrix.z4, 0)
		assertEquals(matrix.w1, 0)
		assertEquals(matrix.w2, 0)
		assertEquals(matrix.w3, 0)
		assertEquals(matrix.w4, 0)
	end)

	describe("CreateIdentity", function()
		it("should return a 4x4 unit matrix in row-major notation", function()
			local matrix = Matrix4D:CreateIdentity()

			assertEquals(matrix.x1, 1)
			assertEquals(matrix.x2, 0)
			assertEquals(matrix.x3, 0)
			assertEquals(matrix.x4, 0)
			assertEquals(matrix.y1, 0)
			assertEquals(matrix.y2, 1)
			assertEquals(matrix.y3, 0)
			assertEquals(matrix.y4, 0)
			assertEquals(matrix.z1, 0)
			assertEquals(matrix.z2, 0)
			assertEquals(matrix.z3, 1)
			assertEquals(matrix.z4, 0)
			assertEquals(matrix.w1, 0)
			assertEquals(matrix.w2, 0)
			assertEquals(matrix.w3, 0)
			assertEquals(matrix.w4, 1)
		end)
	end)
end)