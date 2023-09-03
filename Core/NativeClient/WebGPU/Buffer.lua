local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local Buffer = {}

local ALIGNMENT_IN_BYTES = 4

function Buffer.GetAlignedSize(unalignedSize)
	if unalignedSize <= 0 then
		return 0
	end

	local numUnalignedBytes = unalignedSize % ALIGNMENT_IN_BYTES
	local numRequiredPaddingBytes = (ALIGNMENT_IN_BYTES - numUnalignedBytes) % ALIGNMENT_IN_BYTES
	local paddedSize = unalignedSize + numRequiredPaddingBytes

	return paddedSize
end

function Buffer:CreateVertexBuffer(wgpuDevice, positions)
	local rawBufferSizeInBytes = #positions * ffi.sizeof("float") -- Assumes both 3D positions and colors are given as floats
	local alignedBufferSizeInBytes = Buffer.GetAlignedSize(rawBufferSizeInBytes)

	local bufferDescriptor = ffi.new("WGPUBufferDescriptor")
	bufferDescriptor.size = alignedBufferSizeInBytes
	bufferDescriptor.usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Vertex)
	bufferDescriptor.mappedAtCreation = false

	local buffer = webgpu.bindings.wgpu_device_create_buffer(wgpuDevice, bufferDescriptor)
	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(wgpuDevice),
		buffer,
		0,
		ffi.new("float[?]", alignedBufferSizeInBytes, positions),
		alignedBufferSizeInBytes
	)

	return buffer
end

function Buffer:CreateIndexBuffer(wgpuDevice, indices)
	local rawBufferSizeInBytes = #indices * ffi.sizeof("uint16_t") -- Assumes there won't be too many trianglces per mesh
	local alignedBufferSizeInBytes = Buffer.GetAlignedSize(rawBufferSizeInBytes)

	local bufferDescriptor = ffi.new("WGPUBufferDescriptor")
	bufferDescriptor.size = alignedBufferSizeInBytes
	bufferDescriptor.usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Index)
	bufferDescriptor.mappedAtCreation = false

	local buffer = webgpu.bindings.wgpu_device_create_buffer(wgpuDevice, bufferDescriptor)
	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(wgpuDevice),
		buffer,
		0,
		ffi.new("uint16_t[?]", alignedBufferSizeInBytes, indices),
		alignedBufferSizeInBytes
	)

	return buffer
end

return Buffer
