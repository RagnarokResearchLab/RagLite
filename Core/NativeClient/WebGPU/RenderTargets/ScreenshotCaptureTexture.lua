local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local ScreenshotCaptureTexture = {}

function ScreenshotCaptureTexture:Construct(wgpuDevice, width, height)
	local textureDescriptor = new("WGPUTextureDescriptor")
	textureDescriptor.dimension = ffi.C.WGPUTextureDimension_2D
	textureDescriptor.format = ScreenshotCaptureTexture.OUTPUT_TEXTURE_FORMAT
	textureDescriptor.mipLevelCount = 1
	textureDescriptor.sampleCount = 1
	textureDescriptor.size = { width, height, 1 }
	textureDescriptor.usage = bit.bor(ffi.C.WGPUTextureUsage_RenderAttachment, ffi.C.WGPUTextureUsage_CopySrc)
	textureDescriptor.viewFormatCount = 0
	local texture = webgpu.bindings.wgpu_device_create_texture(wgpuDevice, textureDescriptor)

	local textureViewDescriptor = new("WGPUTextureViewDescriptor")
	textureViewDescriptor.aspect = ffi.C.WGPUTextureAspect_All
	textureViewDescriptor.baseArrayLayer = 0
	textureViewDescriptor.arrayLayerCount = 1
	textureViewDescriptor.baseMipLevel = 0
	textureViewDescriptor.mipLevelCount = 1
	textureViewDescriptor.dimension = ffi.C.WGPUTextureViewDimension_2D
	textureViewDescriptor.format = textureDescriptor.format
	local textureView = webgpu.bindings.wgpu_texture_create_view(texture, textureViewDescriptor)

	local renderPassColorAttachment = new("WGPURenderPassColorAttachment", {
		view = textureView,
		loadOp = ffi.C.WGPULoadOp_Clear,
		storeOp = ffi.C.WGPUStoreOp_Store,
		clearValue = new("WGPUColor", { 0, 0, 0, 0 }),
	})

	setmetatable(instance, self)
	return instance
end

class("ScreenshotCaptureTexture", ScreenshotCaptureTexture)

return ScreenshotCaptureTexture
