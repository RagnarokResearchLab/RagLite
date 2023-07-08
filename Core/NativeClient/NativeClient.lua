local ffi = require("ffi")
local glfw = require("glfw")
local interop = require("interop")
local uv = require("uv")

local C_Camera = require("Core.NativeClient.C_Camera")
local C_Cursor = require("Core.NativeClient.C_Cursor")
local Renderer = require("Core.NativeClient.Renderer")

local tonumber = tonumber

local NativeClient = {
	mainWindow = nil,
	graphicsContext = nil,
	deferredEventQueue = nil,
}

function NativeClient:Start()
	self.mainWindow = self:CreateMainWindow()
	self.graphicsContext = Renderer:CreateGraphicsContext(self.mainWindow)
	Renderer:CreatePipelineConfigurations(self.graphicsContext)
	Renderer:CreateUniformBuffer(self.graphicsContext)
	Renderer:EnableDepthBuffer(self.graphicsContext)

	-- Hardcoded for now, replace with actual geometry later
	local PYRAMID_VERTEX_COUNT = 5
	local ARROWHEAD_VERTEX_COUNT = 3
	local vertexPositions = {
		-- Base of the pyramid (square)
		-0.5,
		0.0,
		-0.5, -- bottom-left corner
		0.5,
		0.0,
		-0.5, -- bottom-right corner
		0.5,
		0.0,
		0.5, -- top-right corner
		-0.5,
		0.0,
		0.5, -- top-left corner

		-- Tip of the pyramid
		0.0,
		1.0,
		0.0, -- top center

		-- X-Axis Visualization
		0.0,
		0.0,
		0.0, -- Bottom-left
		2.0,
		0.0,
		0.0, -- Bottom-right
		2.0,
		0.05,
		0.0, -- Top-right
		0.0,
		0.05,
		0.0, -- Top-left
		2.0,
		0.1,
		0, -- Arrowhead.Top
		2.0,
		-0.05,
		0, -- Arrowhead.Bottm
		2.25,
		0.05 / 2,
		0, -- Arrowhead.Tip

		-- Y-Axis Visualization
		0.0,
		0.0,
		0.0, -- Bottom-left
		0.05,
		0.0,
		0.0, -- Bottom-right
		0.05,
		2.0,
		0.0, -- Top-right
		0.0,
		2.0,
		0.0, -- Top-left
		-0.05,
		2,
		0, -- Arrowhead.Top
		0.1,
		2,
		0, -- Arrowhead.Bottom
		0.05 / 2,
		2.25,
		0, -- Arrowhead.Tip

		-- Z-Axis Visualization
		0.0,
		0.0,
		0.0, -- Bottom-left
		0.0,
		0.0,
		2.0, -- Bottom-right
		0.0,
		0.05,
		2.0, -- Top-right
		0.0,
		0.05,
		0.0, -- Top-left
		0,
		0.1,
		2, -- Arrowhead.Top
		0,
		-0.05,
		2, -- Arrowhead.Bottom
		0,
		0.05 / 2,
		2.25, -- Arrowhead.Tip
	}

	local vertexColorsRGB = {
		1.0,
		1.0,
		1.0, -- base color
		1.0,
		1.0,
		1.0,
		1.0,
		1.0,
		1.0,
		1.0,
		1.0,
		1.0,
		0.25,
		0.25,
		0.25, -- tip color

		-- X-Axis (Red)
		1.0,
		0.0,
		0.0, -- Bottom-left
		1.0,
		0.0,
		0.0, -- Bottom-right
		1.0,
		0.0,
		0.0, -- Top-right
		1.0,
		0.0,
		0.0, -- Top-left
		1.0,
		0,
		0,
		1.0,
		0,
		0,
		1.0,
		0,
		0,
		-- Arrowhead

		-- Y-Axis (Green)
		0.0,
		1.0,
		0.0, -- Bottom-left
		0.0,
		1.0,
		0.0, -- Bottom-right
		0.0,
		1.0,
		0.0, -- Top-right
		0.0,
		1.0,
		0.0, -- Top-left
		0,
		1.0,
		0,
		0,
		1.0,
		0,
		0,
		1.0,
		0,
		-- Arrowhead

		-- Z-Axis (Blue)
		0.0,
		0.0,
		1.0, -- Bottom-left
		0.0,
		0.0,
		1.0, -- Bottom-right
		0.0,
		0.0,
		1.0, -- Top-right
		0.0,
		0.0,
		1.0, -- Top-left
		0.0,
		0.0,
		1.0,
		0.0,
		0.0,
		1.0,
		0.0,
		0.0,
		1.0, -- Arrowhead
	}

	local triangleIndices = {
		0,
		1,
		4, -- bottom-right triangle
		1,
		2,
		4, -- right triangle
		2,
		3,
		4, -- top triangle
		3,
		0,
		4, -- left triangle
		3,
		1,
		0, -- base triangle 1
		3,
		2,
		1, -- base triangle 2

		-- X Axis
		PYRAMID_VERTEX_COUNT + 0,
		PYRAMID_VERTEX_COUNT + 1,
		PYRAMID_VERTEX_COUNT + 2,
		PYRAMID_VERTEX_COUNT + 0,
		PYRAMID_VERTEX_COUNT + 2,
		PYRAMID_VERTEX_COUNT + 3,
		PYRAMID_VERTEX_COUNT + 3 + 1,
		PYRAMID_VERTEX_COUNT + 3 + 2,
		PYRAMID_VERTEX_COUNT + 3 + 3,

		-- Y Axis
		PYRAMID_VERTEX_COUNT
			+ 3
			+ 4,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 5,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 6,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 4,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 6,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 7,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 7 + 1,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 7 + 2,
		PYRAMID_VERTEX_COUNT + ARROWHEAD_VERTEX_COUNT + 7 + 3,

		-- Z Axis
		PYRAMID_VERTEX_COUNT
			+ 3
			+ 3
			+ 8,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 9,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 10,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 8,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 10,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 11,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 12,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 13,
		PYRAMID_VERTEX_COUNT + 2 * ARROWHEAD_VERTEX_COUNT + 14,
	}

	Renderer:UploadGeometry(self.graphicsContext, vertexPositions, triangleIndices, vertexColorsRGB)

	self:StartRenderLoop()
end

function NativeClient:Stop()
	glfw.bindings.glfw_destroy_window(self.mainWindow)
	glfw.bindings.glfw_terminate()
end

function NativeClient:CreateMainWindow()
	if not glfw.bindings.glfw_init() then
		error("Failed to initialize windowing context")
	end

	-- Default to windowed fullscreen mode as switching the display settings is too disruptive for development
	local primaryMonitor = glfw.bindings.glfw_get_primary_monitor()
	local videoMode = glfw.bindings.glfw_get_video_mode(primaryMonitor)
	local GLFW_RED_BITS = glfw.bindings.glfw_find_constant("GLFW_RED_BITS")
	local GLFW_GREEN_BITS = glfw.bindings.glfw_find_constant("GLFW_GREEN_BITS")
	local GLFW_BLUE_BITS = glfw.bindings.glfw_find_constant("GLFW_BLUE_BITS")
	local GLFW_REFRESH_RATE = glfw.bindings.glfw_find_constant("GLFW_REFRESH_RATE")

	glfw.bindings.glfw_window_hint(GLFW_RED_BITS, videoMode.redBits)
	glfw.bindings.glfw_window_hint(GLFW_GREEN_BITS, videoMode.greenBits)
	glfw.bindings.glfw_window_hint(GLFW_BLUE_BITS, videoMode.blueBits)
	glfw.bindings.glfw_window_hint(GLFW_REFRESH_RATE, videoMode.refreshRate)

	-- Disable the builtin OpenGL and Vulkan context since we'll be using WebGPU (custom extension)
	local GLFW_CLIENT_API = glfw.bindings.glfw_find_constant("GLFW_CLIENT_API")
	local GLFW_NO_API = glfw.bindings.glfw_find_constant("GLFW_NO_API")
	glfw.bindings.glfw_window_hint(GLFW_CLIENT_API, GLFW_NO_API)

	-- Resizing the window means recreating a whole bunch of stuff (swap chain, buffers, ...) - let's sidestep all that for now
	local GLFW_RESIZABLE = glfw.bindings.glfw_find_constant("GLFW_RESIZABLE")
	local GLFW_FALSE = glfw.bindings.glfw_find_constant("GLFW_FALSE")
	glfw.bindings.glfw_window_hint(GLFW_RESIZABLE, GLFW_FALSE)

	local window = glfw.bindings.glfw_create_window(videoMode.width, videoMode.height, "RagLite", nil, nil)
	if not window then
		error("Failed to create application window")
	end

	glfw.bindings.glfw_set_window_pos(window, 0, 0)
	self.deferredEventQueue = interop.bindings.queue_create()
	glfw.bindings.glfw_register_events(window, self.deferredEventQueue)

	return window
end

function NativeClient:StartRenderLoop()
	while glfw.bindings.glfw_window_should_close(self.mainWindow) == 0 do
		glfw.bindings.glfw_poll_events()
		self:ProcessWindowEvents()
		Renderer:RenderNextFrame(self.graphicsContext)
	end
end

function NativeClient:GetMainWindow()
	return self.mainWindow
end

function NativeClient:ProcessWindowEvents()
	local eventCount
	repeat
		eventCount = tonumber(interop.bindings.queue_size(self.deferredEventQueue))

		if eventCount > 0 then
			local eventInfo = interop.bindings.queue_pop_event(self.deferredEventQueue)
			self:ReplayDeferredEvent(eventInfo)
		end
	until eventCount == 0
end

local glfwEventNames = {
	[ffi.C.ERROR_EVENT] = "UNKNOWN_WINDOW_EVENT_ENCOUNTERED",
	[ffi.C.WINDOW_MOVE_EVENT] = "APPLICATION_WINDOW_MOVED",
	[ffi.C.WINDOW_RESIZE_EVENT] = "APPLICATION_WINDOW_RESIZED",
	[ffi.C.WINDOW_CLOSE_EVENT] = "APPLICATION_WINDOW_CLOSED",
	[ffi.C.FRAMEBUFFER_RESIZE_EVENT] = "FRAMEBUFFER_SIZE_CHANGED",
	[ffi.C.CONTENT_SCALE_EVENT] = "CONTENT_SCALE_CHANGED",
	[ffi.C.WINDOW_REFRESH_EVENT] = "CONTENT_COMPOSITION_DAMAGED",
	[ffi.C.WINDOW_FOCUS_EVENT] = "APPLICATION_WINDOW_FOCUS_CHANGED",
	[ffi.C.WINDOW_ICONIFY_EVENT] = "APPLICATION_WINDOW_ICON_CHANGED",
	[ffi.C.WINDOW_MAXIMIZE_EVENT] = "APPLICATION_WINDOW_MAXIMIZED",
	[ffi.C.MOUSE_BUTTON_EVENT] = "MOUSECLICK_STATUS_UPDATED",
	[ffi.C.CURSOR_MOVE_EVENT] = "CURSOR_MOVED",
	[ffi.C.CURSOR_ENTER_EVENT] = "MOUSEOVER_STATUS_CHANGED",
	[ffi.C.SCROLL_EVENT] = "SCROLL_STATUS_CHANGED",
	[ffi.C.KEYBOARD_EVENT] = "KEYPRESS_STATUS_CHANGED",
	[ffi.C.CHARACTER_INPUT_EVENT] = "UNICODE_INPUT_RECEIVED",
}

function NativeClient:ReplayDeferredEvent(eventInfo)
	local event = ffi.cast("error_event_t*", eventInfo)

	local eventName = glfwEventNames[event.type] or glfwEventNames[ffi.C.ERROR_EVENT]
	local eventHandler = self[eventName]

	eventHandler(self, eventName, eventInfo)
end

function NativeClient:UNKNOWN_WINDOW_EVENT_ENCOUNTERED(eventID, payload)
	print("UNKNOWN_WINDOW_EVENT_ENCOUNTERED")
end

function NativeClient:APPLICATION_WINDOW_MOVED(eventID, payload)
	print("APPLICATION_WINDOW_MOVED")
end

function NativeClient:APPLICATION_WINDOW_RESIZED(eventID, payload)
	print("APPLICATION_WINDOW_RESIZED")
end

function NativeClient:APPLICATION_WINDOW_CLOSED(eventID, payload)
	print("APPLICATION_WINDOW_CLOSED")
end

function NativeClient:FRAMEBUFFER_SIZE_CHANGED(eventID, payload)
	print("FRAMEBUFFER_SIZE_CHANGED")
end

function NativeClient:CONTENT_SCALE_CHANGED(eventID, payload)
	print("CONTENT_SCALE_CHANGED")
end

function NativeClient:CONTENT_COMPOSITION_DAMAGED(eventID, payload)
	print("CONTENT_COMPOSITION_DAMAGED")
end

function NativeClient:APPLICATION_WINDOW_FOCUS_CHANGED(eventID, payload)
	print("APPLICATION_WINDOW_FOCUS_CHANGED")
end

function NativeClient:APPLICATION_WINDOW_ICON_CHANGED(eventID, payload)
	print("APPLICATION_WINDOW_ICON_CHANGED")
end

function NativeClient:APPLICATION_WINDOW_MAXIMIZED(eventID, payload)
	print("APPLICATION_WINDOW_MAXIMIZED")
end

function NativeClient:MOUSECLICK_STATUS_UPDATED(eventID, payload)
	local GLFW_MOUSE_BUTTON_RIGHT = glfw.bindings.glfw_find_constant("GLFW_MOUSE_BUTTON_RIGHT")
	local GLFW_PRESS = glfw.bindings.glfw_find_constant("GLFW_PRESS")
	local GLFW_MOD_CONTROL = glfw.bindings.glfw_find_constant("GLFW_MOD_CONTROL")

	local isRightButton = (payload.mouse_button_details.button == GLFW_MOUSE_BUTTON_RIGHT)
	local wasButtonPressed = (payload.mouse_button_details.action == GLFW_PRESS)
	local wasControlKeyDown = (payload.mouse_button_details.mods == GLFW_MOD_CONTROL)

	-- Should probably use a proper FSM for more complex input sequences, but for now this will do
	local now = uv.hrtime()
	if isRightButton then
		if wasControlKeyDown and wasButtonPressed then
			C_Camera.ResetView()
		end

		if wasButtonPressed and C_Cursor.IsWithinDoubleClickInterval(now) then
			C_Camera.ResetView()
		end

		if wasButtonPressed then
			C_Camera.StartAdjustingView()
		else
			C_Camera.StopAdjustingView()
		end
		C_Cursor.SetClickTime(now)
	end
end

function NativeClient:CURSOR_MOVED(eventID, payload)
	C_Cursor.SetLastKnownPosition(payload.cursor_move_details.x, payload.cursor_move_details.y)

	if not C_Camera.IsAdjustingView() then
		return
	end

	C_Camera.ApplyHorizontalRotation(C_Cursor.GetDelta())
end

function NativeClient:MOUSEOVER_STATUS_CHANGED(eventID, payload)
	print("MOUSEOVER_STATUS_CHANGED")
end

function NativeClient:SCROLL_STATUS_CHANGED(eventID, payload)
	if self:IsControlKeyDown() then
		return
	end

	local isScrollingUp = (payload.scroll_details.y == C_Cursor.SCROLL_DIRECTION_UP)
	local isScrollingDown = (payload.scroll_details.y == C_Cursor.SCROLL_DIRECTION_DOWN)

	if isScrollingUp then
		C_Camera.ZoomOut()
	end

	if isScrollingDown then
		C_Camera.ZoomIn()
	end
end

function NativeClient:KEYPRESS_STATUS_CHANGED(eventID, payload)
	print("KEYPRESS_STATUS_CHANGED")
end

function NativeClient:UNICODE_INPUT_RECEIVED(eventID, payload)
	print("UNICODE_INPUT_RECEIVED")
end

function NativeClient:IsControlKeyDown()
	local GLFW_PRESS = glfw.bindings.glfw_find_constant("GLFW_PRESS")
	local GLFW_KEY_LEFT_CONTROL = glfw.bindings.glfw_find_constant("GLFW_KEY_LEFT_CONTROL")
	return (glfw.bindings.glfw_get_key(self.mainWindow, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS)
end

return NativeClient
