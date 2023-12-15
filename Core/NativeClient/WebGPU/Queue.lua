local etrace = require("Core.RuntimeExtensions.etrace")
local webgpu = require("webgpu")

etrace.register("GPU_QUEUE_SUBMIT")
etrace.register("GPU_BUFFER_WRITE")

local Queue = {}

function Queue:Submit(wgpuQueue, commandCount, wgpuCommandBuffers)
	etrace.create("GPU_QUEUE_SUBMIT", { commandCount = commandCount })
	return webgpu.bindings.wgpu_queue_submit(wgpuQueue, commandCount, wgpuCommandBuffers)
end

function Queue:WriteBuffer(wgpuQueue, wgpuBuffer, bufferOffset, data, size)
	etrace.create("GPU_BUFFER_WRITE", { bufferOffset = bufferOffset, data = data, size = size })
	return webgpu.bindings.wgpu_queue_write_buffer(wgpuQueue, wgpuBuffer, bufferOffset, data, size)
end

Queue.__call = Queue.Construct
Queue.__index = Queue
setmetatable(Queue, Queue)

return Queue
