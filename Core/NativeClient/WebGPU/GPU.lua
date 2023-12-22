local Texture = require("Core.NativeClient.WebGPU.Texture")

local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("webgpu")

local new = ffi.new

local GPU = {
	MAX_VERTEX_COUNT = 200000, -- Should be configurable (later)
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
	local numComponentsPerVertex = 3 -- sizeof(Vertex3D) = positions (x, y, z)

	local deviceDescriptor = new("WGPUDeviceDescriptor", {
		label = options.label,
		defaultQueue = {
			label = options.defaultQueue.label,
		},
		requiredFeatureCount = options.requiredFeatureCount,
		requiredLimits = new("WGPURequiredLimits", {
			limits = {
				maxTextureDimension1D = 0,
				maxTextureDimension2D = Texture.MAX_TEXTURE_DIMENSION,
				maxTextureDimension3D = 0,
				maxTextureArrayLayers = 1, -- For the depth/stencil texture
				maxVertexAttributes = 3, -- Vertex positions, vertex colors, diffuse texture UVs
				maxVertexBuffers = 3, -- Vertex positions, vertex colors, diffuse texture UVs
				maxInterStageShaderComponents = 5, -- sizeof(VertexOutput\{#@builtins}) = #(vec3f color, vec2f diffuseTextureCoords)
				maxBufferSize = self.MAX_VERTEX_COUNT * numComponentsPerVertex * ffi.sizeof("float"),
				maxVertexBufferArrayStride = numComponentsPerVertex * ffi.sizeof("float"),
				maxBindGroups = 2, -- Camera, material (increase for model transforms, later?)
				maxUniformBuffersPerShaderStage = 1, -- Camera properties (increase for material, soon?)
				maxSampledTexturesPerShaderStage = 1, -- Diffuse texture (increase for lightmaps, later?)
				maxSamplersPerShaderStage = 1, -- Diffuse texture sampler (increase for lightmaps, later?)
				maxUniformBufferBindingSize = 48 * ffi.sizeof("float"),
				maxBindingsPerBindGroup = 1, -- Max. allowed binding index
				minStorageBufferOffsetAlignment = supportedLimits.limits.minStorageBufferOffsetAlignment,
				minUniformBufferOffsetAlignment = supportedLimits.limits.minUniformBufferOffsetAlignment,
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
					ffi.string(message)
				)
			)
		end
		requestedDevice = device
	end
	webgpu.bindings.wgpu_adapter_request_device(adapter, deviceDescriptor, onDeviceRequested, nil)

	-- This is blocking in the wgpu-native implementation, but it might change in the future...
	assert(requestedDevice, "onDeviceRequested did not trigger, but it should have")

	local function onDeviceError(errorType, message, userdata)
		local errorDetails = format("Type: %s, Message: %s", tonumber(errorType), ffi.string(message))
		error("Uncaptured device error - " .. errorDetails)
	end

	webgpu.bindings.wgpu_device_set_uncaptured_error_callback(requestedDevice, onDeviceError, nil)

	return requestedDevice, deviceDescriptor
end

return GPU
