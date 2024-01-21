local format = string.format
local ipairs = ipairs
local tconcat = table.concat
local tinsert = table.insert

local PerformanceMetricsOverlay = {
	samples = {},
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
		tinsert(sampleStrings, format("%s: %.2f ms%s", name, avg, separator))
	end

	return tconcat(sampleStrings, "")
end

return PerformanceMetricsOverlay
