local NativeClient = require("Core.NativeClient.NativeClient")

-- set GRF_FILE_PATH
-- unset PERSISTENT_RESOURCES
local TEST_DURATION_IN_MILLISECONDS = 1000 * 3--15
C_Timer.After(TEST_DURATION_IN_MILLISECONDS, function()
	print("I guess that's enough? Time to pack it up and go home...")
	NativeClient:Stop()
end)

NativeClient:Start()
