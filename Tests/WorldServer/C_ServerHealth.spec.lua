local C_ServerHealth = require("Core.World.C_ServerHealth")

describe("C_ServerHealth", function()
	describe("UpdateWithTickTime", function()
		before(function()
			C_ServerHealth.Reset()
		end)

		after(function()
			C_ServerHealth.Reset()
		end)

		it("should add the measured tick time to the current data set if a number value was passed", function()
			C_ServerHealth.UpdateWithTickTime(42)
			assertEquals(C_ServerHealth.GetSampleSize(), 1)
			assertEquals(C_ServerHealth.GetAccumulatedTickTime(), 42)

			C_ServerHealth.UpdateWithTickTime(100)
			C_ServerHealth.UpdateWithTickTime(1)
			assertEquals(C_ServerHealth.GetSampleSize(), 3)
			assertEquals(C_ServerHealth.GetAccumulatedTickTime(), 42 + 100 + 1)
		end)
	end)

	describe("ComputeMetricsOverInterval", function()
		before(function()
			C_ServerHealth.Reset()
		end)

		after(function()
			C_ServerHealth.Reset()
		end)

		it("should throw when the current data set is empty", function()
			local function computeMetricsOnEmptyDataSet()
				C_ServerHealth.Reset()
				C_ServerHealth.ComputeMetricsOverInterval(100)
			end
			local expectedErrorMessage = "Cannot compute server health metrics on an empty data set"
			assertThrows(computeMetricsOnEmptyDataSet, expectedErrorMessage)
		end)

		it("should throw when the observation interval is zero", function()
			local function computeMetricsOverZeroInterval()
				C_ServerHealth.Reset()
				C_ServerHealth.UpdateWithTickTime(1)
				C_ServerHealth.UpdateWithTickTime(2)
				C_ServerHealth.ComputeMetricsOverInterval(0)
			end
			local expectedErrorMessage = "Cannot compute server health metrics over a zero-length interval"
			assertThrows(computeMetricsOverZeroInterval, expectedErrorMessage)
		end)

		it("should return a table with the updated metrics when the current data set is not empty", function()
			C_ServerHealth.UpdateWithTickTime(44)
			C_ServerHealth.UpdateWithTickTime(103)
			C_ServerHealth.UpdateWithTickTime(12)

			local metrics = C_ServerHealth.ComputeMetricsOverInterval(1000)
			assertEquals(metrics.average, 53)
			assertEquals(metrics.minimum, 12)
			assertEquals(metrics.maximum, 103)
			assertEquals(metrics.median, 44)
			assertEqualNumbers(metrics.standardDeviation, 46.162755550335, 10e-5)
			assertEquals(metrics.ticksPerSecond, 3)
			assertEquals(metrics.interval, 1000)
			assertEquals(metrics.count, 3)
		end)
	end)

	describe("GetFormattedMetricsString", function()
		it("should return a formatted summary if a valid metrics table was passed", function()
			-- These aren't consistent (completely made-up data), but that makes no difference here
			local metrics = {
				average = 2.34567,
				minimum = 0.12345,
				maximum = 4.56789,
				median = 2.123456789,
				standardDeviation = 0.123456789,
				ticksPerSecond = 42,
				interval = 3333,
				count = 67,
			}

			local formatString = C_ServerHealth.GetFormattedMetricsString(metrics)
			local expectedFormatString =
				"Average tick time: 2.35 ms | Min: 0.12 ms | Max: 4.57 ms | Median: 2.12 ms | Std Dev: 0.12 ms | Sample: 67 ticks over 3333 ms (42 ticks/second)"
			assertEquals(formatString, expectedFormatString)
		end)
	end)
end)
