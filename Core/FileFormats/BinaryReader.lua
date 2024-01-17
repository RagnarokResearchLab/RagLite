local ffi = require("ffi")

local cast = ffi.cast
local sizeof = ffi.sizeof
local ffi_string = ffi.string
local type = type

local BinaryReader = {
	ERROR_SEEKING_INVALID_OFFSET = "Cannot move file pointer outside the buffered range",
}

function BinaryReader:Construct(readOnlyBuffer)
	if type(readOnlyBuffer) == "string" then
		readOnlyBuffer = buffer.new(#readOnlyBuffer):set(readOnlyBuffer)
	end

	if type(readOnlyBuffer) ~= "userdata" then
		error("Cannot initialize BinaryReader (no input buffer provided)", 0)
	end

	local instance = {
		readOnlyBuffer = readOnlyBuffer,
		virtualFilePointer = 0,
		endOfFilePointer = #readOnlyBuffer,
	}

	setmetatable(instance, self)

	return instance
end

function BinaryReader:Forward(numBytes)
	self.virtualFilePointer = self.virtualFilePointer + numBytes
	if self.virtualFilePointer > self.endOfFilePointer then
		self.virtualFilePointer = self.endOfFilePointer
		error(self.ERROR_SEEKING_INVALID_OFFSET, 0)
	end
end

function BinaryReader:Rewind(numBytes)
	self.virtualFilePointer = self.virtualFilePointer - numBytes
	if self.virtualFilePointer < 0 then
		self.virtualFilePointer = 0
		error(self.ERROR_SEEKING_INVALID_OFFSET, 0)
	end
end

function BinaryReader:Seek(offset)
	if offset < 0 or offset > self.endOfFilePointer then
		error(self.ERROR_SEEKING_INVALID_OFFSET, 0)
	end
	self.virtualFilePointer = offset
end

function BinaryReader:Reset()
	self.virtualFilePointer = 0
end

function BinaryReader:HasReachedEOF()
	return (self.virtualFilePointer == self.endOfFilePointer)
end

-- Unsafe in the sense that it read-faults off the end of the scanned range, but not the buffer
function BinaryReader:GetUnsafePointer(numBytesToRead)
	local numAvailableBytes = self.endOfFilePointer - self.virtualFilePointer
	if numBytesToRead > numAvailableBytes then
		local errorMessage = format(
			"Failed to read %d bytes starting at offset %d (%d additional bytes are available)",
			numBytesToRead,
			self.virtualFilePointer,
			numAvailableBytes
		)
		error(errorMessage, 0)
	end

	local cdataPointer = cast("uint8_t*", self.readOnlyBuffer) + self.virtualFilePointer
	self.virtualFilePointer = self.virtualFilePointer + numBytesToRead

	return cdataPointer
end

function BinaryReader:GetTypedArray(cTypeName, numElements)
	numElements = numElements or 1
	local cdataPointer = self:GetUnsafePointer(sizeof(cTypeName) * numElements)
	return cast(cTypeName .. "*", cdataPointer) -- Slightly inefficient (GC), but oh well
end

function BinaryReader:GetChar()
	local cdataPointer = cast("char*", self:GetUnsafePointer(1))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetNullTerminatedString(numBytesToRead)
	local bytes = self:GetUnsafePointer(numBytesToRead)

	-- It's possible there just isn't any \0 in the requested range
	local actualLength = numBytesToRead
	for i = 0, numBytesToRead - 1 do
		if bytes[i] == 0 then
			actualLength = i
			break
		end
	end

	return ffi_string(bytes, actualLength)
end

function BinaryReader:GetCountedString(numBytesToRead)
	local bytes = self:GetUnsafePointer(numBytesToRead)
	return ffi_string(bytes, numBytesToRead)
end

function BinaryReader:GetFloat()
	local cdataPointer = cast("float*", self:GetUnsafePointer(4))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetDouble()
	local cdataPointer = cast("double*", self:GetUnsafePointer(8))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetInt64()
	local cdataPointer = cast("int64_t*", self:GetUnsafePointer(8))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetUnsignedInt64()
	local cdataPointer = cast("uint64_t*", self:GetUnsafePointer(8))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetInt32()
	local cdataPointer = cast("int32_t*", self:GetUnsafePointer(4))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetUnsignedInt32()
	local cdataPointer = cast("uint32_t*", self:GetUnsafePointer(4))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetInt16()
	local cdataPointer = cast("int16_t*", self:GetUnsafePointer(2))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetUnsignedInt16()
	local cdataPointer = cast("uint16_t*", self:GetUnsafePointer(2))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetInt8()
	local cdataPointer = cast("int8_t*", self:GetUnsafePointer(1))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetUnsignedInt8()
	local cdataPointer = cast("uint8_t*", self:GetUnsafePointer(1))
	return tonumber(cdataPointer[0])
end

function BinaryReader:GetBufferSize()
	return #self.readOnlyBuffer
end

BinaryReader.__index = BinaryReader
BinaryReader.__call = BinaryReader.Construct
BinaryReader.__len = BinaryReader.GetBufferSize
setmetatable(BinaryReader, BinaryReader)

return BinaryReader
