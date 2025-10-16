#include <xinput.h>

typedef struct gamepad_controller_state {
	int16 stickX;
	int16 stickY;
} gamepad_state_t;

GLOBAL bool APPLICATION_USES_GAMEPAD = false;

INTERNAL void GamePadPollControllers(gamepad_state_t& controllerInputs) {

	if(!APPLICATION_USES_GAMEPAD) return;

	constexpr DWORD MAX_SUPPORTED_GAMEPAD_COUNT = XUSER_MAX_COUNT;
	for(DWORD gamePadID = 0; gamePadID < MAX_SUPPORTED_GAMEPAD_COUNT; ++gamePadID) {
		XINPUT_STATE gamePadButtonState;
		if(XInputGetState(gamePadID, &gamePadButtonState) != ERROR_SUCCESS) {
			TODO("XInput detected a GamePad but it wasn't usable?\n")
		}

		XINPUT_GAMEPAD* gamePad = &gamePadButtonState.Gamepad;
		controllerInputs.stickX = gamePad->sThumbLX;
		controllerInputs.stickY = gamePad->sThumbLY;
	}
}
