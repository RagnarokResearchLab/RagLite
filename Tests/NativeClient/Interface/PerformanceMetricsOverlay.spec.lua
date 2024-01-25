local PerformanceMetricsOverlay = require("Core.NativeClient.Interface.PerformanceMetricsOverlay")

local EXAMPLE_METRICS_ENTRY = {
	totalFrameTime = 100,
	worldRenderTime = 200,
	interfaceRenderTime = 300,
	commandSubmissionTime = 600,
	uvPollingTime = 400,
	glfwPollingTime = 500,
	"totalFrameTime",
	"cpuRenderTime",
	"worldRenderTime",
	"interfaceRenderTime",
	"commandSubmissionTime",
	"uvPollingTime",
	"glfwPollingTime",
}

describe("PerformanceMetricsOverlay", function()
	after(function()
		-- Reset to start with a blank slate for every test case
		PerformanceMetricsOverlay:StartMeasuring()
		PerformanceMetricsOverlay:StopMeasuring()
	end)

	describe("StartMeasuring", function()
		it("should start tracking performance metrics", function()
			PerformanceMetricsOverlay:StartMeasuring()
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			assertEquals(PerformanceMetricsOverlay.samples.totalFrameTime, { 100 })
			assertEquals(PerformanceMetricsOverlay.samples.worldRenderTime, { 200 })
			assertEquals(PerformanceMetricsOverlay.samples.interfaceRenderTime, { 300 })
			assertEquals(PerformanceMetricsOverlay.samples.uvPollingTime, { 400 })
			assertEquals(PerformanceMetricsOverlay.samples.glfwPollingTime, { 500 })
			assertEquals(PerformanceMetricsOverlay.samples.commandSubmissionTime, { 600 })

			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			assertEquals(PerformanceMetricsOverlay.samples.totalFrameTime, { 100, 100 })
			assertEquals(PerformanceMetricsOverlay.samples.worldRenderTime, { 200, 200 })
			assertEquals(PerformanceMetricsOverlay.samples.interfaceRenderTime, { 300, 300 })
			assertEquals(PerformanceMetricsOverlay.samples.uvPollingTime, { 400, 400 })
			assertEquals(PerformanceMetricsOverlay.samples.glfwPollingTime, { 500, 500 })
			assertEquals(PerformanceMetricsOverlay.samples.commandSubmissionTime, { 600, 600 })
		end)

		it("should reset all stored metrics", function()
			PerformanceMetricsOverlay:StartMeasuring()
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:StartMeasuring()
			assertEquals(PerformanceMetricsOverlay.samples, {})
			PerformanceMetricsOverlay:StopMeasuring()
		end)
	end)

	describe("StopMeasuring", function()
		it("should stop tracking performance metrics", function()
			PerformanceMetricsOverlay:StartMeasuring()
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:StopMeasuring()
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			assertEquals(PerformanceMetricsOverlay.samples.totalFrameTime, { 100 })
			assertEquals(PerformanceMetricsOverlay.samples.worldRenderTime, { 200 })
			assertEquals(PerformanceMetricsOverlay.samples.interfaceRenderTime, { 300 })
			assertEquals(PerformanceMetricsOverlay.samples.uvPollingTime, { 400 })
			assertEquals(PerformanceMetricsOverlay.samples.glfwPollingTime, { 500 })
			assertEquals(PerformanceMetricsOverlay.samples.commandSubmissionTime, { 600 })
		end)
	end)

	describe("GetFormattedMetricsString", function()
		it("should return a placeholder string if no samples have been added yet", function()
			local actual = PerformanceMetricsOverlay:GetFormattedMetricsString()
			local expected = PerformanceMetricsOverlay.messageStrings.NO_SAMPLES_AVAILABLE
			assertEquals(actual, expected)
		end)

		it("should return a human-readable summary of the sampled metrics", function()
			PerformanceMetricsOverlay:StartMeasuring()

			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)
			PerformanceMetricsOverlay:AddSample(EXAMPLE_METRICS_ENTRY)

			local actual = PerformanceMetricsOverlay:GetFormattedMetricsString()
			local expected =
				"totalFrameTime: 100.00 ms | cpuRenderTime: nan ms | worldRenderTime: 200.00 ms | interfaceRenderTime: 300.00 ms | commandSubmissionTime: 600.00 ms | uvPollingTime: 400.00 ms | glfwPollingTime: 500.00 ms"
			assertEquals(actual, expected)
		end)

		it("should allow overriding the format for non-standard types of metrics", function()
			PerformanceMetricsOverlay:StartMeasuring()

			local metricsEntry = {
				Memory = 1024,
				Percentage = 56.75345,
				Time = 250,
				"Memory",
				"Percentage",
				"Time",
			}
			PerformanceMetricsOverlay:AddSample(metricsEntry)
			PerformanceMetricsOverlay:AddSample(metricsEntry)

			PerformanceMetricsOverlay.formatOverrides.Memory = "%s: %d MB%s"
			PerformanceMetricsOverlay.formatOverrides.Percentage = "%s: %.2f %%%s"
			PerformanceMetricsOverlay.formatOverrides.Time = "%s: %d milliseconds%s"

			local actual = PerformanceMetricsOverlay:GetFormattedMetricsString()
			local expected = "Memory: 1024 MB | Percentage: 56.75 % | Time: 250 milliseconds"
			assertEquals(actual, expected)
		end)

		describe("ComputeResourceUsageForInterval", function()
			local function uvMakeResourceUsage(seconds, microseconds)
				return {
					utime = { sec = seconds, usec = microseconds },
					stime = { sec = 0, usec = 0 }, -- stime is ignored since it may be async background tasks etc.
				}
			end

			it("should compute the resource usage if the measured interval is zero", function()
				local initialUsage = uvMakeResourceUsage(1, 500000) -- 1.5 seconds
				local finalUsage = uvMakeResourceUsage(1, 500000) -- 1.5 seconds
				local measuredIntervalInMilliseconds = 0 -- 1 second
				local expected = 0
				local actual = PerformanceMetricsOverlay:ComputeResourceUsageForInterval(
					initialUsage,
					finalUsage,
					measuredIntervalInMilliseconds
				)
				assertEquals(actual, expected)
			end)

			it("should compute the resource usage correctly if it's 0%", function()
				local initialUsage = uvMakeResourceUsage(1, 500000) -- 1.5 seconds
				local finalUsage = uvMakeResourceUsage(1, 500000) -- 1.5 seconds
				local measuredIntervalInMilliseconds = 1000 -- 1 second
				local expected = 0
				local actual = PerformanceMetricsOverlay:ComputeResourceUsageForInterval(
					initialUsage,
					finalUsage,
					measuredIntervalInMilliseconds
				)
				assertEquals(actual, expected)
			end)

			it("should compute the resource usage correctly if it's 100%", function()
				local initialUsage = uvMakeResourceUsage(0, 500000) -- 0.5 seconds
				local finalUsage = uvMakeResourceUsage(1, 0) -- 1 second
				local measuredIntervalInMilliseconds = 500 -- 0.5 second
				local expected = 100 -- 100% CPU usage
				local actual = PerformanceMetricsOverlay:ComputeResourceUsageForInterval(
					initialUsage,
					finalUsage,
					measuredIntervalInMilliseconds
				)
				assertEquals(actual, expected)
			end)

			it("should compute the resource usage correctly if it's more than 100%", function()
				local initialUsage = uvMakeResourceUsage(0, 500000) -- 0.5 seconds
				local finalUsage = uvMakeResourceUsage(2, 0) -- 1 second
				local measuredIntervalInMilliseconds = 500 -- 0.5 second
				local expected = 300 -- 300% CPU usage (probably a measurement error or timer inaccuracy - ignore it)
				local actual = PerformanceMetricsOverlay:ComputeResourceUsageForInterval(
					initialUsage,
					finalUsage,
					measuredIntervalInMilliseconds
				)
				assertEquals(actual, expected)
			end)

			it("should compute the resource usage correctly over the provided duration", function()
				local initialUsage = uvMakeResourceUsage(1, 0) -- 1 second
				local finalUsage = uvMakeResourceUsage(2, 0) -- 2 seconds
				local measuredIntervalInMilliseconds = 2000 -- 2 seconds
				local expected = 50 -- 50% CPU usage
				local actual = PerformanceMetricsOverlay:ComputeResourceUsageForInterval(
					initialUsage,
					finalUsage,
					measuredIntervalInMilliseconds
				)
				assertEquals(actual, expected)
			end)
		end)
	end)
end)
