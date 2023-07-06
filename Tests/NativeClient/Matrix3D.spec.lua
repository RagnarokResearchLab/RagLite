local Matrix3D = require("Core.NativeClient.Matrix3D")

describe("Matrix3D", function()
	it("should return an empty 3x3 matrix in row-major notation", function()
		local matrix = Matrix3D()

		assertEquals(matrix.x1, 0)
		assertEquals(matrix.x2, 0)
		assertEquals(matrix.x3, 0)
		assertEquals(matrix.y1, 0)
		assertEquals(matrix.y2, 0)
		assertEquals(matrix.y3, 0)
		assertEquals(matrix.z1, 0)
		assertEquals(matrix.z2, 0)
		assertEquals(matrix.z3, 0)
	end)

	describe("CreateIdentity", function()
		it("should return a 3x3 unit matrix in row-major notation", function()
			local matrix = Matrix3D:CreateIdentity()

			assertEquals(matrix.x1, 1)
			assertEquals(matrix.x2, 0)
			assertEquals(matrix.x3, 0)
			assertEquals(matrix.y1, 0)
			assertEquals(matrix.y2, 1)
			assertEquals(matrix.y3, 0)
			assertEquals(matrix.z1, 0)
			assertEquals(matrix.z2, 0)
			assertEquals(matrix.z3, 1)
		end)
	end)

	describe("CreateRotationAroundX", function()
		it(
			"should return a 3x3 matrix in row-major notation that encodes a clockwise rotation around the X axis",
			function()
				local rotationMatrix = Matrix3D:CreateAxisRotationX(90)

				local allowedDelta = 1E-3
				assertEqualNumbers(rotationMatrix.x1, 1, allowedDelta)
				assertEqualNumbers(rotationMatrix.x2, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.x3, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.y1, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.y2, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.y3, 1, allowedDelta)
				assertEqualNumbers(rotationMatrix.z1, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.z2, -1, allowedDelta)
				assertEqualNumbers(rotationMatrix.z3, 0, allowedDelta)
			end
		)
	end)

	describe("CreateAxisRotationY", function()
		it(
			"should return a 3x3 matrix in row-major notation that encodes a clockwise rotation around the Y axis",
			function()
				local rotationMatrix = Matrix3D:CreateAxisRotationY(90)

				local allowedDelta = 1E-3
				assertEqualNumbers(rotationMatrix.x1, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.x2, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.x3, -1, allowedDelta)
				assertEqualNumbers(rotationMatrix.y1, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.y2, 1, allowedDelta)
				assertEqualNumbers(rotationMatrix.y3, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.z1, 1, allowedDelta)
				assertEqualNumbers(rotationMatrix.z2, 0, allowedDelta)
				assertEqualNumbers(rotationMatrix.z3, 0, allowedDelta)
			end
		)
	end)
end)
