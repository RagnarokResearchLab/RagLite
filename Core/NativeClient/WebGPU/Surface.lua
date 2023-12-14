local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("webgpu")

local assert = assert
local tonumber = tonumber

local ffi_new = ffi.new

local Surface = {}

function Surface:Construct(wgpuInstance, wgpuAdapter, wgpuDevice, glfwWindow)
	self.wgpuInstance = wgpuInstance
	self.wgpuAdapter = wgpuAdapter
	self.wgpuDevice = wgpuDevice
	self.glfwWindow = glfwWindow

	self.wgpuSurface = glfw.bindings.glfw_get_wgpu_surface(wgpuInstance, glfwWindow)
	self.wgpuSurfaceConfiguration = ffi_new("WGPUSurfaceConfiguration")
	self.wgpuSurfaceTexture = ffi_new("WGPUSurfaceTexture")
	self.wgpuTextureViewDescriptor = ffi_new("WGPUTextureViewDescriptor")

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
end

function Surface:AcquireTextureView()
	local surfaceTexture = self.wgpuSurfaceTexture
	local textureViewDescriptor = self.wgpuTextureViewDescriptor

	-- Since resizing isn't yet supported, fail loudly if attempted despite GLFW window hints
	webgpu.bindings.wgpu_surface_get_current_texture(self.wgpuSurface, surfaceTexture)
	-- Some of those errors could probably be handled... oh, well. Maybe later!
	assert(surfaceTexture.status == ffi.C.WGPUSurfaceGetCurrentTextureStatus_Success, "Unexpected surface status")

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

local contentWidthInPixels = ffi_new("int[1]")
local contentHeightInPixels = ffi_new("int[1]")
function Surface:GetViewportSize()
	-- Should probably differentiate between window and frame buffer here for high-DPI (later)
	glfw.bindings.glfw_get_window_size(self.glfwWindow, contentWidthInPixels, contentHeightInPixels)
	return tonumber(contentWidthInPixels[0]), tonumber(contentHeightInPixels[0])
end

Surface.__index = Surface
Surface.__call = Surface.Construct
setmetatable(Surface, Surface)

return Surface
