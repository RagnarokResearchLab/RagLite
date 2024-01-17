local Device = require("Core.NativeClient.WebGPU.Device")
local _ = require("Core.VectorMath.Matrix4D") -- Only needed for the cdefs right now

local bit = require("bit")
local ffi = require("ffi")
local webgpu = require("webgpu")

local new = ffi.new
local sizeof = ffi.sizeof

local UniformBuffer = {
	DEFAULT_SHADER_STAGE_VISIBILITY_FLAGS = bit.bor(ffi.C.WGPUShaderStage_Vertex, ffi.C.WGPUShaderStage_Fragment),
	cdefs = [[
		// Total struct size must align to 16 byte boundary
		// See https://gpuweb.github.io/gpuweb/wgsl/#address-space-layout-constraints
		// Layouts must match the structs defined in the shaders
		typedef struct PerSceneData {
			Matrix4D view;
			Matrix4D perspectiveProjection;
			float color[4];
			float viewportWidth;
			float viewportHeight;
			// Padding needs to be updated whenever the struct changes!
			uint8_t padding[6];
		} scenewide_uniform_t;
		typedef struct PerMeshData {
			float translation[2]; // 8
			float padding[6]; // 32
			// Total size must be at least minUniformBufferOffsetAlignment bytes large (with 16 byte alignment)
		} mesh_uniform_t;
	]],
}

function UniformBuffer:Construct(displayName) end

function UniformBuffer:CreateCameraBindGroupLayout(wgpuDevice)
	local bindGroupLayoutDescriptor = new("WGPUBindGroupLayoutDescriptor", {
		entryCount = 1,
		entries = new("WGPUBindGroupLayoutEntry[?]", 1, {
			new("WGPUBindGroupLayoutEntry", {
				binding = 0,
				visibility = UniformBuffer.DEFAULT_SHADER_STAGE_VISIBILITY_FLAGS,
				buffer = {
					type = ffi.C.WGPUBufferBindingType_Uniform,
					minBindingSize = sizeof("scenewide_uniform_t"),
				},
			}),
		}),
	})

	local bindGroupLayout = webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDevice, bindGroupLayoutDescriptor)

	self.cameraBindGroupLayout = bindGroupLayout
	self.cameraBindGroupLayoutDescriptor = bindGroupLayoutDescriptor -- Need to keep it around for the entryCount
end

-- Needs streamlining (later)
function UniformBuffer:CreateCameraAndViewportUniform(wgpuDevice)
	local scenewideUniformBuffer = Device:CreateBuffer(
		wgpuDevice,
		ffi.new("WGPUBufferDescriptor", {
			size = ffi.sizeof("scenewide_uniform_t"),
			usage = bit.bor(ffi.C.WGPUBufferUsage_CopyDst, ffi.C.WGPUBufferUsage_Uniform),
		})
	)
	local cameraBindGroupDescriptor = ffi.new("WGPUBindGroupDescriptor", {
		layout = UniformBuffer.cameraBindGroupLayout,
		entryCount = UniformBuffer.cameraBindGroupLayoutDescriptor.entryCount,
		entries = ffi.new("WGPUBindGroupEntry", {
			binding = 0,
			buffer = scenewideUniformBuffer,
			offset = 0,
			size = ffi.sizeof("scenewide_uniform_t"),
		}),
	})
	local instance = {
		bindGroupDescriptor = cameraBindGroupDescriptor,
		bindGroup = Device:CreateBindGroup(wgpuDevice, cameraBindGroupDescriptor),
		buffer = scenewideUniformBuffer,
		data = ffi.new("scenewide_uniform_t"),
	}

	setmetatable(instance, self)

	return instance
end

function UniformBuffer:CreateMaterialBindGroupLayouts(wgpuDevice)
	local bindGroupLayoutDescriptor = new("WGPUBindGroupLayoutDescriptor", {
		entryCount = 2,
		entries = new("WGPUBindGroupLayoutEntry[?]", 2, {
			new("WGPUBindGroupLayoutEntry", {
				binding = 0,
				visibility = ffi.C.WGPUShaderStage_Fragment,
				texture = {
					sampleType = ffi.C.WGPUTextureSampleType_Float,
					viewDimension = ffi.C.WGPUTextureViewDimension_2D,
				},
			}),
			new("WGPUBindGroupLayoutEntry", {
				binding = 1,
				visibility = ffi.C.WGPUShaderStage_Fragment,
				sampler = {
					type = ffi.C.WGPUSamplerBindingType_Filtering,
				},
			}),
		}),
	})

	-- Texture arrays (wgpu extension) for water surface textures should be added here

	local bindGroupLayout = webgpu.bindings.wgpu_device_create_bind_group_layout(wgpuDevice, bindGroupLayoutDescriptor)

	self.materialBindGroupLayout = bindGroupLayout
	self.materialBindGroupLayoutDescriptor = bindGroupLayoutDescriptor -- Need to keep it around for the entryCount
end

UniformBuffer.__call = UniformBuffer.Construct
UniformBuffer.__index = UniformBuffer
setmetatable(UniformBuffer, UniformBuffer)

ffi.cdef(UniformBuffer.cdefs)

assert(
	ffi.sizeof("scenewide_uniform_t") % 16 == 0,
	"Structs in uniform address space must be aligned to a 16 byte boundary (as per the WebGPU specification)"
)
assert(
	ffi.sizeof("mesh_uniform_t") % 16 == 0,
	"Structs in uniform address space must be aligned to a 16 byte boundary (as per the WebGPU specification)"
)

return UniformBuffer
