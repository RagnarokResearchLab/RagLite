local Texture = require("Core.NativeClient.WebGPU.Texture")

local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("webgpu")

local new = ffi.new
local ffi_string = ffi.string

local GPU = {
	MAX_VERTEX_COUNT = 200000, -- Should be configurable (later)
	MAX_TEXTURE_ARRAY_SIZE = 32,
}

-- The FFI bindings don't provide enums for native extensions yet (requires a fix in the runtime)
ffi.cdef([[
	typedef enum WGPUNativeFeature {
		WGPUNativeFeature_PushConstants = 0x00030001,
		WGPUNativeFeature_TextureAdapterSpecificFormatFeatures = 0x00030002,
		WGPUNativeFeature_MultiDrawIndirect = 0x00030003,
		WGPUNativeFeature_MultiDrawIndirectCount = 0x00030004,
		WGPUNativeFeature_VertexWritableStorage = 0x00030005,
		WGPUNativeFeature_TextureBindingArray = 0x00030006,
		WGPUNativeFeature_SampledTextureAndStorageBufferArrayNonUniformIndexing = 0x00030007,
		WGPUNativeFeature_PipelineStatisticsQuery = 0x00030008,
		WGPUNativeFeature_Force32 = 0x7FFFFFFF
	} WGPUNativeFeature;

	typedef enum WGPUNativeSType {
		// Start at 0003 since that's allocated range for wgpu-native
		WGPUSType_DeviceExtras = 0x00030001,
		WGPUSType_RequiredLimitsExtras = 0x00030002,
		WGPUSType_PipelineLayoutExtras = 0x00030003,
		WGPUSType_ShaderModuleGLSLDescriptor = 0x00030004,
		WGPUSType_SupportedLimitsExtras = 0x00030005,
		WGPUSType_InstanceExtras = 0x00030006,
		WGPUSType_BindGroupEntryExtras = 0x00030007,
		WGPUSType_BindGroupLayoutEntryExtras = 0x00030008,
		WGPUSType_QuerySetDescriptorExtras = 0x00030009,
		WGPUSType_SurfaceConfigurationExtras = 0x0003000A,
		WGPUNativeSType_Force32 = 0x7FFFFFFF
	} WGPUNativeSType;

	typedef struct WGPUBindGroupLayoutEntryExtras {
		WGPUChainedStruct chain;
		uint32_t count;
	} WGPUBindGroupLayoutEntryExtras;
]])

function GPU:CreateInstance()
	local instanceDescriptor = new("WGPUInstanceDescriptor")
	local instance = webgpu.bindings.wgpu_create_instance(instanceDescriptor)
	if not instance then
		error("Could not initialize WebGPU")
	end

	return instance, instanceDescriptor
end

function GPU:RequestAdapter(instance, window)
	local adapterOptions = new("WGPURequestAdapterOptions", {
		compatibleSurface = glfw.bindings.glfw_get_wgpu_surface(instance, window),
		powerPreference = ffi.C.WGPUPowerPreference_HighPerformance,
	})

	local requestedAdapter
	local function onAdapterRequested(status, adapter, message, userdata)
		assert(status == ffi.C.WGPURequestAdapterStatus_Success, "Failed to request WebGPU adapter")
		requestedAdapter = adapter
	end
	webgpu.bindings.wgpu_instance_request_adapter(instance, adapterOptions, onAdapterRequested, nil)

	-- This call is blocking (in the wgpu-native implementation), but that might change in the future...
	assert(requestedAdapter, "onAdapterRequested did not trigger, but it should have")

	return requestedAdapter
end

function GPU:RequestLogicalDevice(adapter, options)
	options = options or {}
	options.defaultQueue = options.defaultQueue or {}

	options.label = options.label or "Logical WebGPU Device"
	options.requiredFeatureCount = options.requiredFeatureCount or 0
	options.defaultQueue.label = options.defaultQueue.label or "Default Queue"

	local supportedLimits = new("WGPUSupportedLimits")
	webgpu.bindings.wgpu_adapter_get_limits(adapter, supportedLimits)

	local deviceDescriptor = new("WGPUDeviceDescriptor", {
		label = options.label,
		defaultQueue = {
			label = options.defaultQueue.label,
		},
		requiredFeatureCount = 2,
		requiredFeatures = new("WGPUFeatureName[?]", 2, {
			ffi.C.WGPUNativeFeature_TextureBindingArray,
			ffi.C.WGPUNativeFeature_SampledTextureAndStorageBufferArrayNonUniformIndexing,
		}),
		requiredLimits = new("WGPURequiredLimits", {
			limits = {
				maxTextureDimension1D = 0,
				maxTextureDimension2D = Texture.MAX_TEXTURE_DIMENSION,
				maxTextureDimension3D = 0,
				maxTextureArrayLayers = 1, -- For the depth/stencil texture
				maxVertexAttributes = 3, -- Vertex positions, vertex colors, diffuse texture UVs
				maxVertexBuffers = 3, -- Vertex positions, vertex colors, diffuse texture UVs
				maxInterStageShaderComponents = 6, -- #(vec3f color, vec2f diffuseTextureCoords, float alpha)
				maxBufferSize = self.MAX_VERTEX_COUNT * 5 * ffi.sizeof("float"), -- #(vec3f position, vec2f transform)
				maxVertexBufferArrayStride = 20, -- #(Rml::Vertex)
				maxBindGroups = 3, -- Camera, material, transforms
				maxUniformBuffersPerShaderStage = 1, -- Camera properties (increase for material, soon?)
				maxSampledTexturesPerShaderStage = GPU.MAX_TEXTURE_ARRAY_SIZE,
				maxSamplersPerShaderStage = GPU.MAX_TEXTURE_ARRAY_SIZE,
				maxUniformBufferBindingSize = 65536, -- DEFAULT
				maxBindingsPerBindGroup = 2, -- Max. allowed binding index
				maxDynamicUniformBuffersPerPipelineLayout = 1,
				minStorageBufferOffsetAlignment = 32,
				minUniformBufferOffsetAlignment = 32,
			},
		}),
	})

	assert(supportedLimits.limits.minUniformBufferOffsetAlignment <= 32, "Dynamic uniform headaches will ensue")
	self.minUniformBufferOffsetAlignment = supportedLimits.limits.minUniformBufferOffsetAlignment

	local requestedDevice
	local function onDeviceRequested(status, device, message, userdata)
		local success = status == ffi.C.WGPURequestDeviceStatus_Success
		if not success then
			error(
				format(
					"Failed to request logical WebGPU device (status: %s)\n%s",
					tonumber(status),
					ffi_string(message)
				)
			)
		end
		requestedDevice = device
	end
	webgpu.bindings.wgpu_adapter_request_device(adapter, deviceDescriptor, onDeviceRequested, nil)

	-- This is blocking in the wgpu-native implementation, but it might change in the future...
	assert(requestedDevice, "onDeviceRequested did not trigger, but it should have")

	local function onDeviceError(errorType, message, userdata)
		local errorDetails = format("Type: %s, Message: %s", tonumber(errorType), ffi_string(message))
		error("Uncaptured device error - " .. errorDetails)
	end

	webgpu.bindings.wgpu_device_set_uncaptured_error_callback(requestedDevice, onDeviceError, nil)

	local canUseTextureArrays =
		webgpu.bindings.wgpu_device_has_feature(requestedDevice, ffi.C.WGPUNativeFeature_TextureBindingArray)
	local canUseNonUniformTextureArraySampler = webgpu.bindings.wgpu_device_has_feature(
		requestedDevice,
		ffi.C.WGPUNativeFeature_SampledTextureAndStorageBufferArrayNonUniformIndexing
	)
	-- If texture arrays work but non-uniform sampling doesn't, shaders will be more complicated -> Not supported
	assert(canUseTextureArrays, "Device is unable to use texture arrays (which are currently required)")
	assert(canUseNonUniformTextureArraySampler, "Device is unable to use non-uniform sampling for texture arrays")

	return requestedDevice, deviceDescriptor
end

function GPU:GetAlignedDynamicUniformBufferStride(uniformStructSizeInBytes)
	local step = self.minUniformBufferOffsetAlignment
	-- More headaches if the dynamic uniforms (e.g., widget transforms) are smaller than the minimum stride...
	local divide_and_ceil = uniformStructSizeInBytes / step + (uniformStructSizeInBytes % step == 0 and 0 or 1)
	return step * divide_and_ceil
end

return GPU
