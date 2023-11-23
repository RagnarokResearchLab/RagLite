local Matrix3D = require("Core.VectorMath.Matrix3D")
local Vector3D = require("Core.VectorMath.Vector3D")

describe("Vector3D", function()
	it("should return an empty 1x3 matrix in row-major notation if no coordinates were passed", function()
		local vector = Vector3D()

		assertEquals(vector.x, 0)
		assertEquals(vector.y, 0)
		assertEquals(vector.z, 0)
	end)

	it(
		"should return a 1x3 matrix in row-major notation with the given input coordinates if any were passed",
		function()
			local vector = Vector3D(1, 2, 3)

			assertEquals(vector.x, 1)
			assertEquals(vector.y, 2)
			assertEquals(vector.z, 3)
		end
	)

	describe("Add", function()
		it("should return a new 3D vector that contains the sum of the two given inputs", function()
			local initialPosition = Vector3D()
			local finalPosition = Vector3D()

			initialPosition.x = 2
			initialPosition.y = 4
			initialPosition.z = 6

			finalPosition.x = 1
			finalPosition.y = 2
			finalPosition.z = 3

			local resultant = finalPosition:Add(initialPosition)
			assertEquals(resultant.x, 3)
			assertEquals(resultant.y, 6)
			assertEquals(resultant.z, 9)
		end)
	end)

	describe("Subtract", function()
		it("should return a new 3D vector that contains the displacement between two given inputs", function()
			local initialPosition = Vector3D()
			local finalPosition = Vector3D()

			initialPosition.x = 2
			initialPosition.y = 4
			initialPosition.z = 6

			finalPosition.x = 1
			finalPosition.y = 2
			finalPosition.z = 3

			local displacement = finalPosition:Subtract(initialPosition)
			assertEquals(displacement.x, -1)
			assertEquals(displacement.y, -2)
			assertEquals(displacement.z, -3)
		end)
	end)

	describe("DotProduct", function()
		it("should return a new 3D vector that contains the dot product of two given inputs", function()
			local firstVector = Vector3D()
			local secondVector = Vector3D()
			local thirdVector = Vector3D()

			firstVector.x = 1
			firstVector.y = 2
			firstVector.z = -1

			secondVector.x = 3
			secondVector.y = 2
			secondVector.z = 1

			thirdVector.x = 0
			thirdVector.y = -5
			thirdVector.z = 2

			assertEquals(firstVector:DotProduct(secondVector), 6)
			assertEquals(firstVector:DotProduct(thirdVector), -12)
		end)
	end)

	describe("CrossProduct", function()
		it("should return a new 3D vector that contains the cross product of two given inputs", function()
			local firstVector = Vector3D()
			local secondVector = Vector3D()

			firstVector.x = 2
			firstVector.y = 3
			firstVector.z = 4

			secondVector.x = 5
			secondVector.y = 6
			secondVector.z = 7

			local result = firstVector:CrossProduct(secondVector)

			assertEquals(result.x, -3)
			assertEquals(result.y, 6)
			assertEquals(result.z, -3)
		end)
	end)

	describe("Normalize", function()
		it("should normalize the given input vector in-place", function()
			local vector = Vector3D(3, 1, 2)

			vector:Normalize()

			local allowedDelta = 1E-3
			assertEqualNumbers(vector.x, 0.802, allowedDelta)
			assertEqualNumbers(vector.y, 0.267, allowedDelta)
			assertEqualNumbers(vector.z, 0.534, allowedDelta)
		end)
	end)

	describe("Transform", function()
		it("should transform the vector with the given transformation matrix", function()
			local vector = Vector3D(0, 0, -1)
			local rotationMatrix = Matrix3D:CreateAxisRotationX(90)
			vector:Transform(rotationMatrix)

			local allowedDelta = 1E-3
			assertEqualNumbers(vector.x, 0, allowedDelta)
			assertEqualNumbers(vector.y, 1, allowedDelta)
			assertEqualNumbers(vector.z, 0, allowedDelta)
		end)
	end)

	describe("Scale", function()
		it("should apply the given scale factor to all of the vector's components", function()
			local vector = Vector3D(1, 2, 3)
			local scaleFactor = 42
			vector:Scale(scaleFactor)

			assertEquals(vector.x, 1 * 42)
			assertEquals(vector.y, 2 * 42)
			assertEquals(vector.z, 3 * 42)
		end)
	end)

	describe("GetMagnitude", function()
		it("should return zero if the input was the zero vector", function()
			local zeroVector = Vector3D(0, 0, 0)
			assertEquals(zeroVector:GetMagnitude(), 0)
		end)

		it("should return one if the input was a unit vector", function()
			local zeroVector = Vector3D(1, 0, 0)
			assertEquals(zeroVector:GetMagnitude(), 1)
		end)

		it("should return the magnitude of the given vector", function()
			local zeroVector = Vector3D(1, 2, 3)
			assertEqualNumbers(zeroVector:GetMagnitude(), 3.7416573867739, 1E-3)
		end)
	end)
end)
