local bit = require("bit")
local console = require("console")
local ffi = require("ffi")
local webgpu = require("wgpu")

local Buffer = require("Core.NativeClient.WebGPU.Buffer")
local CommandEncoder = require("Core.NativeClient.WebGPU.CommandEncoder")
local Device = require("Core.NativeClient.WebGPU.Device")

local format = string.format

local ScreenshotCaptureTexture = {
	OUTPUT_TEXTURE_FORMAT = ffi.C.WGPUTextureFormat_RGBA8Unorm, -- Texture.DEFAULT_TEXTURE_FORMAT
}

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

	local pixelBufferDescriptor = new("WGPUBufferDescriptor")
	pixelBufferDescriptor.mappedAtCreation = false
	pixelBufferDescriptor.usage = Buffer.READBACK_BUFFER_FLAGS
	pixelBufferDescriptor.size = 4 * width * height -- RGBA
	local pixelBuffer = webgpu.bindings.wgpu_device_create_buffer(wgpuDevice, pixelBufferDescriptor)

	local instance = {
		width = width,
		height = height,
		wgpuDevice = wgpuDevice,
		wgpuTexture = texture,
		wgpuTextureView = textureView,
		wgpuTextureDescriptor = textureDescriptor,
		wgpuTextureViewDescriptor = textureViewDescriptor,
		colorAttachment = renderPassColorAttachment,
		readbackBuffer = pixelBuffer,
		readbackBufferDescriptor = pixelBufferDescriptor,
	}

	local inheritanceLookupMetatable = {
		__index = self,
	}
	setmetatable(instance, inheritanceLookupMetatable)

	return instance
end
function ScreenshotCaptureTexture:DownloadPixelBuffer(wgpuDevice)
	console.startTimer("[ScreenshotCaptureTexture] DownloadPixelBuffer")

	local rgbaPixelBufferSize = tonumber(self.readbackBufferDescriptor.size)
	self.rgbaPixelBuffer = buffer.new(rgbaPixelBufferSize)

	local commandEncoderDescriptor = new("WGPUCommandEncoderDescriptor")
	local commandEncoder = Device:CreateCommandEncoder(wgpuDevice, commandEncoderDescriptor)

	local source = new("WGPUImageCopyTexture", {
		mipLevel = 0,
		origin = { 0, 0, 0 },
		aspect = ffi.C.WGPUTextureAspect_All,
		texture = self.wgpuTexture,
	})

	local destination = new("WGPUImageCopyBuffer", {
		buffer = self.readbackBuffer,
		layout = {
			bytesPerRow = 4 * self.width,
			offset = 0,
			rowsPerImage = self.height,
		},
	})

	webgpu.bindings.wgpu_command_encoder_copy_texture_to_buffer(
		commandEncoder,
		source,
		destination,
		new("WGPUExtent3D", { self.width, self.height, 1 })
	)

	CommandEncoder:Submit(commandEncoder, self.wgpuDevice)

	local function onAsyncMapRequestCompleted(status)
		if status ~= ffi.C.WGPUBufferMapAsyncStatus_Success then
			error(format("Failed to map screenshot readback buffer (status: %s)", status))
			return
		end

		local pixelData = webgpu.bindings.wgpu_buffer_get_const_mapped_range(
			self.readbackBuffer,
			0,
			self.readbackBufferDescriptor.size
		)

		self.rgbaPixelBuffer:putcdata(pixelData, rgbaPixelBufferSize)

		-- Can safely unmap here since the image data was copied (not ideal, can probably avoid this copy?)
		webgpu.bindings.wgpu_buffer_unmap(self.readbackBuffer)

		console.stopTimer("[ScreenshotCaptureTexture] DownloadPixelBuffer")
	end

	webgpu.bindings.wgpu_buffer_map_async(
		self.readbackBuffer,
		ffi.C.WGPUMapMode_Read,
		0,
		self.readbackBufferDescriptor.size,
		onAsyncMapRequestCompleted,
		nil
	)

	-- Should probably do this asynchronously and not block the render loop (optimize later)
	webgpu.bindings.wgpu_device_poll(self.wgpuDevice, true, nil)

	return self.rgbaPixelBuffer, self.width, self.height
end

class("ScreenshotCaptureTexture", ScreenshotCaptureTexture)

return ScreenshotCaptureTexture
