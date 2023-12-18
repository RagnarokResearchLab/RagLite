local etrace = require("Core.RuntimeExtensions.etrace")
local ffi = require("ffi")
local webgpu = require("webgpu")

local VirtualGPU = {
	events = {
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
	},
}

function VirtualGPU:Enable()
	for event, _ in pairs(self.events) do
		etrace.register(event)
	end

	self.backedUpBindings = webgpu.bindings
	webgpu.bindings = self.virtualizedBindings
end

function VirtualGPU:Disable()
	for event, isEnabled in pairs(self.events) do
		etrace.unregister(event)
	end

	webgpu.bindings = self.backedUpBindings
end

return VirtualGPU