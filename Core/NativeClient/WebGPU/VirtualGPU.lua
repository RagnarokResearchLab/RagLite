local etrace = require("Core.RuntimeExtensions.etrace")
local ffi = require("ffi")
local webgpu = require("webgpu")

local VirtualGPU = {
	events = {
		GPU_BUFFER_CREATE = true,
		GPU_BUFFER_DESTROY = true,
		GPU_BUFFER_WRITE = true,
		GPU_TEXTURE_WRITE = true,
	},
	virtualizedBindings = {
		wgpu_device_create_sampler = function(...) end,
		wgpu_device_create_texture = function(...)
			return ffi.new("WGPUTexture")
		end,
		wgpu_texture_create_view = function(...) end,
		wgpu_device_create_bind_group_layout = function(...) end,
		wgpu_device_create_bind_group = function(...) end,
		wgpu_device_get_queue = function(...)
			return ffi.new("WGPUQueue")
		end,
		wgpu_queue_write_texture = function(queue, destination, data, dataSize, dataLayout, writeSize)
			etrace.create("GPU_TEXTURE_WRITE", {
				destination = destination,
				data = data,
				dataSize = dataSize,
				dataLayout = dataLayout,
				writeSize = writeSize,
			})
		end,
		wgpu_device_create_buffer = function(device, descriptor)
			etrace.create("GPU_BUFFER_CREATE", {
				device = device,
				descriptor = descriptor,
			})
		end,
		wgpu_queue_write_buffer = function(queue, buffer, bufferOffset, data, size)
			etrace.create("GPU_BUFFER_WRITE", {
				queue = queue,
				buffer = buffer,
				bufferOffset = bufferOffset,
				data = data,
				size = size,
			})
		end,
		wgpu_buffer_destroy = function(buffer)
			etrace.create("GPU_BUFFER_DESTROY", {
				buffer = buffer,
			})
		end,
	},
}

setmetatable(VirtualGPU.virtualizedBindings, {
	__index = function(t, k)
		error(format("NYI: Virtualized binding is missing for %s", k), 0)
	end,
})

function VirtualGPU:Enable()
	printf("[VirtualGPU] WebGPU call interception is now ON")
	for event, _ in pairs(self.events) do
		etrace.register(event)
	end

	self.backedUpBindings = webgpu.bindings
	webgpu.bindings = self.virtualizedBindings

	etrace.enable()
end

function VirtualGPU:Disable()
	printf("[VirtualGPU] WebGPU call interception is now OFF")
	for event, isEnabled in pairs(self.events) do
		etrace.unregister(event)
	end

	webgpu.bindings = self.backedUpBindings
	self.backedUpBindings = nil

	etrace.disable()
end

return VirtualGPU
