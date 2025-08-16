local Texture = require("Core.NativeClient.WebGPU.Texture")

local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("wgpu")

local new = ffi.new
local ffi_string = ffi.string

local GPU = {
	MAX_VERTEX_COUNT = 200000, -- Should be configurable (later)
	MAX_TEXTURE_ARRAY_SIZE = 32,
	MAX_BUFFER_SIZE = 256 * 1024 * 1024,
	MAX_UNIFORM_BUFFER_BINDING_SIZE = 65536,
}

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
		compatibleSurface = glfw.bindings.glfw_create_window_wgpu_surface(instance, window),
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
				maxVertexAttributes = 5, -- Vertex positions, vertex colors, diffuse UVs, normals, lightmap UVs
				maxVertexBuffers = 5, -- Vertex positions, vertex colors, diffuse UVs, normals, lightmap UVs
				maxInterStageShaderComponents = 11, -- #(vec3f color, vec2f diffuseTextureCoords, float alpha), normal(vec3f), lightmapUV(vec2f), fogFactor:f32
				maxBufferSize = GPU.MAX_BUFFER_SIZE, -- DEFAULT
				maxVertexBufferArrayStride = 20, -- #(Rml::Vertex)
				maxBindGroups = 3, -- Camera, material, transforms
				maxUniformBuffersPerShaderStage = 1, -- Camera properties (increase for material, soon?)
				maxSampledTexturesPerShaderStage = GPU.MAX_TEXTURE_ARRAY_SIZE,
				maxSamplersPerShaderStage = GPU.MAX_TEXTURE_ARRAY_SIZE,
				maxUniformBufferBindingSize = GPU.MAX_UNIFORM_BUFFER_BINDING_SIZE,
				maxBindingsPerBindGroup = 3, -- Max. allowed binding index
				maxDynamicUniformBuffersPerPipelineLayout = 1,
				minStorageBufferOffsetAlignment = 32,
				minUniformBufferOffsetAlignment = ffi.sizeof("mesh_uniform_t"),
			},
		}),
	})

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

	local function onDeviceError(errorType, message, userdata)
		local errorDetails = format("Type: %s, Message: %s", tonumber(errorType), ffi_string(message))
		error("Uncaptured device error - " .. errorDetails)
	end

	local jit = require("jit")
	jit.off(onDeviceError)

	deviceDescriptor.uncapturedErrorCallbackInfo.callback = onDeviceError
	webgpu.bindings.wgpu_adapter_request_device(adapter, deviceDescriptor, onDeviceRequested, nil)

	-- This is blocking in the wgpu-native implementation, but it might change in the future...

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

return GPU
