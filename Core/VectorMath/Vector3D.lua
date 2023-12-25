local ffi = require("ffi")
local transform = require("transform")

local format = format
local ffi_new = ffi.new
local math_sqrt = math.sqrt
local transform_bold = transform.bold

ffi.cdef([[
	typedef struct Vector3D {
		float x;
		float y;
		float z;
	} Vector3D;
]])

local Vector3D = {}

function Vector3D:__tostring()
	local formatted = {
		x = format("%.3f", self.x),
		y = format("%.3f", self.y),
		z = format("%.3f", self.z),
	}
	local firstRow = format("{ x = %s, y = %s, z = %s }", formatted.x, formatted.y, formatted.z)
	return format("%s %s", transform_bold("Vector3D"), firstRow)
end

function Vector3D:Add(anotherVector)
	local result = ffi_new("Vector3D")
	result.x = self.x + anotherVector.x
	result.y = self.y + anotherVector.y
	result.z = self.z + anotherVector.z
	return result
end

function Vector3D:Subtract(anotherVector)
	local result = ffi_new("Vector3D")
	result.x = self.x - anotherVector.x
	result.y = self.y - anotherVector.y
	result.z = self.z - anotherVector.z
	return result
end

function Vector3D:DotProduct(anotherVector)
	return self.x * anotherVector.x + self.y * anotherVector.y + self.z * anotherVector.z
end

function Vector3D:CrossProduct(anotherVector)
	local result = ffi.new("Vector3D")
	result.x = self.y * anotherVector.z - self.z * anotherVector.y
	result.y = self.z * anotherVector.x - self.x * anotherVector.z
	result.z = self.x * anotherVector.y - self.y * anotherVector.x
	return result
end

function Vector3D:Normalize()
	local length = math_sqrt(self:DotProduct(self))
	self.x = self.x / length
	self.y = self.y / length
	self.z = self.z / length
end

function Vector3D:Transform(transformationMatrix)
	local transformedX = self.x * transformationMatrix.x1
		+ self.y * transformationMatrix.y1
		+ self.z * transformationMatrix.z1
	local transformedY = self.x * transformationMatrix.x2
		+ self.y * transformationMatrix.y2
		+ self.z * transformationMatrix.z2
	local transformedZ = self.x * transformationMatrix.x3
		+ self.y * transformationMatrix.y3
		+ self.z * transformationMatrix.z3

	self.x = transformedX
	self.y = transformedY
	self.z = transformedZ
end

function Vector3D:Scale(scaleFactorXYZ)
	self.x = self.x * scaleFactorXYZ
	self.y = self.y * scaleFactorXYZ
	self.z = self.z * scaleFactorXYZ
end

function Vector3D:GetMagnitude()
	return math_sqrt(self:DotProduct(self))
end

Vector3D.__index = Vector3D

return ffi.metatype("Vector3D", Vector3D)
