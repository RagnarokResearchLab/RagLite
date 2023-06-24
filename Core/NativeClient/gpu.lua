local ffi = require("ffi")
local glfw = require("glfw")
local webgpu = require("webgpu")

local gpu = {}

function gpu.createInstance()
	local instanceDescriptor = ffi.new("WGPUInstanceDescriptor")
	local instance = webgpu.bindings.wgpu_create_instance(instanceDescriptor)
	if not instance then
		error("Could not initialize WebGPU")
	end

	return instance, instanceDescriptor
end

function gpu.requestAdapter(instance, window)
	local surface = glfw.bindings.glfw_get_wgpu_surface(instance, window)

	local adapterOptions = ffi.new("WGPURequestAdapterOptions")
	adapterOptions.compatibleSurface = surface

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

function gpu.requestLogicalDevice(adapter, options)
	options = options or {}
	options.defaultQueue = options.defaultQueue or {}

	options.label = options.label or "Logical WebGPU Device"
	options.requiredFeaturesCount = options.requiredFeaturesCount or 0
	options.defaultQueue.label = options.defaultQueue.label or "Default Queue"

	local deviceDescriptor = ffi.new("WGPUDeviceDescriptor")
	deviceDescriptor.label = options.label
	deviceDescriptor.requiredFeaturesCount = options.requiredFeaturesCount
	deviceDescriptor.defaultQueue.label = options.defaultQueue.label

	local requestedDevice
	local function onDeviceRequested(status, device, message, userdata)
		assert(status == ffi.C.WGPURequestDeviceStatus_Success, "Failed to request logical WebGPU device")
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

return gpu
