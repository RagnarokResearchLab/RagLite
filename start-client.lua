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
end

NativeClient:Start()
