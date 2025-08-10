#pragma once

#ifdef _WIN32
#define RAGLITE_PLATFORM_WINDOWS
#elifdef __APPLE__
#define RAGLITE_PLATFORM_MACOS
#elifdef __linux__
#define RAGLITE_PLATFORM_LINUX
#else
#define RAGLITE_UNSUPPORTED_PLATFORM
#endif

#ifdef RAGLITE_UNSUPPORTED_PLATFORM
#error "Unsupported Platform: OS-specific code paths have yet to be ported"
#endif

#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
	MessageBoxA(0, "Hello world", "RagLite2", MB_OK | MB_ICONINFORMATION);
}
