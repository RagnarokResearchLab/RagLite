#include <xinput.h>

GLOBAL bool APPLICATION_USES_GAMEPAD = false;

INTERNAL void GamePadPollControllers(gamepad_state_t& controllerInputs) {

	if(!APPLICATION_USES_GAMEPAD) return;

	constexpr DWORD MAX_SUPPORTED_GAMEPAD_COUNT = XUSER_MAX_COUNT;
	for(DWORD gamePadID = 0; gamePadID < MAX_SUPPORTED_GAMEPAD_COUNT; ++gamePadID) {
		XINPUT_STATE gamePadButtonState = {};
		DWORD result = XInputGetState(gamePadID, &gamePadButtonState);
		ASSUME(result != ERROR_DEVICE_NOT_CONNECTED, "GamePad detected, but not connected (...how does that work?)");
		ASSUME(result == ERROR_SUCCESS, "GamePad detected, but it wasn't usable - despite being connected (...why?)");

		XINPUT_GAMEPAD* gamePad = &gamePadButtonState.Gamepad;
		controllerInputs.stickX = gamePad->sThumbLX;
		controllerInputs.stickY = gamePad->sThumbLY;
	}
}
