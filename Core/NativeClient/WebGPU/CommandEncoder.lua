local webgpu = require("webgpu")

local CommandEncoder = {}

function CommandEncoder:BeginRenderPass(wgpuCommandEncoder, wgpuRenderPassDescriptor)
	return webgpu.bindings.wgpu_command_encoder_begin_render_pass(wgpuCommandEncoder, wgpuRenderPassDescriptor)
end

function CommandEncoder:Finish(wgpuCommandEncoder, wgpuCommandBufferDescriptor)
	return webgpu.bindings.wgpu_command_encoder_finish(wgpuCommandEncoder, wgpuCommandBufferDescriptor)
end

CommandEncoder.__call = CommandEncoder.Construct
CommandEncoder.__index = CommandEncoder
setmetatable(CommandEncoder, CommandEncoder)

return CommandEncoder
