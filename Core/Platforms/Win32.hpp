#pragma once

#include "../StandardLibrary/NullTerminatedString.hpp"

#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <strsafe.h>
#include <timeapi.h>

typedef enum standard_device_identifier {
	PLATFORM_DEVICE_STDIN = STD_INPUT_HANDLE,
	PLATFORM_DEVICE_STDOUT = STD_OUTPUT_HANDLE,
	PLATFORM_DEVICE_STDERR = STD_ERROR_HANDLE,
} std_device_id_t;

typedef enum standard_device_action {
	PLATFORM_ACTION_CREATE,
	PLATFORM_ACTION_REUSE,
	PLATFORM_CONSOLE_NEWLINE,
} std_device_action_t;

enum platform_exit_code_t : int32 {
	EXIT_SUCCESS = 0,
	EXIT_FAILURE = 1,
	TEST_FAILURE = 2,
};

// #if defined(_DEBUG) // TBD is this standard?
// #if defined(_DEBUG) // TBD defined vs ifdef
#ifdef RAGLITE_GRAPHICAL_INTERFACE
// TBD attachOp flags?
// TBD freopen_s = ??
static void
PlatformAttachDevice(std_device_id_t what, std_device_action_t how) {
	// AllocConsole();
	// TODO how = CREATE_NEW_CONSOLE, REUSE_PARENT_CONSOLE
	if(how == PLATFORM_ACTION_CREATE) AllocConsole();
	if(how == PLATFORM_ACTION_REUSE) AttachConsole(ATTACH_PARENT_PROCESS);
	// TBD why is it blocking if attached to parent?
	FILE* dummy;
	// if(what == PLATFORM_DEVICE_STDIN)  freopen_s(&dummy, "CONIN$", "rw", stdin);
	if(what == PLATFORM_DEVICE_STDOUT) freopen_s(&dummy, "CONOUT$", "w", stdout);
	if(what == PLATFORM_DEVICE_STDERR) freopen_s(&dummy, "CONOUT$", "w", stderr);
}
#else
// Terminal should already be attached when running in a command-line environment
// TODO NOOP macro
#define PlatformAttachDevice() ((void)0)
#endif

// typedef platform_api_result {
// result type/status: OK, incomplete, failed
// message/ID
// type: fatal, warn, info
// } platform_result_t;

bool PlatformDeviceOutput(const char* message, std_device_id_t deviceID
	// , std_device_action_t mode
) {
	HANDLE deviceHandle = GetStdHandle(deviceID);
	if(!deviceHandle) return false;

	// TBD something seems fishy here, check in console/GUI app
	ASSUME(deviceHandle != INVALID_HANDLE_VALUE, "Cannot write to invalid device handle");

	DWORD numBytesWritten;
	DWORD messageLength = (DWORD)NullTerminatedStringLength(message);
	WriteFile(deviceHandle, message, messageLength, &numBytesWritten, NULL);
	ASSUME(numBytesWritten == messageLength, "Incomplete write to output device");

	// if(mode == PLATFORM_CONSOLE_NEWLINE) {
	// 	WriteFile(deviceHandle, "\r\n", 2, &numBytesWritten, NULL);
	// 	ASSUME(numBytesWritten == 2, "Incomplete write to output device");
	// }

	return true;
}

bool PlatformStandardOutput(const char* message) { // TBD PlatformOutput
	return PlatformDeviceOutput(message, PLATFORM_DEVICE_STDOUT);
}

bool PlatformStandardError(const char* message) {
	return PlatformDeviceOutput(message, PLATFORM_DEVICE_STDERR);
}

// TODO counted strings...
// TODO message type (fatal, info.?) -> Rename to PlatformShowMessage(text, title, type)
void PlatformAlertPopup(const char* message, const char* title) {
	// const char* title = "Fatal Error";
	// char *title = "Oh no! Something went horribly wrong...";

	UINT messageBoxType = MB_OK;
	// if(messageType == FATAL)
	// {
	// title = "Fatal Error";
	messageBoxType |= MB_ICONSTOP;
	// }
	// else
	// {
	// messageBoxType |= MB_ICONWARNING;
	// }

	MessageBoxExA(NULL, message, title, messageBoxType, 0);
	// if(messageType == FATAL)
	// {
	ExitProcess(EXIT_FAILURE);
	// }
}

void PlatformProcessExit(platform_exit_code_t exitCode) {
	ExitProcess(exitCode);
}
