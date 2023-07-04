local ffi = require("ffi")
local glfw = require("glfw")
local interop = require("interop")

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
			printf("Processing %d new window event(s)", eventCount)
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
	print("MOUSECLICK_STATUS_UPDATED")
end

function NativeClient:CURSOR_MOVED(eventID, payload)
	print("CURSOR_MOVED")
end

function NativeClient:MOUSEOVER_STATUS_CHANGED(eventID, payload)
	print("MOUSEOVER_STATUS_CHANGED")
end

function NativeClient:SCROLL_STATUS_CHANGED(eventID, payload)
	print("SCROLL_STATUS_CHANGED")
end

function NativeClient:KEYPRESS_STATUS_CHANGED(eventID, payload)
	print("KEYPRESS_STATUS_CHANGED")
end

function NativeClient:UNICODE_INPUT_RECEIVED(eventID, payload)
	print("UNICODE_INPUT_RECEIVED")
end

return NativeClient
