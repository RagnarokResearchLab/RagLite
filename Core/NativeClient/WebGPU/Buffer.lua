local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("wgpu")

local Buffer = {
	VERTEX_BUFFER_FLAGS = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Vertex),
	INDEX_BUFFER_FLAGS = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Index),
	READBACK_BUFFER_FLAGS = bit.bor(ffi.C.WGPUBufferUsage_MapRead, ffi.C.WGPUBufferUsage_CopyDst),
}

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

function Buffer:CreateVertexBuffer(wgpuDevice, entries)
	local isCGND = type(entries) == "cdata"
	local rawBufferSizeInBytes = isCGND and ffi.sizeof(entries) or #entries * ffi.sizeof("float") -- Assumes 3D positions, texture coords, or colors
	local alignedBufferSizeInBytes = Buffer.GetAlignedSize(rawBufferSizeInBytes)

	local bufferDescriptor = ffi.new("WGPUBufferDescriptor", {
		size = alignedBufferSizeInBytes,
		usage = Buffer.VERTEX_BUFFER_FLAGS,
	})

	local buffer = webgpu.bindings.wgpu_device_create_buffer(wgpuDevice, bufferDescriptor)
	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(wgpuDevice),
		buffer,
		0,
		isCGND and entries or ffi.new("float[?]", alignedBufferSizeInBytes, entries),
		alignedBufferSizeInBytes
	)

	return buffer
end

function Buffer:CreateIndexBuffer(wgpuDevice, indices)
	local isCGND = type(indices) == "cdata"

	local rawBufferSizeInBytes = isCGND and ffi.sizeof(indices) or #indices * ffi.sizeof("uint32_t") -- Assumes there won't be too many trianglces per mesh
	local alignedBufferSizeInBytes = Buffer.GetAlignedSize(rawBufferSizeInBytes)

	local bufferDescriptor = ffi.new("WGPUBufferDescriptor", {
		size = alignedBufferSizeInBytes,
		usage = Buffer.INDEX_BUFFER_FLAGS,
	})

	local buffer = webgpu.bindings.wgpu_device_create_buffer(wgpuDevice, bufferDescriptor)
	webgpu.bindings.wgpu_queue_write_buffer(
		webgpu.bindings.wgpu_device_get_queue(wgpuDevice),
		buffer,
		0,
		isCGND and indices or ffi.new("uint32_t[?]", alignedBufferSizeInBytes, indices),
		alignedBufferSizeInBytes
	)

	return buffer
end

function Buffer:Destroy(wgpuBuffer)
	webgpu.bindings.wgpu_buffer_destroy(wgpuBuffer)
end

return Buffer
