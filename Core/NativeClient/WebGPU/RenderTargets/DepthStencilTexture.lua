local ffi = require("ffi")

local Device = require("Core.NativeClient.WebGPU.Device")
local Texture = require("Core.NativeClient.WebGPU.Texture")

local DepthStencilTexture = {}

function DepthStencilTexture:Construct(wgpuDevice, width, height)
	local instance = {}

	local depthTextureDesc = ffi.new("WGPUTextureDescriptor", {
		dimension = ffi.C.WGPUTextureDimension_2D,
		format = ffi.C.WGPUTextureFormat_Depth24Plus,
		mipLevelCount = 1,
		sampleCount = 1,
		size = {
			width,
			height,
			1,
		},
		usage = ffi.C.WGPUTextureUsage_RenderAttachment,
		viewFormatCount = 1,
		viewFormats = ffi.new("WGPUTextureFormat[1]", ffi.C.WGPUTextureFormat_Depth24Plus),
	})
	local depthTexture = Device:CreateTexture(wgpuDevice, depthTextureDesc)

	-- Create the view of the depth texture manipulated by the rasterizer
	local depthTextureViewDesc = ffi.new("WGPUTextureViewDescriptor", {
		aspect = ffi.C.WGPUTextureAspect_DepthOnly,
		baseArrayLayer = 0,
		arrayLayerCount = 1,
		baseMipLevel = 0,
		mipLevelCount = 1,
		dimension = ffi.C.WGPUTextureViewDimension_2D,
		format = ffi.C.WGPUTextureFormat_Depth24Plus,
	})
	local depthTextureView = Texture:CreateTextureView(depthTexture, depthTextureViewDesc)

	local depthStencilAttachment = ffi.new("WGPURenderPassDepthStencilAttachment", {
		view = depthTextureView,
		depthClearValue = 1.0, -- The initial value of the depth buffer, meaning "far"
		depthLoadOp = ffi.C.WGPULoadOp_Clear,
		depthStoreOp = ffi.C.WGPUStoreOp_Store, -- Enable depth write (should disable for UI later?)
		depthReadOnly = false,
		-- Stencil setup; mandatory but unused
		stencilClearValue = 0,
		stencilLoadOp = ffi.C.WGPULoadOp_Clear,
		stencilStoreOp = ffi.C.WGPUStoreOp_Store,
		stencilReadOnly = true,
	})

	instance.colorAttachment = depthStencilAttachment
	instance.wgpuTexture = depthTexture
	instance.wgpuTextureView = depthTextureView

	setmetatable(instance, self)
	return instance
end

class("DepthStencilTexture", DepthStencilTexture)

return DepthStencilTexture
