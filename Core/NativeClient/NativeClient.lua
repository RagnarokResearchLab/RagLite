local bit = require("bit")
local ffi = require("ffi")
local glfw = require("glfw")
local interop = require("interop")
local rml = require("rml")
local uv = require("uv")

local C_Camera = require("Core.NativeClient.C_Camera")
local C_Cursor = require("Core.NativeClient.C_Cursor")
local DebugScene = require("Core.NativeClient.DebugDraw.DebugScene")
local Renderer = require("Core.NativeClient.Renderer")
local Vector3D = require("Core.VectorMath.Vector3D")

local RagnarokGRF = require("Core.FileFormats.RagnarokGRF")
local RagnarokMap = require("Core.FileFormats.RagnarokMap")

local tonumber = tonumber

local NativeClient = {
	mainWindow = nil,
	deferredEventQueue = nil,
	-- Should probably move this to a dedicated Resources API (later)
	GRF_FILE_PATH = "data.grf",
	PERSISTENT_RESOURCES = {
		["data/sprite/cursors.act"] = false,
		["data/sprite/cursors.spr"] = false,
	},
	FALLBACK_SCENE_ID = "wgpu",
}

function NativeClient:Start(loginSceneID)
	self.mainWindow = self:CreateMainWindow()
	Renderer:InitializeWithGLFW(self.mainWindow)

	self:PreloadPersistentResources()
	self:LoadSceneByID(loginSceneID or self.FALLBACK_SCENE_ID)

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
		uv.run("nowait")
		glfw.bindings.glfw_poll_events()
		self:ProcessWindowEvents()
		Renderer:RenderNextFrame()
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

	local shouldProcessEvent = rml.bindings.rml_process_mouse_button_callback(
		Renderer.rmlContext,
		payload.mouse_button_details.button,
		payload.mouse_button_details.action,
		payload.mouse_button_details.mods
	)
	if not shouldProcessEvent then
		return
	end

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
			C_Cursor.SetClickTime(now)
		else
			C_Camera.StopAdjustingView()
		end
	end
end

function NativeClient:CURSOR_MOVED(eventID, payload)
	local shouldProcessEvent = rml.bindings.rml_process_cursor_pos_callback(
		Renderer.rmlContext,
		payload.cursor_move_details.x,
		payload.cursor_move_details.y,
		0
	) -- The modifiers aren't provided by GLFW here? Fix later if it turns out to be a problem...
	if not shouldProcessEvent then
		return
	end

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
	local isShiftKeyDown = self:IsShiftKeyDown()

	if isScrollingUp and not isShiftKeyDown then
		C_Camera.ZoomOut()
	end

	if isScrollingUp and isShiftKeyDown then
		C_Camera.ApplyVerticalRotation(-C_Camera.DEGREES_PER_ZOOM_LEVEL)
	end

	if isScrollingDown and not isShiftKeyDown then
		C_Camera.ZoomIn()
	end

	if isScrollingDown and isShiftKeyDown then
		C_Camera.ApplyVerticalRotation(C_Camera.DEGREES_PER_ZOOM_LEVEL)
	end
end

function NativeClient:KEYPRESS_STATUS_CHANGED(eventID, payload)
	local GLFW_KEY_LEFT = glfw.bindings.glfw_find_constant("GLFW_KEY_LEFT")
	local GLFW_KEY_RIGHT = glfw.bindings.glfw_find_constant("GLFW_KEY_RIGHT")
	local GLFW_KEY_DOWN = glfw.bindings.glfw_find_constant("GLFW_KEY_DOWN")
	local GLFW_KEY_UP = glfw.bindings.glfw_find_constant("GLFW_KEY_UP")
	local GLFW_MOD_SHIFT = glfw.bindings.glfw_find_constant("GLFW_MOD_SHIFT")
	local GLFW_PRESS = glfw.bindings.glfw_find_constant("GLFW_PRESS")
	local wasKeyPressed = tonumber(payload.key_details.action) == GLFW_PRESS
	if not wasKeyPressed then
		return
	end

	local isModifiedBySHIFT = bit.band(payload.key_details.mods, GLFW_MOD_SHIFT) == 1
	if not isModifiedBySHIFT then
		return
	end

	local wasLeftKey = payload.key_details.key == GLFW_KEY_LEFT
	local wasRightKey = payload.key_details.key == GLFW_KEY_RIGHT
	local wasUpKey = payload.key_details.key == GLFW_KEY_UP
	local wasDownKey = payload.key_details.key == GLFW_KEY_DOWN
	local movementDirectionX = wasLeftKey and -1 or 0
	movementDirectionX = wasRightKey and 1 or movementDirectionX
	local movementDirectionZ = wasUpKey and 1 or 0
	movementDirectionZ = wasDownKey and -1 or movementDirectionZ

	local movementDistanceInWorldUnits = C_Camera.TARGET_DEBUG_STEPSIZE_IN_WORLD_UNITS
	local translation = Vector3D(
		movementDirectionX * movementDistanceInWorldUnits,
		0,
		movementDirectionZ * movementDistanceInWorldUnits
	)
	C_Camera.targetWorldPosition = C_Camera.targetWorldPosition:Add(translation)
end

function NativeClient:UNICODE_INPUT_RECEIVED(eventID, payload)
	print("UNICODE_INPUT_RECEIVED")
end

function NativeClient:IsControlKeyDown()
	local GLFW_PRESS = glfw.bindings.glfw_find_constant("GLFW_PRESS")
	local GLFW_KEY_LEFT_CONTROL = glfw.bindings.glfw_find_constant("GLFW_KEY_LEFT_CONTROL")
	return (glfw.bindings.glfw_get_key(self.mainWindow, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS)
end

function NativeClient:IsShiftKeyDown()
	local GLFW_PRESS = glfw.bindings.glfw_find_constant("GLFW_PRESS")
	local GLFW_KEY_LEFT_SHIFT = glfw.bindings.glfw_find_constant("GLFW_KEY_LEFT_SHIFT")
	return (glfw.bindings.glfw_get_key(self.mainWindow, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS)
end

-- Can move to runtime later?
local function table_count(t)
	local count = 0

	for k, v in pairs(t) do
		count = count + 1
	end

	return count
end

-- Should probably move this to a dedicated Resources API (later)
function NativeClient:PreloadPersistentResources()
	local grf = RagnarokGRF()
	grf:Open(self.GRF_FILE_PATH)

	printf("Preloading %d persistent resources from %s", table_count(self.PERSISTENT_RESOURCES), self.GRF_FILE_PATH)
	for filePath, isLoaded in pairs(self.PERSISTENT_RESOURCES) do
		self.PERSISTENT_RESOURCES[filePath] = grf:ExtractFileInMemory(filePath)
	end

	self.grf = grf -- No need to close as reopening would be expensive (OS will free the handle)
end

function NativeClient:LoadSceneByID(globallyUniqueSceneID)
	printf("Loading scene %s", globallyUniqueSceneID)
	Renderer:ResetScene()

	-- This might seem sketchy, but it allows swapping the asset source on the fly (e.g., disk/network/virtual FS)
	local grfFileSystem = self.grf:MakeFileSystem(self.GRF_FILE_PATH)

	local map = RagnarokMap(globallyUniqueSceneID, grfFileSystem) or DebugScene(globallyUniqueSceneID)
	Renderer:LoadSceneObjects(map)
end

function NativeClient:LoadScenesOneByOne(delayInMilliseconds)
	delayInMilliseconds = delayInMilliseconds or 1
	local mapDB = require("DB.Maps")
	local gndFiles = self.grf:FindFilesByType("gnd")
	local numAvailableGNDs = table.count(gndFiles)

	local numMapsLoaded, numMapsSkipped = 0, 0

	printf(
		"Starting stress test (loading at most %d maps one by one) with a delay of %d ms",
		numAvailableGNDs,
		delayInMilliseconds
	)

	local index, ticker, entry, mapID, mapInfo
	ticker = C_Timer.NewTicker(delayInMilliseconds, function()
		index, entry = next(gndFiles, index)
		if not index then
			printf(
				"Stress test finished! A total of %d maps were loaded, while %d were skipped.",
				numMapsLoaded,
				numMapsSkipped
			)
			ticker:stop()
			self:Stop()
			return
		end

		mapID = path.basename(entry.name, ".gnd")
		mapInfo = mapDB[mapID]
		if mapInfo then
			self:LoadSceneByID(mapID)
			numMapsLoaded = numMapsLoaded + 1
		else
			printf("Skipping map %s since it wasn't found in %s", mapID, self.GRF_FILE_PATH)
			numMapsSkipped = numMapsSkipped + 1
		end
	end)
end

return NativeClient
