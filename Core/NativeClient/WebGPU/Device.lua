local webgpu = require("webgpu")

local Device = {}

function Device:CreateBindGroup(wgpuDevice, wgpuBindGroupDescriptor)
	return webgpu.bindings.wgpu_device_create_bind_group(wgpuDevice, wgpuBindGroupDescriptor)
end

function Device:CreateBuffer(wgpuDevice, wgpuBufferDescriptor)
	return webgpu.bindings.wgpu_device_create_buffer(wgpuDevice, wgpuBufferDescriptor)
end

function Device:CreateCommandEncoder(wgpuDevice, wgpuCommandEncoderDescriptor)
	return webgpu.bindings.wgpu_device_create_command_encoder(wgpuDevice, wgpuCommandEncoderDescriptor)
end

function Device:CreateShaderModule(wgpuDevice, wgpuShaderModuleDescriptor)
	return webgpu.bindings.wgpu_device_create_shader_module(wgpuDevice, wgpuShaderModuleDescriptor)
end

function Device:CreateTexture(wgpuDevice, wgpuTextureDescriptor)
	return webgpu.bindings.wgpu_device_create_texture(wgpuDevice, wgpuTextureDescriptor)
end

function Device:GetQueue(wgpuDevice)
	return webgpu.bindings.wgpu_device_get_queue(wgpuDevice)
end

Device.__call = Device.Construct
Device.__index = Device
setmetatable(Device, Device)

return Device
