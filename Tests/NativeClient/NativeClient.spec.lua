local ffi = require("ffi")
local glfw = require("glfw")

local C_Camera = require("Core.NativeClient.C_Camera")
local C_Cursor = require("Core.NativeClient.C_Cursor")
local NativeClient = require("Core.NativeClient.NativeClient")
local Vector3D = require("Core.VectorMath.Vector3D")

describe("NativeClient", function()
	describe("CURSOR_MOVED", function()
		it("should save the screen space coordinates of the cursor", function()
			local event = ffi.new("deferred_event_t")
			event.cursor_move_details.x = 42
			event.cursor_move_details.y = 123

			NativeClient:CURSOR_MOVED("CURSOR_MOVED", event)

			local x, y = C_Cursor.GetLastKnownPosition()
			assertEquals(x, 42)
			assertEquals(y, 123)

			C_Cursor.SetLastKnownPosition(nil, nil)
		end)

		it("should leave the horizontal camera angle unchanged if the view isn't being adjusted", function()
			C_Camera.StopAdjustingView()

			local event = ffi.new("deferred_event_t")
			event.cursor_move_details.x = 400
			event.cursor_move_details.y = 500
			NativeClient:CURSOR_MOVED("CURSOR_MOVED", event)

			-- First move -> No delta available -> Camera angle shouldn't be changed
			local deltaX, deltaY = C_Cursor.GetDelta()
			assertEquals(deltaX, 0)
			assertEquals(deltaY, 0)
			assertEquals(C_Camera.GetHorizontalRotationAngle(), C_Camera.DEFAULT_HORIZONTAL_ROTATION)

			event.cursor_move_details.x = 440
			event.cursor_move_details.y = 501
			NativeClient:CURSOR_MOVED("CURSOR_MOVED", event)
			-- Second move -> Delta available, but shouldn't be applied
			assertEquals(C_Camera.GetHorizontalRotationAngle(), C_Camera.DEFAULT_HORIZONTAL_ROTATION)

			C_Cursor.SetLastKnownPosition(nil, nil)
		end)

		it(
			"should update the horizontal camera angle according to the cursor's delta if the view is being adjusted",
			function()
				C_Camera.StartAdjustingView()

				local event = ffi.new("deferred_event_t")
				event.cursor_move_details.x = 400
				event.cursor_move_details.y = 500
				NativeClient:CURSOR_MOVED("CURSOR_MOVED", event)

				-- First move -> No delta available -> Camera angle shouldn't be changed
				local deltaX, deltaY = C_Cursor.GetDelta()
				assertEquals(deltaX, 0)
				assertEquals(deltaY, 0)
				assertEquals(C_Camera.GetHorizontalRotationAngle(), C_Camera.DEFAULT_HORIZONTAL_ROTATION)

				event.cursor_move_details.x = 440
				event.cursor_move_details.y = 501
				NativeClient:CURSOR_MOVED("CURSOR_MOVED", event)
				-- Second move -> Apply delta to adjust the horizontal angle
				deltaX = C_Cursor.GetDelta()
				assertEquals(C_Camera.GetHorizontalRotationAngle(), C_Camera.DEFAULT_HORIZONTAL_ROTATION + deltaX)

				C_Camera.StopAdjustingView()
				C_Camera.ResetView()
				C_Cursor.SetLastKnownPosition(nil, nil)
			end
		)
	end)

	describe("MOUSECLICK_STATUS_UPDATED", function()
		it("should enable camera rotations if the right mouse button is pressed", function()
			local event = ffi.new("deferred_event_t")
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")

			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertTrue(C_Camera.IsAdjustingView())
		end)

		it("should disable camera rotations if the right mouse button is released", function()
			local event = ffi.new("deferred_event_t")
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")

			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertFalse(C_Camera.IsAdjustingView())
		end)

		it(
			"should reset the horizontal camera rotation if the right mouse button is pressed while CTRL is active",
			function()
				local event = ffi.new("deferred_event_t")
				C_Cursor.SetClickTime(-2 * C_Cursor.DOUBLE_CLICK_TIME_IN_MILLISECONDS * 10E5)
				C_Camera.ApplyHorizontalRotation(37) -- Arbitrary non-default rotation

				-- RCLICK received -> should reset camera since SHIFT is still down
				event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
				event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
				event.mouse_button_details.mods = glfw.bindings.glfw_find_constant("GLFW_MOD_CONTROL")
				NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

				assertEquals(C_Camera.GetHorizontalRotationAngle(), C_Camera.DEFAULT_HORIZONTAL_ROTATION)

				-- Don't care about this, but should reset to a blank slate anyway
				event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
				event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")
				event.mouse_button_details.mods = glfw.bindings.glfw_find_constant("GLFW_MOD_CONTROL")
				NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)
			end
		)

		it("should reset the horizontal camera rotation if the right mouse button is double-clicked", function()
			local event = ffi.new("deferred_event_t")
			C_Cursor.SetClickTime(-2 * C_Cursor.DOUBLE_CLICK_TIME_IN_MILLISECONDS * 10E5)
			C_Camera.ApplyHorizontalRotation(37) -- Arbitrary non-default rotation

			-- RCLICK received -> should await second click
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertFalse(C_Camera.GetHorizontalRotationAngle() == C_Camera.DEFAULT_HORIZONTAL_ROTATION)

			-- Another RCLICK received -> should reset angle
			-- Near-zero delay is inhumanely fast, so it should always be considered a double-click
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertEquals(C_Camera.GetHorizontalRotationAngle(), C_Camera.DEFAULT_HORIZONTAL_ROTATION)
		end)

		it("should not reset the horizontal camera rotation if a right-click follows a left click", function()
			local event = ffi.new("deferred_event_t")
			C_Cursor.SetClickTime(-2 * C_Cursor.DOUBLE_CLICK_TIME_IN_MILLISECONDS * 10E5)
			C_Camera.ApplyHorizontalRotation(37) -- Arbitrary non-default rotation

			-- RCLICK received -> should await second click
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_LEFT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_LEFT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertFalse(C_Camera.GetHorizontalRotationAngle() == C_Camera.DEFAULT_HORIZONTAL_ROTATION)

			-- Another RCLICK received -> should reset angle
			-- Near-zero delay is inhumanely fast, so it should always be considered a double-click
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertFalse(C_Camera.GetHorizontalRotationAngle() == C_Camera.DEFAULT_HORIZONTAL_ROTATION)
		end)

		it("should not reset the horizontal camera rotation if a right-click follows a release", function()
			local event = ffi.new("deferred_event_t")
			C_Cursor.SetClickTime(-2 * C_Cursor.DOUBLE_CLICK_TIME_IN_MILLISECONDS * 10E5)
			C_Camera.ApplyHorizontalRotation(37) -- Arbitrary non-default rotation

			-- RBUTTON released (here implied: a long time after it was first pressed)
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertFalse(C_Camera.GetHorizontalRotationAngle() == C_Camera.DEFAULT_HORIZONTAL_ROTATION)

			-- Another RCLICK received -> should NOT reset angle since the original GLFW_PRESS no longer counts
			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)

			assertFalse(C_Camera.GetHorizontalRotationAngle() == C_Camera.DEFAULT_HORIZONTAL_ROTATION)

			event.mouse_button_details.button = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
			event.mouse_button_details.action = glfw.bindings.glfw_find_constant("GLFW_RELEASE")
			NativeClient:MOUSECLICK_STATUS_UPDATED("MOUSECLICK_STATUS_UPDATED", event)
		end)
	end)

	describe("SCROLL_STATUS_CHANGED", function()
		local originalControlKeyHandler, originalShiftKeyHandler
		before(function()
			originalControlKeyHandler = NativeClient.IsControlKeyDown
			originalShiftKeyHandler = NativeClient.IsShiftKeyDown

			NativeClient.IsControlKeyDown = function()
				return false
			end

			NativeClient.IsShiftKeyDown = function()
				return false
			end
		end)

		after(function()
			NativeClient.IsControlKeyDown = originalControlKeyHandler
			NativeClient.IsShiftKeyDown = originalShiftKeyHandler
			C_Camera.ResetView()
			C_Camera.ResetZoom()
		end)

		it("should not change the zoom level if CTRL is held while scrolling up", function()
			NativeClient.IsControlKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetOrbitDistance(), C_Camera.DEFAULT_ORBIT_DISTANCE)
		end)

		it("should not change the zoom level if CTRL is held while scrolling down", function()
			NativeClient.IsControlKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetOrbitDistance(), C_Camera.DEFAULT_ORBIT_DISTANCE)
		end)

		it("should not change the zoom level if SHIFT is held while scrolling up", function()
			NativeClient.IsShiftKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetOrbitDistance(), C_Camera.DEFAULT_ORBIT_DISTANCE)
		end)

		it("should not change the zoom level if SHIFT is held while scrolling down", function()
			NativeClient.IsShiftKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetOrbitDistance(), C_Camera.DEFAULT_ORBIT_DISTANCE)
		end)

		it(
			"should zoom in the camera if scrolling down while the orbit radius is above the configured minimum",
			function()
				local event = ffi.new("deferred_event_t")
				event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
				event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
				NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

				assertEquals(
					C_Camera.GetOrbitDistance(),
					C_Camera.DEFAULT_ORBIT_DISTANCE - C_Camera.DEGREES_PER_ZOOM_LEVEL
				)
			end
		)

		it("should not zoom in the camera below the configured minimum orbit radius if scrolling down", function()
			C_Camera.SetOrbitDistance(C_Camera.MIN_ORBIT_DISTANCE + 1)

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetOrbitDistance(), C_Camera.MIN_ORBIT_DISTANCE)
		end)

		it(
			"should not change the zoom level if scrolling down while the orbit radius is at the configured minimum",
			function()
				C_Camera.SetOrbitDistance(C_Camera.MIN_ORBIT_DISTANCE)

				local event = ffi.new("deferred_event_t")
				event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
				event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
				NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

				assertEquals(C_Camera.GetOrbitDistance(), C_Camera.MIN_ORBIT_DISTANCE)
			end
		)

		it(
			"should zoom out the camera if scrolling up while the orbit radius is below the configured maximum",
			function()
				local event = ffi.new("deferred_event_t")
				event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
				event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
				NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

				assertEquals(
					C_Camera.GetOrbitDistance(),
					C_Camera.DEFAULT_ORBIT_DISTANCE + C_Camera.DEGREES_PER_ZOOM_LEVEL
				)
			end
		)

		it("should not zoom out the camera beyond the configured maximum orbit radius if scrolling up", function()
			C_Camera.SetOrbitDistance(C_Camera.MAX_ORBIT_DISTANCE - 1)

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetOrbitDistance(), C_Camera.MAX_ORBIT_DISTANCE)
		end)

		it(
			"should not change the zoom level if scrolling up while the orbit radius is at the configured maximum",
			function()
				C_Camera.SetOrbitDistance(C_Camera.MAX_ORBIT_DISTANCE)

				local event = ffi.new("deferred_event_t")
				event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
				event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
				NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

				assertEquals(C_Camera.GetOrbitDistance(), C_Camera.MAX_ORBIT_DISTANCE)
			end
		)

		it("should not change the vertical rotation angle if SHIFT is not held while scrolling up", function()
			NativeClient.IsShiftKeyDown = function()
				return false
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetVerticalRotationAngle(), C_Camera.DEFAULT_VERTICAL_ROTATION)
		end)

		it("should not change the vertical rotation angle if SHIFT is not held while scrolling down", function()
			NativeClient.IsShiftKeyDown = function()
				return false
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetVerticalRotationAngle(), C_Camera.DEFAULT_VERTICAL_ROTATION)
		end)

		it("should increase the vertical rotation angle if SHIFT is held while scrolling down", function()
			NativeClient.IsShiftKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(
				C_Camera.GetVerticalRotationAngle(),
				C_Camera.DEFAULT_VERTICAL_ROTATION + C_Camera.DEGREES_PER_ZOOM_LEVEL
			)
		end)

		it("should decrease the vertical rotation angle if SHIFT is held while scrolling up", function()
			C_Camera.ApplyVerticalRotation(
				C_Camera.MAX_VERTICAL_ROTATION - C_Camera.DEFAULT_VERTICAL_ROTATION - C_Camera.DEGREES_PER_ZOOM_LEVEL
			)
			NativeClient.IsShiftKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(
				C_Camera.GetVerticalRotationAngle(),
				C_Camera.MAX_VERTICAL_ROTATION - 2 * C_Camera.DEGREES_PER_ZOOM_LEVEL
			)
		end)

		it("should cap the vertical rotation angle at the configured maximum when scrolling down", function()
			C_Camera.ApplyVerticalRotation(C_Camera.MAX_VERTICAL_ROTATION - C_Camera.DEFAULT_VERTICAL_ROTATION - 1)

			NativeClient.IsShiftKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetVerticalRotationAngle(), C_Camera.MAX_VERTICAL_ROTATION)
		end)

		it("should cap the vertical rotation angle at the configured minimum when scrolling up", function()
			C_Camera.ApplyVerticalRotation(C_Camera.MIN_VERTICAL_ROTATION - C_Camera.DEFAULT_VERTICAL_ROTATION + 1)

			NativeClient.IsShiftKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetVerticalRotationAngle(), C_Camera.MIN_VERTICAL_ROTATION)
		end)

		it("should not change the rotation angle if it's already at the configured minimum", function()
			C_Camera.ApplyVerticalRotation(C_Camera.MIN_VERTICAL_ROTATION - C_Camera.DEFAULT_VERTICAL_ROTATION)

			NativeClient.IsShiftKeyDown = function()
				return true
			end

			local event = ffi.new("deferred_event_t")
			event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
			event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_UP
			NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

			assertEquals(C_Camera.GetVerticalRotationAngle(), C_Camera.MIN_VERTICAL_ROTATION)
		end)

		it(
			"should not change the rotation angle if it's already at the configured maximum when scrolling down",
			function()
				C_Camera.ApplyVerticalRotation(C_Camera.MAX_VERTICAL_ROTATION - C_Camera.DEFAULT_VERTICAL_ROTATION)

				NativeClient.IsShiftKeyDown = function()
					return true
				end

				local event = ffi.new("deferred_event_t")
				event.scroll_details.x = C_Cursor.SCROLL_DIRECTION_NONE
				event.scroll_details.y = C_Cursor.SCROLL_DIRECTION_DOWN
				NativeClient:SCROLL_STATUS_CHANGED("SCROLL_STATUS_CHANGED", event)

				assertEquals(C_Camera.GetVerticalRotationAngle(), C_Camera.MAX_VERTICAL_ROTATION)
			end
		)
	end)

	describe("KEYPRESS_STATUS_CHANGED", function()
		local originalCameraTarget = C_Camera.GetTargetPosition()
		after(function()
			C_Camera.SetTargetPosition(originalCameraTarget)
		end)

		it("should adjust the camera target if SHIFT + LEFT was pressed", function()
			local event = ffi.new("deferred_event_t")
			event.key_details.key = glfw.bindings.glfw_find_constant("GLFW_KEY_LEFT")
			event.key_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			event.key_details.mods = glfw.bindings.glfw_find_constant("GLFW_MOD_SHIFT")

			NativeClient:KEYPRESS_STATUS_CHANGED("KEYPRESS_STATUS_CHANGED", event)

			local newCameraTarget = C_Camera.GetTargetPosition()
			local expectedTranslation = Vector3D(-C_Camera.TARGET_DEBUG_STEPSIZE_IN_WORLD_UNITS, 0, 0)
			local expectedCameraTarget = originalCameraTarget:Add(expectedTranslation)

			assertEquals(newCameraTarget.x, expectedCameraTarget.x)
			assertEquals(newCameraTarget.y, expectedCameraTarget.y)
			assertEquals(newCameraTarget.z, expectedCameraTarget.z)
		end)

		it("should adjust the camera target if SHIFT + RIGHT was pressed", function()
			local event = ffi.new("deferred_event_t")
			event.key_details.key = glfw.bindings.glfw_find_constant("GLFW_KEY_RIGHT")
			event.key_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			event.key_details.mods = glfw.bindings.glfw_find_constant("GLFW_MOD_SHIFT")

			NativeClient:KEYPRESS_STATUS_CHANGED("KEYPRESS_STATUS_CHANGED", event)

			local newCameraTarget = C_Camera.GetTargetPosition()
			local expectedTranslation = Vector3D(C_Camera.TARGET_DEBUG_STEPSIZE_IN_WORLD_UNITS, 0, 0)
			local expectedCameraTarget = originalCameraTarget:Add(expectedTranslation)

			assertEquals(newCameraTarget.x, expectedCameraTarget.x)
			assertEquals(newCameraTarget.y, expectedCameraTarget.y)
			assertEquals(newCameraTarget.z, expectedCameraTarget.z)
		end)

		it("should adjust the camera target if SHIFT + UP was pressed", function()
			local event = ffi.new("deferred_event_t")
			event.key_details.key = glfw.bindings.glfw_find_constant("GLFW_KEY_UP")
			event.key_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			event.key_details.mods = glfw.bindings.glfw_find_constant("GLFW_MOD_SHIFT")

			NativeClient:KEYPRESS_STATUS_CHANGED("KEYPRESS_STATUS_CHANGED", event)

			local newCameraTarget = C_Camera.GetTargetPosition()
			local expectedTranslation = Vector3D(0, 0, C_Camera.TARGET_DEBUG_STEPSIZE_IN_WORLD_UNITS)
			local expectedCameraTarget = originalCameraTarget:Add(expectedTranslation)

			assertEquals(newCameraTarget.x, expectedCameraTarget.x)
			assertEquals(newCameraTarget.y, expectedCameraTarget.y)
			assertEquals(newCameraTarget.z, expectedCameraTarget.z)
		end)

		it("should adjust the camera target if SHIFT + DOWN was pressed", function()
			local event = ffi.new("deferred_event_t")
			event.key_details.key = glfw.bindings.glfw_find_constant("GLFW_KEY_DOWN")
			event.key_details.action = glfw.bindings.glfw_find_constant("GLFW_PRESS")
			event.key_details.mods = glfw.bindings.glfw_find_constant("GLFW_MOD_SHIFT")

			NativeClient:KEYPRESS_STATUS_CHANGED("KEYPRESS_STATUS_CHANGED", event)

			local newCameraTarget = C_Camera.GetTargetPosition()
			local expectedTranslation = Vector3D(0, 0, -C_Camera.TARGET_DEBUG_STEPSIZE_IN_WORLD_UNITS)
			local expectedCameraTarget = originalCameraTarget:Add(expectedTranslation)

			assertEquals(newCameraTarget.x, expectedCameraTarget.x)
			assertEquals(newCameraTarget.y, expectedCameraTarget.y)
			assertEquals(newCameraTarget.z, expectedCameraTarget.z)
		end)
	end)
end)
