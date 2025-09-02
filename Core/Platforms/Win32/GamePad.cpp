#include <xinput.h>

GLOBAL bool APPLICATION_USES_GAMEPAD = false;

void GamePadPollControllers(int& offsetX, int& offsetY) {

	if(!APPLICATION_USES_GAMEPAD) return;

	constexpr DWORD MAX_SUPPORTED_GAMEPAD_COUNT = XUSER_MAX_COUNT;
	for(DWORD gamePadID = 0; gamePadID < MAX_SUPPORTED_GAMEPAD_COUNT; ++gamePadID) {
		XINPUT_STATE gamePadButtonState;
		if(XInputGetState(gamePadID, &gamePadButtonState) != ERROR_SUCCESS) {
			TODO("XInput detected a GamePad but it wasn't usable?\n")
		}

		XINPUT_GAMEPAD* gamePad = &gamePadButtonState.Gamepad;
		int16 stickX = gamePad->sThumbLX;
		int16 stickY = gamePad->sThumbLY;
		offsetX += stickX >> 12;
		offsetY += stickY >> 12;
	}
}
