local REQUEST_RANDOM_PRESET_CHARACTER = [[
	typedef struct {
		const char* requestedCharacterName;
	} REQUEST_RANDOM_PRESET_CHARACTER;
]]

local PLAYER_ENTERING_WORLD = [[
	typedef struct {
		ushort mapID;
		ushort mapU;
		ushort mapV;
	} PLAYER_ENTERING_WORLD;
]]

local REQUEST_PLAYER_LOGOUT = [[
	typedef struct {
		// Placeholder
	} REQUEST_RANDOM_PRESET_CHARACTER;
]]

local messages = {
	-- Requests (from client to server)
	REQUEST_RANDOM_PRESET_CHARACTER,
	REQUEST_PLAYER_LOGOUT,
	-- World state updates (from server to client)
	PLAYER_ENTERING_WORLD,
}

return messages