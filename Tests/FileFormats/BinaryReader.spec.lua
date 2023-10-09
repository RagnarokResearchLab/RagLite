local BinaryReader = require("Core.FileFormats.BinaryReader")

local ffi = require("ffi")

local function getExpectedReadFaultError(numBytesRead, offset, numBytesAvailable)
	return format(
		"Failed to read %s bytes starting at offset %s (%s additional bytes are available)",
		numBytesRead,
		offset,
		numBytesAvailable
	)
end

describe("BinaryReader", function()
	describe("Construct", function()
		it("should anchor the provided buffer to avoid it being garbage collected", function()
			local fileContents = buffer.new(42):put("HELLO!HELLO!HELLO!")
			local reader = BinaryReader(fileContents)
			assertEquals(reader.readOnlyBuffer, fileContents)
		end)

		it("should store the virtual file pointer offsets for later EOF checks", function()
			-- Not sure how useful this really is, but it's negligible overhead so let's do it anyway
			local fileContents = buffer.new(42):put("HELLO")
			local reader = BinaryReader(fileContents)
			assertEquals(reader.virtualFilePointer, 0)
			assertEquals(reader.endOfFilePointer, 5)
		end)

		it("should throw if no buffer was provided", function()
			local function createReaderWithoutBuffer()
				BinaryReader()
			end
			local expectedErrorMessage = "Cannot initialize BinaryReader (no input buffer provided)"
			assertThrows(createReaderWithoutBuffer, expectedErrorMessage)
		end)

		it("should automatically create a string buffer if a regular Lua string was passed", function()
			local fileContents = "HELLO!HELLO!HELLO!"
			local buffer = buffer.new(42):put("HELLO!HELLO!HELLO!")
			local reader = BinaryReader(buffer)
			assertEquals(tostring(reader.readOnlyBuffer), fileContents)
		end)
	end)

	describe("GetBufferSize", function()
		it("should return the byte size of the internal buffer", function()
			local fileContents = buffer.new(42):put("HELLO")
			local reader = BinaryReader(fileContents)

			assertEquals(reader:GetBufferSize(), 5)
			local numBytesRemaining = reader.endOfFilePointer - reader.virtualFilePointer
			assertEquals(reader:GetBufferSize(), numBytesRemaining)
		end)
	end)

	describe("__len", function()
		it("should return the byte size of the internal buffer", function()
			local fileContents = buffer.new(42):put("HELLO")
			local reader = BinaryReader(fileContents)

			assertEquals(#reader, 5)
			local numBytesRemaining = reader.endOfFilePointer - reader.virtualFilePointer
			assertEquals(#reader, numBytesRemaining)
		end)
	end)

	describe("Forward", function()
		it("should forward the virtual file pointer if it will stay in the buffered range", function()
			local fileContents = buffer.new(42):put("He went home and became a family man")
			local reader = BinaryReader(fileContents)
			reader:Forward(7)
			assertEquals(reader.virtualFilePointer, 7)
		end)

		it("should throw when attempting to forward the virtual file pointer outside the buffered range", function()
			local fileContents = buffer.new(42):put("Life is short and so is this string")
			local reader = BinaryReader(fileContents)
			local function attemptToAdvanceBeyondEOF()
				reader:Forward(777)
			end

			local expectedErrorMessage = BinaryReader.ERROR_SEEKING_INVALID_OFFSET
			assertThrows(attemptToAdvanceBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("Rewind", function()
		it("should rewind the virtual file pointer if it will stay in the buffered range", function()
			local fileContents = buffer.new(42):put("Advancing in another direction")
			local reader = BinaryReader(fileContents)
			reader:Forward(7)
			reader:Rewind(3)
			assertEquals(reader.virtualFilePointer, 4)
		end)

		it("should throw when attempting to rewind the virtual file pointer outside the buffered range", function()
			local fileContents = buffer.new(42):put("Life is short and so is this string")
			local reader = BinaryReader(fileContents)
			local function attemptToRewindTooFar()
				reader:Forward(7)
				reader:Rewind(777)
			end

			local expectedErrorMessage = BinaryReader.ERROR_SEEKING_INVALID_OFFSET
			assertThrows(attemptToRewindTooFar, expectedErrorMessage)
		end)
	end)

	describe("Seek", function()
		it(
			"should set the virtual file pointer to the specified position if it lies within the buffered range",
			function()
				local fileContents = buffer.new(42):put("Seek... and Destroy")
				local reader = BinaryReader(fileContents)
				reader:Seek(5)
				assertEquals(reader.virtualFilePointer, 5)
			end
		)

		it("should throw if the new position is outside the buffered range", function()
			local fileContents = buffer.new(42):put("Life is short and so is this string")
			local reader = BinaryReader(fileContents)
			local function attemptToSeekOutOfRange()
				reader:Seek(42)
			end

			local expectedErrorMessage = BinaryReader.ERROR_SEEKING_INVALID_OFFSET
			assertThrows(attemptToSeekOutOfRange, expectedErrorMessage)
		end)
	end)

	describe("Reset", function()
		it("should reset the virtual file pointer", function()
			local fileContents = buffer.new(42):put("Reset me!")
			local reader = BinaryReader(fileContents)
			reader:Forward(5)
			reader:Reset()
			assertEquals(reader.virtualFilePointer, 0)
		end)
	end)

	describe("HasReachedEOF", function()
		it("should return true if the input buffer was empty and nothing was read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			assertTrue(reader:HasReachedEOF())
		end)

		it("should return false if the input buffer was not empty and nothing was read", function()
			local fileContents = buffer.new(42):put("HELLO")
			local reader = BinaryReader(fileContents)
			assertFalse(reader:HasReachedEOF())
		end)

		it("should return true if the EOF pointer has been reached", function()
			local fileContents = buffer.new(42):put("HELLO")
			local reader = BinaryReader(fileContents)
			reader:GetCountedString(5)
			assertTrue(reader:HasReachedEOF())
		end)

		it("should return false if the EOF pointer has not been reached", function()
			local fileContents = buffer.new(42):put("HELLO")
			local reader = BinaryReader(fileContents)
			reader:GetCountedString(2)
			assertFalse(reader:HasReachedEOF())
		end)
	end)

	describe("GetCountedString", function()
		it("should throw if the input buffer was empty", function()
			local fileContents = buffer.new(42)
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetCountedString(2)
			end

			local expectedErrorMessage = getExpectedReadFaultError(2, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("Something")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetCountedString(42)
			end

			local expectedErrorMessage = getExpectedReadFaultError(42, 0, 9)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)

		it("should return the next characters as a Lua string if enough input bytes can be read", function()
			local fileContents = buffer.new(42):put("READ ME ALREADY!!!")
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetCountedString(4), "READ")
			assertEquals(reader:GetCountedString(1), " ")
			assertEquals(reader:GetCountedString(2), "ME")
			assertEquals(reader:GetCountedString(1), " ")
			assertEquals(reader:GetCountedString(7), "ALREADY")
			assertEquals(reader:GetCountedString(3), "!!!")
		end)
	end)

	describe("GetNullTerminatedString", function()
		it("should throw if the input buffer was empty", function()
			local fileContents = buffer.new(42)
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetNullTerminatedString(4)
			end

			local expectedErrorMessage = getExpectedReadFaultError(4, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)

		it("should throw if the input buffer is smaller than the requested string length", function()
			local fileContents = buffer.new(42):put("Something")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetNullTerminatedString(777)
			end

			local expectedErrorMessage = getExpectedReadFaultError(777, 0, 9)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)

		it(
			"should return a Lua string if the input doesn't contain any null terminators within the scanned range",
			function()
				local asciiBytes = {
					ffi.new("uint8_t[?]", 1, 65), -- 'A'
					ffi.new("uint8_t[?]", 1, 66), -- 'B'
					ffi.new("uint8_t[?]", 1, 67), -- 'C'
					ffi.new("uint8_t[?]", 1, 68), -- 'D'
				}
				local fileContents = buffer.new(4)
				fileContents:putcdata(asciiBytes[1], 1)
				fileContents:putcdata(asciiBytes[2], 1)
				fileContents:putcdata(asciiBytes[3], 1)
				fileContents:putcdata(asciiBytes[4], 1)
				local reader = BinaryReader(fileContents)
				assertEquals(reader:GetNullTerminatedString(2), "AB") -- LJ implicitly adds \0 (during the string conversion)
			end
		)

		it("should return a Lua string if the input contains a null terminator within the scanned range", function()
			local asciiBytes = {
				ffi.new("uint8_t[?]", 1, 65), -- 'A'
				ffi.new("uint8_t[?]", 1, 66), -- 'B'
				ffi.new("uint8_t[?]", 1, 0), -- String must end here even if the scanned range is larger
				ffi.new("uint8_t[?]", 1, 68), -- 'D'
			}
			local fileContents = buffer.new(4)
			fileContents:putcdata(asciiBytes[1], 1)
			fileContents:putcdata(asciiBytes[2], 1)
			fileContents:putcdata(asciiBytes[3], 1)
			fileContents:putcdata(asciiBytes[4], 1)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetNullTerminatedString(4), "AB")
		end)

		it("should return the next C string as a Lua string if enough input bytes can be read", function()
			local fileContents = buffer.new(42):put("READ\0ME\0ALREADY\0!!!")
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetNullTerminatedString(8), "READ") -- First \0 ends the cstring
			assertEquals(reader:GetNullTerminatedString(5), "ALREA") -- No \0 encountered
		end)
	end)

	describe("GetChar", function()
		it("should return the byte value of the next ASCII character as a number", function()
			local fileContents = buffer.new(42):put("ABCD")
			local reader = BinaryReader(fileContents)

			assertEquals(reader:GetChar(), 65) -- 'A'
			assertEquals(reader:GetChar(), 66) -- 'B'
			assertEquals(reader:GetChar(), 67) -- 'C'
			assertEquals(reader:GetChar(), 68) -- 'D'
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetChar()
			end

			local expectedErrorMessage = getExpectedReadFaultError(1, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetUnsafePointer", function()
		it("should throw if scanning the requested number of bytes would read past the EOF", function()
			local fileContents = buffer.new(42):put("Short")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetUnsafePointer(42)
			end

			local expectedErrorMessage = getExpectedReadFaultError(42, 0, 5)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)

		it("should return a cdata pointer to the scanned region", function()
			local fileContents = buffer.new(42):put("Hello World!\0")
			local reader = BinaryReader(fileContents)
			local bytes = ffi.string(reader:GetUnsafePointer(5)) -- Mid-string (not terminated)
			-- Deliberately read-fault off the end of the scanned range
			-- This tests that we actually do get a pointer, and not a copy of the bytes
			assertEquals(bytes, "Hello World!")
		end)
	end)

	describe("GetTypedArray", function()
		-- Ensure the cdefs don't conflict with anything else (probably overkill, but oh well)
		local uniqueID = require("uuid").createMersenneTwistedUUID()
		local randomizedTypeName = string.gsub("GetTypedArray_test_struct_" .. uniqueID, "-", "_") -- C syntax
		ffi.cdef(format(
			[[
					typedef struct %s {
						int x, y;
					} %s;
				]],
			randomizedTypeName,
			randomizedTypeName
		))

		it("should return a pointer to the requested struct", function()
			local struct = ffi.new(randomizedTypeName, 42, 55)
			local fileContents = buffer.new():putcdata(struct, ffi.sizeof(struct))
			local reader = BinaryReader(fileContents)
			local point = reader:GetTypedArray(randomizedTypeName)
			assertEquals(point.x, 42)
			assertEquals(point.y, 55)
		end)

		it("should throw if no more input bytes can be read for the struct", function()
			local fileContents = buffer.new(42):put("Hey")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetTypedArray(randomizedTypeName)
			end

			local expectedErrorMessage = getExpectedReadFaultError(8, 0, 3)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetFloat", function()
		it("should correctly read a float value from the virtual file pointer", function()
			local floatVal = 3.14159
			local fileContents = buffer.new(4):putcdata(ffi.new("float[1]", floatVal), 4)
			local reader = BinaryReader(fileContents)
			assertEqualNumbers(reader:GetFloat(), floatVal, 1E-3)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetFloat()
			end

			local expectedErrorMessage = getExpectedReadFaultError(4, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetDouble", function()
		it("should correctly read a double value from the virtual file pointer", function()
			local doubleVal = 3.14159265358979
			local fileContents = buffer.new(8):putcdata(ffi.new("double[1]", doubleVal), 8)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetDouble(), doubleVal)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetDouble()
			end

			local expectedErrorMessage = getExpectedReadFaultError(8, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetInt64", function()
		it("should correctly read a int64_t value from the virtual file pointer", function()
			local int64Val = 123456789012345
			local fileContents = buffer.new(8):putcdata(ffi.new("int64_t[1]", int64Val), 8)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetInt64(), int64Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetInt64()
			end

			local expectedErrorMessage = getExpectedReadFaultError(8, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetUnsignedInt64", function()
		it("should correctly read a uint64_t value from the virtual file pointer", function()
			local uint64Val = 123456789012345
			local fileContents = buffer.new(8):putcdata(ffi.new("uint64_t[1]", uint64Val), 8)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetUnsignedInt64(), uint64Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetUnsignedInt64()
			end

			local expectedErrorMessage = getExpectedReadFaultError(8, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetInt32", function()
		it("should correctly read a int32_t value from the virtual file pointer", function()
			local int32Val = 12345678
			local fileContents = buffer.new(4):putcdata(ffi.new("int32_t[1]", int32Val), 4)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetInt32(), int32Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetInt32()
			end

			local expectedErrorMessage = getExpectedReadFaultError(4, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetUnsignedInt32", function()
		it("should correctly read a uint32_t value from the virtual file pointer", function()
			local uint32Val = 12345678
			local fileContents = buffer.new(4):putcdata(ffi.new("uint32_t[1]", uint32Val), 4)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetUnsignedInt32(), uint32Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetUnsignedInt32()
			end

			local expectedErrorMessage = getExpectedReadFaultError(4, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetInt16", function()
		it("should correctly read a int16_t value from the virtual file pointer", function()
			local int16Val = 12345
			local fileContents = buffer.new(2):putcdata(ffi.new("int16_t[1]", int16Val), 2)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetInt16(), int16Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetInt16()
			end

			local expectedErrorMessage = getExpectedReadFaultError(2, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetUnsignedInt16", function()
		it("should correctly read a uint16_t value from the virtual file pointer", function()
			local uint16Val = 12345
			local fileContents = buffer.new(2):putcdata(ffi.new("uint16_t[1]", uint16Val), 2)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetUnsignedInt16(), uint16Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetUnsignedInt16()
			end

			local expectedErrorMessage = getExpectedReadFaultError(2, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetInt8", function()
		it("should correctly read a int8_t value from the virtual file pointer", function()
			local int8Val = 123
			local fileContents = buffer.new(1):putcdata(ffi.new("int8_t[1]", int8Val), 1)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetInt8(), int8Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetInt8()
			end

			local expectedErrorMessage = getExpectedReadFaultError(1, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)

	describe("GetUnsignedInt8", function()
		it("should correctly read a uint8_t value from the virtual file pointer", function()
			local uint8Val = 123
			local fileContents = buffer.new(1):putcdata(ffi.new("uint8_t[1]", uint8Val), 1)
			local reader = BinaryReader(fileContents)
			assertEquals(reader:GetUnsignedInt8(), uint8Val)
		end)

		it("should throw if no more input bytes can be read", function()
			local fileContents = buffer.new(42):put("")
			local reader = BinaryReader(fileContents)
			local function attemptToReadBeyondEOF()
				reader:GetUnsignedInt8()
			end

			local expectedErrorMessage = getExpectedReadFaultError(1, 0, 0)
			assertThrows(attemptToReadBeyondEOF, expectedErrorMessage)
		end)
	end)
end)
