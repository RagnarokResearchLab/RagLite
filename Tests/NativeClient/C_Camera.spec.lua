local C_Camera = require("Core.NativeClient.C_Camera")
local Vector3D = require("Core.NativeClient.Vector3D")

describe("C_Camera", function()
	describe("CreatePerspectiveProjection", function()
		it("should return a WebGPU-compatible left-handed 4D projection matrix in row-major notation", function()
			local aspectRatio = 1920.0 / 1080.0
			local zNearDistance = 2
			local zFarDistance = 300
			local verticalFieldOfViewInDegrees = 15

			local projectionMatrix = C_Camera.CreatePerspectiveProjection(
				verticalFieldOfViewInDegrees,
				aspectRatio,
				zNearDistance,
				zFarDistance
			)

			local allowedDelta = 1E-4
			assertEqualNumbers(projectionMatrix.x1, 4.272611618042, allowedDelta)
			assertEquals(projectionMatrix.x2, 0)
			assertEquals(projectionMatrix.x3, 0)
			assertEquals(projectionMatrix.x4, 0)
			assertEquals(projectionMatrix.y1, 0)
			assertEqualNumbers(projectionMatrix.y2, 7.595754, allowedDelta)
			assertEquals(projectionMatrix.y3, 0)
			assertEquals(projectionMatrix.y4, 0)
			assertEquals(projectionMatrix.z1, 0)
			assertEquals(projectionMatrix.z2, 0)
			assertEqualNumbers(projectionMatrix.z3, 1.0067113, allowedDelta)
			assertEqualNumbers(projectionMatrix.z4, -2.0134, allowedDelta)
			assertEquals(projectionMatrix.w1, 0)
			assertEquals(projectionMatrix.w2, 0)
			assertEquals(projectionMatrix.w3, 1)
			assertEquals(projectionMatrix.w4, 0)
		end)
	end)

	describe("CreateOrbitalView", function()
		it("should return a WebGPU-compatible left-handed 4D view matrix in row-major notation", function()
			local cameraWorldPosition = Vector3D(-5, 5, -5)
			local targetWorldPosition = Vector3D(0, 0, 0)
			local upVectorHint = Vector3D(0, 1, 0)
			local viewMatrix = C_Camera.CreateOrbitalView(cameraWorldPosition, targetWorldPosition, upVectorHint)

			local allowedDelta = 1E-3
			assertEqualNumbers(viewMatrix.x1, 0.707, allowedDelta)
			assertEquals(viewMatrix.x2, 0)
			assertEqualNumbers(viewMatrix.x3, -0.707, allowedDelta)
			assertEquals(viewMatrix.x4, 0)
			assertEqualNumbers(viewMatrix.y1, 0.408, allowedDelta)
			assertEqualNumbers(viewMatrix.y2, 0.816, allowedDelta)
			assertEqualNumbers(viewMatrix.y3, 0.408, allowedDelta)
			assertEquals(viewMatrix.y4, 0)
			assertEqualNumbers(viewMatrix.z1, 0.577, allowedDelta)
			assertEqualNumbers(viewMatrix.z2, -0.577, allowedDelta)
			assertEqualNumbers(viewMatrix.z3, 0.577, allowedDelta)
			assertEqualNumbers(viewMatrix.z4, 8.660, allowedDelta)
			assertEquals(viewMatrix.w1, 0)
			assertEquals(viewMatrix.w2, 0)
			assertEquals(viewMatrix.w3, 0)
			assertEquals(viewMatrix.w4, 1)
		end)

		local function isNaN(x)
			return x ~= x
		end

		local function assertValidNumber(x)
			local isValidNumber = not isNaN(x)
			assertTrue(isValidNumber)
		end

		it("should return a valid view matrix even if the look direction is parallel to the up vector", function()
			local cameraWorldPosition = Vector3D(0, 5, 0)
			local targetWorldPosition = Vector3D(0, 0, 0)
			local upVectorHint = Vector3D(0, 1, 0)
			local viewMatrix = C_Camera.CreateOrbitalView(cameraWorldPosition, targetWorldPosition, upVectorHint)

			assertValidNumber(viewMatrix.x1)
			assertValidNumber(viewMatrix.x2)
			assertValidNumber(viewMatrix.x3)
			assertValidNumber(viewMatrix.x4)
			assertValidNumber(viewMatrix.y1)
			assertValidNumber(viewMatrix.y2)
			assertValidNumber(viewMatrix.y3)
			assertValidNumber(viewMatrix.y4)
			assertValidNumber(viewMatrix.z1)
			assertValidNumber(viewMatrix.z2)
			assertValidNumber(viewMatrix.z3)
			assertValidNumber(viewMatrix.z4)
			assertValidNumber(viewMatrix.w1)
			assertValidNumber(viewMatrix.w2)
			assertValidNumber(viewMatrix.w3)
			assertValidNumber(viewMatrix.w4)
		end)

		it("should return a valid view matrix even if the look direction is parallel to the down vector", function()
			local cameraWorldPosition = Vector3D(0, -5, 0)
			local targetWorldPosition = Vector3D(0, 0, 0)
			local upVectorHint = Vector3D(0, 1, 0)
			local viewMatrix = C_Camera.CreateOrbitalView(cameraWorldPosition, targetWorldPosition, upVectorHint)

			assertValidNumber(viewMatrix.x1)
			assertValidNumber(viewMatrix.x2)
			assertValidNumber(viewMatrix.x3)
			assertValidNumber(viewMatrix.x4)
			assertValidNumber(viewMatrix.y1)
			assertValidNumber(viewMatrix.y2)
			assertValidNumber(viewMatrix.y3)
			assertValidNumber(viewMatrix.y4)
			assertValidNumber(viewMatrix.z1)
			assertValidNumber(viewMatrix.z2)
			assertValidNumber(viewMatrix.z3)
			assertValidNumber(viewMatrix.z4)
			assertValidNumber(viewMatrix.w1)
			assertValidNumber(viewMatrix.w2)
			assertValidNumber(viewMatrix.w3)
			assertValidNumber(viewMatrix.w4)
		end)
	end)

	describe("ComputeOrbitPositionInLocalSpace", function()
		it("should return the world position of a rotated orbital camera looking at the origin", function()
			local azimuthAngleInDegrees = 45
			local polarAngleInDegrees = 45
			local radiusInWorldUnits = 10

			local cameraWorldPosition = C_Camera.ComputeOrbitPositionInLocalSpace(
				azimuthAngleInDegrees,
				polarAngleInDegrees,
				radiusInWorldUnits
			)

			local allowedDelta = 1E-3
			assertEqualNumbers(cameraWorldPosition.x, -5, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.y, 7.071, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.z, -5, allowedDelta)
		end)

		it(
			"should return the origin of the spherical coordinate system if both angles are zero and the camera is at unit distance",
			function()
				local azimuthAngleInDegrees = 0
				local polarAngleInDegrees = 0
				local radiusInWorldUnits = 1

				local cameraWorldPosition = C_Camera.ComputeOrbitPositionInLocalSpace(
					azimuthAngleInDegrees,
					polarAngleInDegrees,
					radiusInWorldUnits
				)

				assertEquals(cameraWorldPosition.x, 0)
				assertEquals(cameraWorldPosition.y, 0)
				assertEquals(cameraWorldPosition.z, -1)
			end
		)

		it("should return a position rotated left around the Y axis when the azimuth angle increases", function()
			local azimuthAngleInDegrees = 90
			local polarAngleInDegrees = 0
			local radiusInWorldUnits = 10

			local cameraWorldPosition = C_Camera.ComputeOrbitPositionInLocalSpace(
				azimuthAngleInDegrees,
				polarAngleInDegrees,
				radiusInWorldUnits
			)

			local allowedDelta = 1E-3
			assertEqualNumbers(cameraWorldPosition.x, -10, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.y, 0, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.z, 0, allowedDelta)
		end)

		it("should return a position rotated right around the Y axis when the azimuth angle decreases", function()
			local azimuthAngleInDegrees = -90
			local polarAngleInDegrees = 0
			local radiusInWorldUnits = 10

			local cameraWorldPosition = C_Camera.ComputeOrbitPositionInLocalSpace(
				azimuthAngleInDegrees,
				polarAngleInDegrees,
				radiusInWorldUnits
			)

			local allowedDelta = 1E-3
			assertEqualNumbers(cameraWorldPosition.x, 10, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.y, 0, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.z, 0, allowedDelta)
		end)

		it("should return a position rotated upwards around the X axis when the polar angle increases", function()
			local azimuthAngleInDegrees = 0
			local polarAngleInDegrees = 90
			local radiusInWorldUnits = 10

			local cameraWorldPosition = C_Camera.ComputeOrbitPositionInLocalSpace(
				azimuthAngleInDegrees,
				polarAngleInDegrees,
				radiusInWorldUnits
			)

			local allowedDelta = 1E-3
			assertEqualNumbers(cameraWorldPosition.x, 0, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.y, 10, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.z, 0, allowedDelta)
		end)

		it("should return a position rotated downwards around the X axis when the polar angle decreases", function()
			local azimuthAngleInDegrees = 0
			local polarAngleInDegrees = -90
			local radiusInWorldUnits = 10

			local cameraWorldPosition = C_Camera.ComputeOrbitPositionInLocalSpace(
				azimuthAngleInDegrees,
				polarAngleInDegrees,
				radiusInWorldUnits
			)

			local allowedDelta = 1E-3
			assertEqualNumbers(cameraWorldPosition.x, 0, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.y, -10, allowedDelta)
			assertEqualNumbers(cameraWorldPosition.z, 0, allowedDelta)
		end)
	end)

	describe("GetViewSpaceOrigin", function()
		it("should return the default world position of the orbital camera", function()
			local defaultCameraPosition = C_Camera.GetViewSpaceOrigin()

			-- This is somewhat arbitrary, but it  only matters is that it's used consistently (hence this interface)
			assertEquals(defaultCameraPosition.x, 0)
			assertEquals(defaultCameraPosition.y, 0)
			assertEquals(defaultCameraPosition.z, -1)
		end)
	end)
end)
