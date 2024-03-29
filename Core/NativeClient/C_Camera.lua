local Matrix3D = require("Core.VectorMath.Matrix3D")
local Matrix4D = require("Core.VectorMath.Matrix4D")
local Vector3D = require("Core.VectorMath.Vector3D")

local math_max = math.max
local math_min = math.min
local math_tan = math.tan

local function deg2rad(angleInDegrees)
	return angleInDegrees * math.pi / 180
end

local C_Camera = {
	DEFAULT_FIELD_OF_VIEW = 15,
	DEFAULT_NEAR_PLANE_DISTANCE = 2,
	DEFAULT_FAR_PLANE_DISTANCE = 300,
	verticalFieldOfViewInDegrees = 15,
	nearPlaneDistanceInWorldUnits = 2,
	farPlaneDistanceInWorldUnits = 300,
	isAdjustingView = false,
	DEFAULT_HORIZONTAL_ROTATION = 0,
	DEFAULT_VERTICAL_ROTATION = 50,
	MIN_VERTICAL_ROTATION = 50,
	MAX_VERTICAL_ROTATION = 65,
	DEFAULT_ORBIT_DISTANCE = 60,
	horizontalRotationAngleInDegrees = 0,
	verticalRotationAngleInDegrees = 50,
	orbitDistanceInWorldUnits = 60,
	DEGREES_PER_ZOOM_LEVEL = 5,
	MIN_ORBIT_DISTANCE = 45,
	MAX_ORBIT_DISTANCE = 80,
	targetWorldPosition = Vector3D(0, 0, 0),
	TARGET_DEBUG_STEPSIZE_IN_WORLD_UNITS = 12,
}

function C_Camera.CreatePerspectiveProjection(verticalFieldOfViewInDegrees, aspectRatio, zNearDistance, zFarDistance)
	local perspectiveProjectionMatrix = Matrix4D()

	local verticalFieldOfViewInRadians = deg2rad(verticalFieldOfViewInDegrees)

	local focalLength = 1 / math_tan(verticalFieldOfViewInRadians / 2)
	local zRange = zFarDistance - zNearDistance

	perspectiveProjectionMatrix.x1 = focalLength / aspectRatio
	perspectiveProjectionMatrix.x2 = 0
	perspectiveProjectionMatrix.x3 = 0
	perspectiveProjectionMatrix.x4 = 0

	perspectiveProjectionMatrix.y1 = 0
	perspectiveProjectionMatrix.y2 = focalLength
	perspectiveProjectionMatrix.y3 = 0
	perspectiveProjectionMatrix.y4 = 0

	perspectiveProjectionMatrix.z1 = 0
	perspectiveProjectionMatrix.z2 = 0
	perspectiveProjectionMatrix.z3 = zFarDistance / zRange
	perspectiveProjectionMatrix.z4 = -zNearDistance * zFarDistance / zRange

	perspectiveProjectionMatrix.w1 = 0
	perspectiveProjectionMatrix.w2 = 0
	perspectiveProjectionMatrix.w3 = 1
	perspectiveProjectionMatrix.w4 = 0

	return perspectiveProjectionMatrix
end

local function GetOrthogonalRightVector(upVectorHint, forwardVector)
	local rightVector = upVectorHint:CrossProduct(forwardVector)

	if rightVector:GetMagnitude() >= 1E-6 then
		return rightVector
	end

	-- Can't compute the view (division by zero), so just find a different orthogonal direction
	rightVector = forwardVector:CrossProduct(Vector3D(0, 0, 1))
	if rightVector:GetMagnitude() >= 1E-6 then
		return rightVector
	end

	-- It might happen that the first attempt failed, but the second one should always work
	return forwardVector:CrossProduct(Vector3D(0, 1, 0))
end

function C_Camera.CreateOrbitalView(cameraWorldPosition, targetWorldPosition, upVectorHint)
	local viewMatrix = Matrix4D()

	local forwardVector = targetWorldPosition:Subtract(cameraWorldPosition)
	forwardVector:Normalize()

	local rightVector = GetOrthogonalRightVector(upVectorHint, forwardVector)

	rightVector:Normalize()
	local upVector = forwardVector:CrossProduct(rightVector)

	viewMatrix.x1 = rightVector.x
	viewMatrix.x2 = rightVector.y
	viewMatrix.x3 = rightVector.z
	viewMatrix.x4 = -rightVector:DotProduct(cameraWorldPosition)

	viewMatrix.y1 = upVector.x
	viewMatrix.y2 = upVector.y
	viewMatrix.y3 = upVector.z
	viewMatrix.y4 = -upVector:DotProduct(cameraWorldPosition)

	viewMatrix.z1 = forwardVector.x
	viewMatrix.z2 = forwardVector.y
	viewMatrix.z3 = forwardVector.z
	viewMatrix.z4 = -forwardVector:DotProduct(cameraWorldPosition)

	viewMatrix.w1 = 0.0
	viewMatrix.w2 = 0.0
	viewMatrix.w3 = 0.0
	viewMatrix.w4 = 1.0

	return viewMatrix
end

function C_Camera.ComputeOrbitPositionInLocalSpace(
	azimuthAngleInDegrees,
	polarAngleInDegrees,
	orbitalDistanceInWorldUnits
)
	local cameraWorldPosition = C_Camera.GetViewSpaceOrigin()

	local rotationAroundX = Matrix3D:CreateAxisRotationX(polarAngleInDegrees)
	local rotationAroundY = Matrix3D:CreateAxisRotationY(azimuthAngleInDegrees)

	cameraWorldPosition:Transform(rotationAroundX)
	cameraWorldPosition:Transform(rotationAroundY)
	cameraWorldPosition:Scale(orbitalDistanceInWorldUnits)

	return cameraWorldPosition
end

function C_Camera.GetViewSpaceOrigin()
	return Vector3D(0, 0, -1)
end

function C_Camera.GetPerspective()
	return {
		fov = C_Camera.verticalFieldOfViewInDegrees,
		nearZ = C_Camera.nearPlaneDistanceInWorldUnits,
		farZ = C_Camera.farPlaneDistanceInWorldUnits,
	}
end

function C_Camera.IsAdjustingView()
	return C_Camera.isAdjustingView
end

function C_Camera.StartAdjustingView()
	C_Camera.isAdjustingView = true
end

function C_Camera.StopAdjustingView()
	C_Camera.isAdjustingView = false
end

function C_Camera.GetWorldPosition()
	local orbitPositionRelativeToTarget = C_Camera.ComputeOrbitPositionInLocalSpace(
		C_Camera.horizontalRotationAngleInDegrees,
		C_Camera.verticalRotationAngleInDegrees,
		C_Camera.orbitDistanceInWorldUnits
	)

	return orbitPositionRelativeToTarget:Add(C_Camera.targetWorldPosition)
end

function C_Camera.GetHorizontalRotationAngle()
	return C_Camera.horizontalRotationAngleInDegrees
end

function C_Camera.GetVerticalRotationAngle()
	return C_Camera.verticalRotationAngleInDegrees
end

function C_Camera.ApplyHorizontalRotation(delta)
	C_Camera.horizontalRotationAngleInDegrees = (C_Camera.horizontalRotationAngleInDegrees + delta) % 360
end

function C_Camera.ApplyVerticalRotation(delta)
	local requestedAngle = (C_Camera.verticalRotationAngleInDegrees + delta) % 360
	C_Camera.verticalRotationAngleInDegrees =
		math_min(math_max(requestedAngle, C_Camera.MIN_VERTICAL_ROTATION), C_Camera.MAX_VERTICAL_ROTATION)
end

function C_Camera.ResetView()
	C_Camera.horizontalRotationAngleInDegrees = C_Camera.DEFAULT_HORIZONTAL_ROTATION
	C_Camera.verticalRotationAngleInDegrees = C_Camera.DEFAULT_VERTICAL_ROTATION
end

function C_Camera.GetOrbitDistance()
	return C_Camera.orbitDistanceInWorldUnits
end

function C_Camera.ZoomIn()
	local requestedOrbitDistance = C_Camera.orbitDistanceInWorldUnits - C_Camera.DEGREES_PER_ZOOM_LEVEL
	local newOrbitDistance = math_max(requestedOrbitDistance, C_Camera.MIN_ORBIT_DISTANCE)
	C_Camera.orbitDistanceInWorldUnits = newOrbitDistance
end

function C_Camera.ZoomOut()
	local requestedOrbitDistance = C_Camera.orbitDistanceInWorldUnits + C_Camera.DEGREES_PER_ZOOM_LEVEL
	local newOrbitDistance = math_min(requestedOrbitDistance, C_Camera.MAX_ORBIT_DISTANCE)
	C_Camera.orbitDistanceInWorldUnits = newOrbitDistance
end

function C_Camera.ResetZoom()
	C_Camera.orbitDistanceInWorldUnits = C_Camera.DEFAULT_ORBIT_DISTANCE
end

function C_Camera.SetOrbitDistance(distance)
	C_Camera.orbitDistanceInWorldUnits = distance
end

function C_Camera.GetTargetPosition()
	return C_Camera.targetWorldPosition
end

function C_Camera.SetTargetPosition(newPosition)
	C_Camera.targetWorldPosition.x = newPosition.x
	C_Camera.targetWorldPosition.y = newPosition.y
	C_Camera.targetWorldPosition.z = newPosition.z
end

return C_Camera
