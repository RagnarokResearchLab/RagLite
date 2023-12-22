local ffi = require("ffi")
local transform = require("transform")

local ffi_new = ffi.new
local format = string.format
local math_cos = math.cos
local math_sin = math.sin
local transform_bold = transform.bold

ffi.cdef([[
	typedef struct Matrix3D {
		float x1;
		float x2;
		float x3;
		float y1;
		float y2;
		float y3;
		float z1;
		float z2;
		float z3;
	} Matrix3D;
]])

local Matrix3D = {}

function Matrix3D:__tostring()
	local formatted = {
		x1 = format("%.3f", self.x1),
		x2 = format("%.3f", self.x2),
		x3 = format("%.3f", self.x3),
		y1 = format("%.3f", self.y1),
		y2 = format("%.3f", self.y2),
		y3 = format("%.3f", self.y3),
		z1 = format("%.3f", self.z1),
		z2 = format("%.3f", self.z2),
		z3 = format("%.3f", self.z3),
	}

	local firstRow = format("%10s %10s %10s", formatted.x1, formatted.x2, formatted.x3)
	local secondRow = format("%10s %10s %10s", formatted.y1, formatted.y2, formatted.y3)
	local thirdRow = format("%10s %10s %10s", formatted.z1, formatted.z2, formatted.z3)

	local components = firstRow .. "\n" .. secondRow .. "\n" .. thirdRow .. "\n"

	return format("%s\n%s", transform_bold("cdata<Matrix3D>:"), components)
end

function Matrix3D:CreateIdentity()
	local identityMatrix = ffi_new("Matrix3D")

	identityMatrix.x1, identityMatrix.y2, identityMatrix.z3 = 1, 1, 1

	return identityMatrix
end

local function deg2rad(angleInDegrees)
	return angleInDegrees * math.pi / 180
end

function Matrix3D:CreateAxisRotationX(rotationAngleInDegrees)
	local rotationAngleInRadians = deg2rad(rotationAngleInDegrees)

	local rotationMatrix = ffi_new("Matrix3D")

	rotationMatrix.x1 = 1
	rotationMatrix.y2 = math_cos(rotationAngleInRadians)
	rotationMatrix.y3 = math_sin(rotationAngleInRadians)
	rotationMatrix.z2 = -math_sin(rotationAngleInRadians)
	rotationMatrix.z3 = math_cos(rotationAngleInRadians)

	return rotationMatrix
end

function Matrix3D:CreateAxisRotationY(rotationAngleInDegrees)
	local rotationAngleInRadians = deg2rad(rotationAngleInDegrees)

	local rotationMatrix = ffi_new("Matrix3D")

	rotationMatrix.x1 = math_cos(rotationAngleInRadians)
	rotationMatrix.x3 = -math_sin(rotationAngleInRadians)
	rotationMatrix.y2 = 1
	rotationMatrix.z1 = math_sin(rotationAngleInRadians)
	rotationMatrix.z3 = math_cos(rotationAngleInRadians)

	return rotationMatrix
end

Matrix3D.__index = Matrix3D

return ffi.metatype("Matrix3D", Matrix3D)
