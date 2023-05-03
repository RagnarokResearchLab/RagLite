local ffi = require("ffi")
local uv = require("uv")

local C_ServerHealth = require("Core.World.C_ServerHealth")

local TARGET_FPS = 50

local WorldServer = {
	worldStateUpdateTimer = nil,
	tickTimeInMilliseconds = 1000 / TARGET_FPS,
}

function WorldServer:Start()
	self:SetProcessTimerResolution()
	self:CreateWorldState()
	self:EnableHealthStatusUpdates()
	self:StartGameLoop()
end

function WorldServer:SetProcessTimerResolution()
	if ffi.os ~= "Windows" then
		return -- Linux/OSX should already use a 1ms clock by default
	end

	ffi.cdef([[
		typedef unsigned int UINT;
		UINT timeBeginPeriod(UINT uPeriod);
		UINT timeEndPeriod(UINT uPeriod);
	]])

	local winmm = ffi.load("winmm")
	-- The global clock cycle is 15.6ms on Windows, which delays libuv's timers far too long to reach the targeted tick rate
	assert(winmm.timeBeginPeriod(1), "Failed to set process timer resolution")
end

function WorldServer:EnableHealthStatusUpdates()
	local observationStartTimeInNanoseconds = uv.hrtime()
	self.healthStatusTicker = C_Timer.NewTicker(1000 * 10, function()
		local now = uv.hrtime()
		local elapsedTimeInNanoseconds = now - observationStartTimeInNanoseconds
		local elapsedTimeInMilliseconds = elapsedTimeInNanoseconds / 10E5
		self:HEALTH_STATUS_UPDATE(elapsedTimeInMilliseconds)
		observationStartTimeInNanoseconds = now
	end)
end

function WorldServer:HEALTH_STATUS_UPDATE(elapsedTimeInMilliseconds)
	local metrics = C_ServerHealth.ComputeMetricsOverInterval(elapsedTimeInMilliseconds)
	local healthStatusSummaryText = C_ServerHealth.GetFormattedMetricsString(metrics)

	print(healthStatusSummaryText)

	C_ServerHealth.Reset()
end

function WorldServer:StartGameLoop()
	self.worldStateUpdateTimer = C_Timer.NewTicker(self.tickTimeInMilliseconds, function()
		self:SimulateNextTick()
	end)
end

function WorldServer:SimulateNextTick()
	local timeBeforeUpdate = uv.hrtime()

	self:UpdateWorldState()

	local timeAfterUpdate = uv.hrtime()
	local lastTickDurationInNanoseconds = timeAfterUpdate - timeBeforeUpdate
	local lastTickDurationInMilliseconds = lastTickDurationInNanoseconds / 10E5

	C_ServerHealth.UpdateWithTickTime(lastTickDurationInMilliseconds)
end

function WorldServer:CreateWorldState()
	self:LoadSpawnData()
end

function WorldServer:LoadSpawnData()
	local creatureSpawns = dofile("DB/Creatures/classic-spawns.lua")
	for mapID, spawns in pairs(creatureSpawns) do
		printf("Processing creature spawns for %s", mapID)

		for _, spawnInfo in ipairs(spawns) do
			self:SpawnCreatures(mapID, spawnInfo)
		end
	end
end

function WorldServer:UpdateWorldState()
	-- NYI
end

function WorldServer:SpawnCreatures(mapID, spawnInfo)
	-- NYI
	printf("%s (%d) spawned in %s", spawnInfo.creatureID, spawnInfo.amount, mapID)
end

return WorldServer
