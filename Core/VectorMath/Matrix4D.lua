local ffi = require("ffi")
local transform = require("transform")

local new = ffi.new
local format = string.format
local transform_bold = transform.bold

ffi.cdef([[
	typedef struct Matrix4D {
		float x1;
		float x2;
		float x3;
		float x4;
		float y1;
		float y2;
		float y3;
		float y4;
		float z1;
		float z2;
		float z3;
		float z4;
		float w1;
		float w2;
		float w3;
		float w4;
	} Matrix4D;
]])

local Matrix4D = {}

function Matrix4D:__tostring()
	local formatted = {
		x1 = format("%.3f", self.x1),
		x2 = format("%.3f", self.x2),
		x3 = format("%.3f", self.x3),
		x4 = format("%.3f", self.x4),
		y1 = format("%.3f", self.y1),
		y2 = format("%.3f", self.y2),
		y3 = format("%.3f", self.y3),
		y4 = format("%.3f", self.y4),
		z1 = format("%.3f", self.z1),
		z2 = format("%.3f", self.z2),
		z3 = format("%.3f", self.z3),
		z4 = format("%.3f", self.z4),
		w1 = format("%.3f", self.w1),
		w2 = format("%.3f", self.w2),
		w3 = format("%.3f", self.w3),
		w4 = format("%.3f", self.w4),
	}

	local firstRow = format("%10s %10s %10s %10s", formatted.x1, formatted.x2, formatted.x3, formatted.x4)
	local secondRow = format("%10s %10s %10s %10s", formatted.y1, formatted.y2, formatted.y3, formatted.y4)
	local thirdRow = format("%10s %10s %10s %10s", formatted.z1, formatted.z2, formatted.z3, formatted.z4)
	local fourthRow = format("%10s %10s %10s %10s", formatted.w1, formatted.w2, formatted.w3, formatted.w4)

	local components = firstRow .. "\n" .. secondRow .. "\n" .. thirdRow .. "\n" .. fourthRow

	return format("%s\n%s", transform_bold("cdata<Matrix4D>:"), components)
end

function Matrix4D:CreateIdentity()
	local identityMatrix = new("Matrix4D")

	identityMatrix.x1, identityMatrix.y2, identityMatrix.z3, identityMatrix.w4 = 1, 1, 1, 1

	return identityMatrix
end

function Matrix4D:SetColumn(columnIndex, firstValue, secondValue, thirdValue, fourthValue)
	if columnIndex == 1 then
		self.x1, self.y1, self.z1, self.w1 = firstValue, secondValue, thirdValue, fourthValue
	elseif columnIndex == 2 then
		self.x2, self.y2, self.z2, self.w2 = firstValue, secondValue, thirdValue, fourthValue
	elseif columnIndex == 3 then
		self.x3, self.y3, self.z3, self.w3 = firstValue, secondValue, thirdValue, fourthValue
	elseif columnIndex == 4 then
		self.x4, self.y4, self.z4, self.w4 = firstValue, secondValue, thirdValue, fourthValue
	else
		error(format("Invalid column index %s (valid indices are one through four)", columnIndex), 0)
	end
end

Matrix4D.__index = Matrix4D

return ffi.metatype("Matrix4D", Matrix4D)
