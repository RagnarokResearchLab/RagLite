local C_Cursor = require("Core.NativeClient.C_Cursor")

describe("C_Cusor", function()
	describe("GetLastKnownPosition", function()
		it("should return nil if no cursor events have been received yet", function()
			local x, y = C_Cursor.GetLastKnownPosition()
			assertEquals(x, nil)
			assertEquals(y, nil)
		end)
	end)

	describe("SetLastKnownPosition", function()
		it("should store the new screen space coordinates of the cursor", function()
			local oldX, oldY = C_Cursor.GetLastKnownPosition()
			C_Cursor.SetLastKnownPosition(123, 543)
			local newX, newY = C_Cursor.GetLastKnownPosition()

			assertEquals(newX, 123)
			assertEquals(newY, 543)

			assertTrue(oldX ~= newX)
			assertTrue(oldY ~= newY)

			C_Cursor.SetLastKnownPosition(nil, nil)
		end)
	end)

	describe("GetDelta", function()
		it("should return nil if no cursor events have been received yet", function()
			local x, y = C_Cursor.GetDelta()
			assertEquals(x, nil)
			assertEquals(y, nil)
		end)

		it("should return zero if a only single cursor event has been received", function()
			local x, y = C_Cursor.GetDelta()
			assertEquals(x, nil)
			assertEquals(y, nil)

			C_Cursor.SetLastKnownPosition(13, 37)

			x, y = C_Cursor.GetDelta()
			assertEquals(x, 0)
			assertEquals(y, 0)

			C_Cursor.SetLastKnownPosition(nil, nil)
		end)

		it("should return the computed delta if at least two cursor events have been received", function()
			C_Cursor.SetLastKnownPosition(100, 200)
			C_Cursor.SetLastKnownPosition(125, 250)

			local x, y = C_Cursor.GetDelta()
			assertEquals(x, 25)
			assertEquals(y, 50)

			C_Cursor.SetLastKnownPosition(nil, nil)
		end)
	end)
end)
