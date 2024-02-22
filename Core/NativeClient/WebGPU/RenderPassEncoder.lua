local webgpu = require("wgpu")

local RenderPassEncoder = {}

function RenderPassEncoder:DrawIndexed(
	wgpuRenderPassEncoder,
	indexCount,
	instanceCount,
	firstIndex,
	baseVertex,
	firstInstance
)
	return webgpu.bindings.wgpu_render_pass_encoder_draw_indexed(
		wgpuRenderPassEncoder,
		indexCount,
		instanceCount,
		firstIndex,
		baseVertex,
		firstInstance
	)
end

function RenderPassEncoder:End(wgpuRenderPassEncoder)
	return webgpu.bindings.wgpu_render_pass_encoder_end(wgpuRenderPassEncoder)
end

function RenderPassEncoder:SetBindGroup(
	wgpuRenderPassEncoder,
	groupIndex,
	wgpuBindGroup,
	dynamicOffsetCount,
	dynamicOffsets
)
	return webgpu.bindings.wgpu_render_pass_encoder_set_bind_group(
		wgpuRenderPassEncoder,
		groupIndex,
		wgpuBindGroup,
		dynamicOffsetCount,
		dynamicOffsets
	)
end

function RenderPassEncoder:SetIndexBuffer(wgpuRenderPassEncoder, wgpuBuffer, wgpuIndexFormat, offset, size)
	return webgpu.bindings.wgpu_render_pass_encoder_set_index_buffer(
		wgpuRenderPassEncoder,
		wgpuBuffer,
		wgpuIndexFormat,
		offset,
		size
	)
end

function RenderPassEncoder:SetPipeline(wgpuRenderPassEncoder, wgpuRenderPipeline)
	return webgpu.bindings.wgpu_render_pass_encoder_set_pipeline(wgpuRenderPassEncoder, wgpuRenderPipeline)
end

function RenderPassEncoder:SetVertexBuffer(wgpuRenderPassEncoder, slot, wgpuBuffer, offset, size)
	return webgpu.bindings.wgpu_render_pass_encoder_set_vertex_buffer(
		wgpuRenderPassEncoder,
		slot,
		wgpuBuffer,
		offset,
		size
	)
end

RenderPassEncoder.__call = RenderPassEncoder.Construct
RenderPassEncoder.__index = RenderPassEncoder
setmetatable(RenderPassEncoder, RenderPassEncoder)

return RenderPassEncoder
