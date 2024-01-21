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
	end)
end)
