local format = string.format
local ipairs = ipairs
local tconcat = table.concat
local tinsert = table.insert

local PerformanceMetricsOverlay = {
	samples = {},
	formatOverrides = {},
	isEnabled = false,
	messageStrings = {
		NO_SAMPLES_AVAILABLE = "No performance metrics available at this time",
	},
}

function PerformanceMetricsOverlay:StartMeasuring()
	self.isEnabled = true
	self.samples = {}
end

function PerformanceMetricsOverlay:StopMeasuring()
	self.isEnabled = false
end
function PerformanceMetricsOverlay:AddSample(sample)
	if not self.isEnabled then
		return
	end

	for index, name in ipairs(sample) do
		local value = sample[name]
		local isNewMetric = (self.samples[name] == nil)
		if isNewMetric then
			self.samples[name] = self.samples[name] or {}
			tinsert(self.samples, name)
		end
		tinsert(self.samples[name], value)
	end
end

function PerformanceMetricsOverlay:GetFormattedMetricsString()
	if not self.isEnabled then
		return self.messageStrings.NO_SAMPLES_AVAILABLE
	end

	local sampleStrings = {}
	for index, name in ipairs(self.samples) do
		-- Fancy statistics aren't needed here, as sampling is expected to be enabled only temporarily
		local values = self.samples[name]
		local sum, count = 0, 0
		for _, value in ipairs(values) do
			sum = sum + value
			count = count + 1
		end
		local avg = sum / count

		local isLastMetric = (index == #self.samples)
		local separator = isLastMetric and "" or " | "
		local formatString = self.formatOverrides[name] or "%s: %.2f ms%s"
		tinsert(sampleStrings, format(formatString, name, avg, separator))
	end

	return tconcat(sampleStrings, "")
end

local function toMicroseconds(time)
	return time.sec * 1E6 + time.usec
end

function PerformanceMetricsOverlay:ComputeResourceUsageForInterval(
	initialResourceUsage,
	finalUsage,
	measuredIntervalInMilliseconds
)
	if measuredIntervalInMilliseconds <= 0 then
		return 0
	end

	local initialTotal = toMicroseconds(initialResourceUsage.utime)
	local finalTotal = toMicroseconds(finalUsage.utime)

	local cpuTimeUsedInMicroseconds = finalTotal - initialTotal
	local elapsedTimeInMicroseconds = measuredIntervalInMilliseconds * 1E3

	return (cpuTimeUsedInMicroseconds / elapsedTimeInMicroseconds) * 100
end

return PerformanceMetricsOverlay
