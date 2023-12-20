package.path = "?.lua"

local NativeClient = require("Core.NativeClient.NativeClient")

if arg[1] == "--etrace" then
	local etrace = require("Core.RuntimeExtensions.etrace")
	-- The Renderer (and WebGPU modules) have to be loaded prior to this so their events are registered
	etrace.enable()

	C_Timer.NewTicker(1000, function()
		-- Dumping traces once per frame isn't currently needed and a little wasteful
		printf("Dumping traced events for the last rendered frame...")
		dump(etrace.filter())
	end)
	_G.arg[1] = nil -- Don't try to load it as a scene
elseif arg[1] == "--stresstest" then
	C_Timer.After(2000, function()
		NativeClient:LoadScenesOneByOne(arg[2])
	end)
	_G.arg[1] = nil -- Don't try to load it as a scene
end

local mapID = arg[1]
NativeClient:Start(mapID)
