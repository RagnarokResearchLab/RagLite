local webgpu = require("webgpu")

local Queue = {}

function Queue:Submit(wgpuQueue, commandCount, wgpuCommandBuffers)
	return webgpu.bindings.wgpu_queue_submit(wgpuQueue, commandCount, wgpuCommandBuffers)
end

function Queue:WriteBuffer(wgpuQueue, wgpuBuffer, bufferOffset, data, size)
	return webgpu.bindings.wgpu_queue_write_buffer(wgpuQueue, wgpuBuffer, bufferOffset, data, size)
end

Queue.__call = Queue.Construct
Queue.__index = Queue
setmetatable(Queue, Queue)

return Queue
