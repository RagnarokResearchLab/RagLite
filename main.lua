local uv = require("uv")

local RealmServer = require("Core.RealmServer")

local WorldServer = {}

function WorldServer:StartGameLoop()
	local TARGET_FPS = 50
	local serverTickTimeInMilliseconds = 1000 / TARGET_FPS

	self:CreateWorldState()

	while true do
		local timeBeforeUpdate = uv.hrtime()

		self:UpdateWorldState()

		local timeAfterUpdate = uv.hrtime()
		local lastTickDurationInNanoseconds = timeAfterUpdate - timeBeforeUpdate
		local lastTickDurationInMilliseconds = lastTickDurationInNanoseconds / 10E5
		-- print("Last tick time", lastTickDurationInMilliseconds)

		local remainingTickTime = math.max(0, serverTickTimeInMilliseconds - lastTickDurationInMilliseconds)
		-- print("Sleeping for the remaining tick time", remainingTickTime)
		uv.sleep(remainingTickTime) -- TODO inaccuarate on Windows, should use QueryPerformanceCounter?
		uv.run("once") -- Will never get to the runtime's default loop, so poll manually
	end
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

RealmServer:Start()
WorldServer:StartGameLoop()
