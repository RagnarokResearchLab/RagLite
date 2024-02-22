local Device = require("Core.NativeClient.WebGPU.Device")
local Queue = require("Core.NativeClient.WebGPU.Queue")

local webgpu = require("wgpu")

local CommandEncoder = {}

function CommandEncoder:BeginRenderPass(wgpuCommandEncoder, wgpuRenderPassDescriptor)
	return webgpu.bindings.wgpu_command_encoder_begin_render_pass(wgpuCommandEncoder, wgpuRenderPassDescriptor)
end

function CommandEncoder:Finish(wgpuCommandEncoder, wgpuCommandBufferDescriptor)
	return webgpu.bindings.wgpu_command_encoder_finish(wgpuCommandEncoder, wgpuCommandBufferDescriptor)
end

function CommandEncoder:Submit(commandEncoder, wgpuDevice)
	local commandBufferDescriptor = new("WGPUCommandBufferDescriptor")
	local commandBuffer = self:Finish(commandEncoder, commandBufferDescriptor)

	local queue = Device:GetQueue(wgpuDevice)
	local commandBuffers = new("WGPUCommandBuffer[1]", commandBuffer)
	Queue:Submit(queue, 1, commandBuffers)
end

CommandEncoder.__call = CommandEncoder.Construct
CommandEncoder.__index = CommandEncoder
setmetatable(CommandEncoder, CommandEncoder)

return CommandEncoder
