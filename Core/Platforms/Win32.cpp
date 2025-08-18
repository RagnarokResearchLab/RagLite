#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <strsafe.h>
#include <timeapi.h>

#define TODO(msg) OutputDebugStringA(msg);

GLOBAL FPS TARGET_FRAME_RATE = 120;

constexpr size_t MAX_ERROR_MSG_SIZE = 512;
GLOBAL TCHAR SYSTEM_ERROR_MESSAGE[MAX_ERROR_MSG_SIZE];

INTERNAL LPTSTR FormatErrorString(DWORD errorCode) {
	DWORD size = FormatMessage(
		FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		errorCode,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
		SYSTEM_ERROR_MESSAGE,
		MAX_ERROR_MSG_SIZE,
		NULL);

	if(size == 0) {
		StringCbPrintfA(SYSTEM_ERROR_MESSAGE, MAX_ERROR_MSG_SIZE, TEXT("Unknown error %lu"), errorCode);
	} else {
		LPTSTR end = SYSTEM_ERROR_MESSAGE + lstrlen(SYSTEM_ERROR_MESSAGE);
		while(end > SYSTEM_ERROR_MESSAGE && (end[-1] == TEXT('\r') || end[-1] == TEXT('\n') || end[-1] == TEXT('.')))
			*--end = TEXT('\0');
	}

	return SYSTEM_ERROR_MESSAGE;
}

typedef LONG(WINAPI* RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);
GLOBAL TCHAR NTDLL_VERSION_STRING[MAX_ERROR_MSG_SIZE] = "OS: N/A (Failed to GetModuleHandle for NTDLL.DLL)";

void ReadKernelVersionInfo() {
	// TODO Skip this in release builds; it's way too intrusive for no real benefit
#if 1
	HMODULE kernelModuleDLL = GetModuleHandleW(L"ntdll.dll");
	if(kernelModuleDLL) {
		RTL_OSVERSIONINFOW kernelVersionInfo = {};
		kernelVersionInfo.dwOSVersionInfoSize = sizeof(kernelVersionInfo);
		RtlGetVersionPtr pRtlGetVersion = (RtlGetVersionPtr)GetProcAddress(kernelModuleDLL, "RtlGetVersion");
		if(pRtlGetVersion && pRtlGetVersion((PRTL_OSVERSIONINFOW)&kernelVersionInfo) == 0) {
			StringCbPrintfA(NTDLL_VERSION_STRING, MAX_ERROR_MSG_SIZE,
				"Operating System: Windows %u.%u (Build %u) %S",
				kernelVersionInfo.dwMajorVersion,
				kernelVersionInfo.dwMinorVersion,
				kernelVersionInfo.dwBuildNumber,
				kernelVersionInfo.szCSDVersion);
		} else {
		}
	}
#endif
}

const char* ArchitectureToDebugName(WORD wProcessorArchitecture) {

	const char* arch = "Unknown";
	switch(wProcessorArchitecture) {
	case PROCESSOR_ARCHITECTURE_AMD64:
		arch = "x64";
		break;
	case PROCESSOR_ARCHITECTURE_INTEL:
		arch = "x86";
		break;
	case PROCESSOR_ARCHITECTURE_ARM:
		arch = "ARM";
		break;
	case PROCESSOR_ARCHITECTURE_ARM64:
		arch = "ARM64";
		break;
	case PROCESSOR_ARCHITECTURE_IA64:
		arch = "Itanium";
		break;
	}
	return arch;
}

#include "Win32/GamePad.cpp"
#include "Win32/Keyboard.cpp"
#include "Win32/Time.cpp"
#include "Win32/Memory.cpp"
#include "Win32/Windowing.cpp"

#include "Win32/DebugDraw.cpp"

LRESULT CALLBACK WindowProcessMessage(HWND window, UINT message, WPARAM wParam,
	LPARAM lParam) {
	LRESULT result = 0;

	switch(message) {
	case WM_CREATE: {
		TODO("Received WM_CREATE\n");
		// TODO Initialize child windows here?
	} break;

	case WM_SIZE: {
		SurfaceGetWindowDimensions(GDI_SURFACE, window);
		ResizeBackBuffer(GDI_BACKBUFFER, GDI_SURFACE.width, GDI_SURFACE.height,
			window);
	} break;

	case WM_PAINT: {
		PAINTSTRUCT paintInfo;
		HDC hdc = BeginPaint(window, &paintInfo);
		GDI_SURFACE.displayDeviceContext = hdc;

		if(!GDI_SURFACE.offscreenDeviceContext || !GDI_BACKBUFFER.activeHandle) {
			EndPaint(window, &paintInfo);
			return 0;
		}

		DebugDrawMemoryUsageOverlay(GDI_SURFACE);
		DebugDrawProcessorUsageOverlay(GDI_SURFACE);
		DebugDrawKeyboardOverlay(GDI_SURFACE);

		int srcW = GDI_BACKBUFFER.width;
		int srcH = GDI_BACKBUFFER.height;
		int destW = GDI_SURFACE.width;
		int destH = GDI_SURFACE.height;
		if(!StretchBlt(hdc, 0, 0, destW, destH, GDI_SURFACE.offscreenDeviceContext,
			   0, 0, srcW, srcH, SRCCOPY)) {
			TODO("StretchBlt failed in WM_PAINT\n");
		}

		EndPaint(window, &paintInfo);
		return 0;

	} break;

	case WM_SYSKEYDOWN:
	case WM_SYSKEYUP:
	case WM_KEYDOWN:
	case WM_KEYUP: {
		DebugDrawKeyboardOverlay(GDI_SURFACE);
		DebugDrawMemoryUsageOverlay(GDI_SURFACE);

		WORD virtualKeyCode = LOWORD(wParam);
		WORD keyFlags = HIWORD(lParam);
		WORD scanCode = LOBYTE(keyFlags);
		BOOL isExtendedKey = (keyFlags & KF_EXTENDED) == KF_EXTENDED;

		if(isExtendedKey)
			scanCode = MAKEWORD(scanCode, 0xE0);

		BOOL wasKeyDown = (keyFlags & KF_REPEAT) == KF_REPEAT;
		WORD repeatCount = LOWORD(lParam);

		BOOL isKeyReleased = (keyFlags & KF_UP) == KF_UP;
		BOOL isKeyDown = !isKeyReleased;

		switch(virtualKeyCode) {
		case VK_SHIFT:
		case VK_CONTROL:
		case VK_MENU:
			// TODO Handle virtual key code mappings (maybe later)
			virtualKeyCode = LOWORD(MapVirtualKeyW(scanCode, MAPVK_VSC_TO_VK_EX));
			break;
		}

		if(wasKeyDown != isKeyDown) {
			// TODO Proper keyboard event handling (forward/queue?)
			if(virtualKeyCode == 'W') {
			} else if(virtualKeyCode == 'A') {
			} else if(virtualKeyCode == 'S') {
			} else if(virtualKeyCode == 'D') {
			} else if(virtualKeyCode == 'G') {
				if(wasKeyDown && !isKeyDown) {
					APPLICATION_USES_GAMEPAD = !APPLICATION_USES_GAMEPAD;
				}
			} else if(virtualKeyCode == 'Q') {
			} else if(virtualKeyCode == 'E') {
			} else if(virtualKeyCode == VK_UP) {
			} else if(virtualKeyCode == VK_LEFT) {
			} else if(virtualKeyCode == VK_DOWN) {
			} else if(virtualKeyCode == VK_RIGHT) {
			} else if(virtualKeyCode == VK_ESCAPE) {
				if(wasKeyDown && !isKeyDown) {
					PostQuitMessage(0);
				}
			} else if(virtualKeyCode == VK_SPACE) {
				if(wasKeyDown && !isKeyDown) {
					WindowToggleFullscreen(window);
				}
			} else if(virtualKeyCode == VK_RETURN) {
				if(wasKeyDown && !isKeyDown) {
					APPLICATION_SHOULD_PAUSE = !APPLICATION_SHOULD_PAUSE;
				}
			}
		}
	} break;

	case WM_CLOSE: {
		TODO("Received WM_CLOSE\n");
		APPLICATION_SHOULD_EXIT = true;
	} break;

	case WM_ACTIVATEAPP: {
		TODO("Received WM_ACTIVATEAPP\n");
	} break;

	case WM_DESTROY: {
		PostQuitMessage(0);
		return 0;
	} break;

	default: {
		result = DefWindowProc(window, message, wParam, lParam);
	} break;
	}

	return result;
}

constexpr int EXIT_FAILURE = -1;
int WINAPI WinMain(HINSTANCE instance, HINSTANCE unused, LPSTR commandLine,
	int showFlag) {
	IntrinsicsReadCPUID();
	ReadKernelVersionInfo();

	UINT requestedSchedulerGranularityInMilliseconds = 1;
	bool didAdjustGranularity = (timeBeginPeriod(requestedSchedulerGranularityInMilliseconds) == TIMERR_NOERROR);
	DWORD sleepTimeInMilliseconds = MILLISECONDS_PER_SECOND / TARGET_FRAME_RATE;

	// TODO Override via CLI arguments or something? (Can also compute based on available RAM)
	constexpr size_t MAIN_MEMORY_SIZE = Megabytes(192);
	constexpr size_t TRANSIENT_MEMORY_SIZE = Megabytes(1800);
	SystemMemoryInitializeArenas(MAIN_MEMORY_SIZE, TRANSIENT_MEMORY_SIZE);

	WNDCLASSEX windowClass = {};
	// TODO Is this really a good idea? Beware the CS_OWNDC footguns...
	// TODO https://devblogs.microsoft.com/oldnewthing/20060601-06/?p=31003
	windowClass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;

	windowClass.cbSize = sizeof(windowClass);
	windowClass.lpfnWndProc = WindowProcessMessage;
	windowClass.hInstance = instance;
	windowClass.hbrBackground = (HBRUSH)COLOR_BACKGROUND;
	windowClass.lpszClassName = "RagLiteWindowClass";
	windowClass.hIcon = (HICON)LoadImage(instance, TEXT("DEFAULT_APP_ICON"), IMAGE_ICON,
		GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON),
		LR_DEFAULTCOLOR);
	windowClass.hIconSm = (HICON)LoadImage(instance, TEXT("DEFAULT_APP_ICON"), IMAGE_ICON,
		GetSystemMetrics(SM_CXSMICON),
		GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);

	if(!RegisterClassEx(&windowClass)) {
		TODO("Failed to register window class\n");
		return EXIT_FAILURE;
	}

	HWND mainWindow = CreateWindowExA(
		0, windowClass.lpszClassName, WINDOW_TITLE,
		WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_MAXIMIZE, CW_USEDEFAULT,
		CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, instance, 0);
	if(!mainWindow) {
		TODO("Failed to CreateWindowExA - Exiting...");
		return EXIT_FAILURE;
	}

	SurfaceGetWindowDimensions(GDI_SURFACE, mainWindow);
	ResizeBackBuffer(GDI_BACKBUFFER, max(1, GDI_SURFACE.width),
		max(1, GDI_SURFACE.height), mainWindow);

	MSG message;
	int offsetX = 0;
	int offsetY = 0;
	while(!APPLICATION_SHOULD_EXIT) {
		while(PeekMessage(&message, 0, 0, 0, PM_REMOVE)) {
			TranslateMessage(&message);
			DispatchMessageA(&message);
			if(message.message == WM_QUIT)
				APPLICATION_SHOULD_EXIT = true;
		}

		if(!APPLICATION_SHOULD_PAUSE) {
			PerformanceMetricsUpdateNow();
			GamePadPollControllers(offsetX, offsetY);
			DebugDrawUpdateBackgroundPattern();
			DebugDrawUpdateFrameBuffer(GDI_BACKBUFFER, offsetX, offsetY);
			InvalidateRect(mainWindow, NULL, FALSE);
		}

		++offsetX;
		offsetY += 2;

		if(!SystemMemoryCanAllocate(MAIN_MEMORY, Megabytes(32))) {
			// SystemMemoryReset(MAIN_MEMORY);
			if(SystemMemoryCanAllocate(TRANSIENT_MEMORY, Megabytes(32))) {
				uint8* memory = (uint8*)SystemMemoryAllocate(TRANSIENT_MEMORY, Megabytes(32));
				for(int i = 0; i < Megabytes(32); ++i) {
					*memory++ = 42;
				}
			} else SystemMemoryReset(TRANSIENT_MEMORY);
		} else {
			uint8* memory = (uint8*)SystemMemoryAllocate(MAIN_MEMORY, Megabytes(32));
			for(int i = 0; i < Megabytes(32); ++i) {
				*memory++ = 42;
			}
		}
		Sleep(sleepTimeInMilliseconds);
	}

	timeEndPeriod(requestedSchedulerGranularityInMilliseconds);

	return 0;
}
