local console = require("console")
local uv = require("uv")

local WorldServer = require("Core.WorldServer")
local C_ServerHealth = require("Core.World.C_ServerHealth")

local function simulateServerTick()
	local startTime = uv.hrtime()

	WorldServer:SimulateNextTick()

	local endTime = uv.hrtime()
	local tickTimeInNanoseconds = endTime - startTime
	local tickTimeInMilliseconds = tickTimeInNanoseconds / 10E5

	return tickTimeInMilliseconds
end

local function updateHealthStatusWithTickTime(tickTime)
	WorldServer:HEALTH_STATUS_UPDATE(tickTime)
end

describe("WorldServer", function()
	describe("HEALTH_STATUS_UPDATE", function()
		before(function()
			C_ServerHealth.Reset()
		end)

		after(function()
			C_ServerHealth.Reset()
		end)

		it("should output server health metrics to the console if at least two ticks were simulated", function()
			local function assertCapturedOutputContainsMetricsString(capturedOutput)
				-- Don't care about the exact values being displayed as they're covered by separate unit tests
				local lines = string.explode(capturedOutput, "\n")

				local hasPrintedHealthStatus = false
				for index, line in ipairs(lines) do
					-- This assumes the format doesn't suddenly change, but it probably won't
					local hasAvgTickTime = line:match("Average tick time: %d+%.%d%d ms")
					local hasMin = line:match("Min: %d+%.%d%d ms")
					local hasMax = line:match("Max: %d+%.%d%d ms")
					local hasMedian = line:match("Median: %d+%.%d%d ms")
					local hasStandardDeviation = line:match("Std Dev: %d+%.%d%d ms")
					local hasSampleInfo = line:match("Sample: %d+ ticks over %d+ ms %(%d+ ticks/second%)")
					local hasPrintedMetricsAtLeastOnce = hasAvgTickTime
						and hasMin
						and hasMax
						and hasMedian
						and hasStandardDeviation
						and hasSampleInfo

					if hasPrintedMetricsAtLeastOnce then
						-- If metrics are printed multiple times in the given interval, that's fine (though unlikely)
						hasPrintedHealthStatus = true
					end
				end
				assertTrue(hasPrintedHealthStatus)
			end

			local firstTickTime = simulateServerTick()
			local secondTickTime = simulateServerTick()

			console.capture()
			assert(pcall(updateHealthStatusWithTickTime, firstTickTime + secondTickTime))
			local capturedOutput = console.release()

			-- May contain other output, which is irrelevant for this test
			assertCapturedOutputContainsMetricsString(capturedOutput)
		end)

		it("should reset any stored health status information after it has finished running", function()
			simulateServerTick()
			simulateServerTick()

			-- Should work because there are two data points
			console.capture()
			updateHealthStatusWithTickTime(12345)
			console.release()

			-- Should NOT work because the data points would have been deleted
			local expectedErrorMessage = "Cannot compute server health metrics on an empty data set"

			local function updateHealthStatusWithoutNewData()
				updateHealthStatusWithTickTime(12345)
			end

			assertThrows(updateHealthStatusWithoutNewData, expectedErrorMessage)
		end)
	end)
end)
