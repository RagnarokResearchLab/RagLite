local C_Cursor = {
	screenSpaceCoordinates = {
		x = nil,
		y = nil,
		lastX = nil,
		lastY = nil,
	},
	DOUBLE_CLICK_TIME_IN_MILLISECONDS = 400,
	lastClickTime = 0,
}

function C_Cursor.GetLastKnownPosition()
	return C_Cursor.screenSpaceCoordinates.x, C_Cursor.screenSpaceCoordinates.y
end

function C_Cursor.SetLastKnownPosition(newX, newY)
	C_Cursor.screenSpaceCoordinates.lastX = C_Cursor.screenSpaceCoordinates.x
	C_Cursor.screenSpaceCoordinates.lastY = C_Cursor.screenSpaceCoordinates.y

	C_Cursor.screenSpaceCoordinates.x = newX
	C_Cursor.screenSpaceCoordinates.y = newY
end

function C_Cursor.GetDelta()
	if not C_Cursor.screenSpaceCoordinates.x or not C_Cursor.screenSpaceCoordinates.y then
		return
	end

	if not C_Cursor.screenSpaceCoordinates.lastX or not C_Cursor.screenSpaceCoordinates.lastY then
		return 0, 0
	end

	local deltaX = C_Cursor.screenSpaceCoordinates.x - C_Cursor.screenSpaceCoordinates.lastX
	local deltaY = C_Cursor.screenSpaceCoordinates.y - C_Cursor.screenSpaceCoordinates.lastY

	return deltaX, deltaY
end

function C_Cursor.GetLastClickTime()
	return C_Cursor.lastClickTime
end

function C_Cursor.IsWithinDoubleClickInterval(now)
	local millisecondsSinceLastClick = (now - C_Cursor.lastClickTime) / 10E5
	return millisecondsSinceLastClick < C_Cursor.DOUBLE_CLICK_TIME_IN_MILLISECONDS
end

function C_Cursor.SetClickTime(now)
	C_Cursor.lastClickTime = now
end

return C_Cursor
