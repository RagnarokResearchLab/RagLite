local glfw = require("glfw")

local Renderer = require("Core.NativeClient.Renderer")

local NativeClient = {
	mainWindow = nil,
	graphicsContext = nil,
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
		-0.5,
		0.0, -- bottom-left corner
		0.5,
		-0.5,
		0.0, -- bottom-right corner
		0.5,
		0.5,
		0.0, -- top-right corner
		-0.5,
		0.5,
		0.0, -- top-left corner

		-- Tip of the pyramid
		0.0,
		0.0,
		1.0, -- top center
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

	return window
end

function NativeClient:StartRenderLoop()
	while glfw.bindings.glfw_window_should_close(self.mainWindow) == 0 do
		glfw.bindings.glfw_poll_events()
		Renderer:RenderNextFrame(self.graphicsContext)
	end
end

function NativeClient:GetMainWindow()
	return self.mainWindow
end

return NativeClient
