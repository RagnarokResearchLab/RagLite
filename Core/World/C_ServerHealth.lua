local format = string.format
local ipairs = ipairs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local table_insert = table.insert
local table_sort = table.sort
local unpack = unpack

local C_ServerHealth = {
	tickDurations = {},
}

function C_ServerHealth.UpdateWithTickTime(measuredTickTimeInMilliseconds)
	table_insert(C_ServerHealth.tickDurations, measuredTickTimeInMilliseconds)
end

function C_ServerHealth.GetSampleSize()
	return #C_ServerHealth.tickDurations
end

function C_ServerHealth.Reset()
	C_ServerHealth.tickDurations = {}
end

function C_ServerHealth.GetAccumulatedTickTime()
	local accumulatedTickTimeInMilliseconds = 0
	for index, tickTimeInMilliseconds in ipairs(C_ServerHealth.tickDurations) do
		accumulatedTickTimeInMilliseconds = accumulatedTickTimeInMilliseconds + tickTimeInMilliseconds
	end
	return accumulatedTickTimeInMilliseconds
end

function C_ServerHealth.ComputeMetricsOverInterval(observationIntervalInMilliseconds)
	if observationIntervalInMilliseconds == 0 then
		error("Cannot compute server health metrics over a zero-length interval", 0)
	end

	local accumulatedTickDuration = C_ServerHealth.GetAccumulatedTickTime()
	local tickCount = C_ServerHealth.GetSampleSize()
	local tickDurations = C_ServerHealth.tickDurations

	if tickCount == 0 then
		error("Cannot compute server health metrics on an empty data set", 0)
	end

	if tickCount == 1 then
		error("Cannot compute server health metrics for a single data point", 0)
	end

	local averageTickDuration = accumulatedTickDuration / tickCount

	local minTickDuration = math_min(unpack(tickDurations))
	local maxTickDuration = math_max(unpack(tickDurations))

	table_sort(tickDurations)
	local medianTickDuration
	local isSampleSizeEven = (tickCount % 2 == 0)
	if isSampleSizeEven then
		-- By convention: Use arithmetic mean of the two middle values
		medianTickDuration = (tickDurations[tickCount / 2] + tickDurations[(tickCount / 2) + 1]) / 2
	else
		-- Trivial case
		medianTickDuration = tickDurations[math_ceil(tickCount / 2)]
	end

	-- Standard deviation for the limited sample (we don't have all tick times ever generated)
	local variance = 0
	for _, duration in ipairs(tickDurations) do
		local squaredDifference = (duration - averageTickDuration) ^ 2
		variance = variance + squaredDifference
	end
	variance = variance / (tickCount - 1) -- One degree of freedom lost since the sample is limited
	local standardDeviation = math_sqrt(variance)

	local observationTimeInSeconds = (observationIntervalInMilliseconds / 1000)
	local ticksPerSecond = tickCount / observationTimeInSeconds

	return {
		average = averageTickDuration,
		minimum = minTickDuration,
		maximum = maxTickDuration,
		median = medianTickDuration,
		standardDeviation = standardDeviation,
		ticksPerSecond = ticksPerSecond,
		interval = observationIntervalInMilliseconds,
		count = tickCount,
	}
end

function C_ServerHealth.GetFormattedMetricsString(metrics)
	return format(
		"Average tick time: %.2f ms | Min: %.2f ms | Max: %.2f ms | Median: %.2f ms | Std Dev: %.2f ms | Sample: %d ticks over %d ms (%d ticks/second)",
		metrics.average,
		metrics.minimum,
		metrics.maximum,
		metrics.median,
		metrics.standardDeviation,
		metrics.count,
		metrics.interval,
		math_floor(metrics.ticksPerSecond + 0.5)
	)
end

return C_ServerHealth
