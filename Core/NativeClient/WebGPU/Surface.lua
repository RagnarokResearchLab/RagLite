local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("wgpu")

local assert = assert
local tonumber = tonumber

local new = ffi.new

local Surface = {
	errorStrings = {
		GPU_DEVICE_LOST = "GPU access has been lost and can't be restored (hardware issue or abrupt shutdown?)",
		UNKNOWN_TEXTURE_STATUS = "Received an unknown texture status from the WebGPU API (outdated FFI bindings?)",
		GPU_MEMORY_EXHAUSTED = "The available GPU memory is exhausted (VRAM usage too high or leaking resources?)",
		BACKING_SURFACE_LOST = "The backing surface has been lost and can't be used (texture format changed?)",
		BACKING_SURFACE_OUTDATED = "The backing surface is outdated and can't be used (window resized or moved?)",
		BACKING_SURFACE_TIMEOUT = "The backing surface couldn't be accessed in time (CPU or GPU too busy?)",
	},
}

function Surface:Construct(wgpuInstance, wgpuAdapter, wgpuDevice, glfwWindow)
	self.wgpuInstance = wgpuInstance
	self.wgpuAdapter = wgpuAdapter
	self.wgpuDevice = wgpuDevice
	self.glfwWindow = glfwWindow

	self.wgpuSurface = glfw.bindings.glfw_get_wgpu_surface(wgpuInstance, glfwWindow)
	self.wgpuSurfaceConfiguration = new("WGPUSurfaceConfiguration")
	self.wgpuSurfaceTexture = new("WGPUSurfaceTexture")
	self.wgpuTextureViewDescriptor = new("WGPUTextureViewDescriptor")

	return self
end

function Surface:UpdateConfiguration()
	local preferredTextureFormat = webgpu.bindings.wgpu_surface_get_preferred_format(self.wgpuSurface, self.wgpuAdapter)
	self.preferredTextureFormat = preferredTextureFormat -- Required to create the render pipeline
	assert(
		preferredTextureFormat == ffi.C.WGPUTextureFormat_BGRA8UnormSrgb,
		"Only sRGB texture formats are currently supported"
	)

	local textureViewDescriptor = self.wgpuTextureViewDescriptor
	textureViewDescriptor.dimension = ffi.C.WGPUTextureViewDimension_2D
	textureViewDescriptor.format = preferredTextureFormat
	textureViewDescriptor.mipLevelCount = 1
	textureViewDescriptor.arrayLayerCount = 1
	textureViewDescriptor.aspect = ffi.C.WGPUTextureAspect_All

	local surfaceConfiguration = self.wgpuSurfaceConfiguration
	surfaceConfiguration.device = self.wgpuDevice
	surfaceConfiguration.format = preferredTextureFormat
	surfaceConfiguration.usage = ffi.C.WGPUTextureUsage_RenderAttachment

	-- The underlying framebuffer may be different if DPI scaling is applied, but let's ignore that for now
	local viewportWidth, viewportHeight = self:GetViewportSize()
	assert(viewportWidth > 0, "Viewport width should be set")
	assert(viewportHeight > 0, "Viewport height should be set")
	surfaceConfiguration.width = viewportWidth
	surfaceConfiguration.height = viewportHeight
	surfaceConfiguration.presentMode = ffi.C.WGPUPresentMode_Fifo

	webgpu.bindings.wgpu_surface_configure(self.wgpuSurface, surfaceConfiguration)

	printf(
		"Surface configuration changed: Frame buffer size is now %dx%d (preferred texture format: %d)",
		viewportWidth,
		viewportHeight,
		tonumber(preferredTextureFormat)
	)
end

function Surface:AcquireTextureView()
	local surfaceTexture = self.wgpuSurfaceTexture
	local textureViewDescriptor = self.wgpuTextureViewDescriptor

	-- Since resizing isn't yet supported, fail loudly if attempted despite GLFW window hints
	webgpu.bindings.wgpu_surface_get_current_texture(self.wgpuSurface, surfaceTexture)
	local isTextureReadyToUse, failureReason = self:ValidateTextureStatus(surfaceTexture.status)
	if not isTextureReadyToUse then
		return nil, failureReason
	end

	local nextTextureView = webgpu.bindings.wgpu_texture_create_view(surfaceTexture.texture, textureViewDescriptor)
	assert(nextTextureView, "Cannot acquire next presentable texture view (window surface has changed?)")

	return nextTextureView
end

function Surface:PresentNextFrame()
	assert(tonumber(self.wgpuSurfaceTexture.suboptimal) == 0, "Surface texture should be optimal")
	webgpu.bindings.wgpu_surface_present(self.wgpuSurface)
end

function Surface:GetAspectRatio()
	return self.wgpuSurfaceConfiguration.width / self.wgpuSurfaceConfiguration.height
end

local contentWidthInPixels = new("int[1]")
local contentHeightInPixels = new("int[1]")
function Surface:GetViewportSize()
	-- Should probably differentiate between window and frame buffer here for high-DPI (later)
	glfw.bindings.glfw_get_window_size(self.glfwWindow, contentWidthInPixels, contentHeightInPixels)
	return tonumber(contentWidthInPixels[0]), tonumber(contentHeightInPixels[0])
end

function Surface:ValidateTextureStatus(status)
	if status == ffi.C.WGPUSurfaceGetCurrentTextureStatus_Success then
		-- Should check for suboptimality here?
		return true
	end

	if status == ffi.C.WGPUSurfaceGetCurrentTextureStatus_DeviceLost then
		error(self.errorStrings.GPU_DEVICE_LOST, 0)
	end

	if status == ffi.C.WGPUSurfaceGetCurrentTextureStatus_OutOfMemory then
		error(self.errorStrings.GPU_MEMORY_EXHAUSTED, 0)
	end

	if status == ffi.C.WGPUSurfaceGetCurrentTextureStatus_Lost then
		return nil, self.errorStrings.BACKING_SURFACE_LOST
	end

	if status == ffi.C.WGPUSurfaceGetCurrentTextureStatus_Outdated then
		return nil, self.errorStrings.BACKING_SURFACE_OUTDATED
	end

	if status == ffi.C.WGPUSurfaceGetCurrentTextureStatus_Timeout then
		return nil, self.errorStrings.BACKING_SURFACE_TIMEOUT
	end

	error(self.errorStrings.UNKNOWN_TEXTURE_STATUS, 0)
end

Surface.__index = Surface
Surface.__call = Surface.Construct
setmetatable(Surface, Surface)

return Surface
