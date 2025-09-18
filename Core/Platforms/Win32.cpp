#include "Win32.hpp"

#define TODO(msg) OutputDebugStringA(msg);

GLOBAL FPS TARGET_FRAME_RATE = 120;

// TODO: Replace these with the actual game/application state later
typedef struct volatile_game_state {
	int32 offsetX;
	int32 offsetY;
} game_state_t;
GLOBAL game_state_t PLACEHOLDER_DEMO_APP = {
	.offsetX = 0,
	.offsetY = 0,
};

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
#include "Win32/Memory.cpp"
#include "Win32/Time.cpp"
#include "Win32/Windowing.cpp"

#include "Win32/DebugDraw.cpp"

void BlitBackBufferToWindow(HWND& window) {
	HDC deviceContext = GetDC(window);
	ASSUME(deviceContext, "Failed to get GDI device drawing context");
	GDI_SURFACE.displayDeviceContext = deviceContext;

	ASSUME(GDI_SURFACE.displayDeviceContext, "Failed to get GDI display device drawing context");
	ASSUME(GDI_SURFACE.offscreenDeviceContext, "Failed to get GDI offscreen device drawing context");
	ASSUME(GDI_BACKBUFFER.activeHandle, "No active GDI back buffer is available for drawing");

	int srcW = GDI_BACKBUFFER.width;
	int srcH = GDI_BACKBUFFER.height;
	int destW = GDI_SURFACE.width;
	int destH = GDI_SURFACE.height;
	if(!StretchBlt(GDI_SURFACE.displayDeviceContext, 0, 0, destW, destH, GDI_SURFACE.offscreenDeviceContext,
		   0, 0, srcW, srcH, SRCCOPY)) {
		TODO("StretchBlt failed\n");
	}
}

void DrawDebugOverlay(gdi_surface_t doubleBufferedSurface) {
	DebugDrawMemoryUsageOverlay(doubleBufferedSurface);
	DebugDrawProcessorUsageOverlay(doubleBufferedSurface);
	DebugDrawKeyboardOverlay(doubleBufferedSurface);
}

void RedrawEverythingIntoWindow(HWND& window) {
	DebugDrawIntoFrameBuffer(GDI_BACKBUFFER, PLACEHOLDER_DEMO_APP.offsetX, PLACEHOLDER_DEMO_APP.offsetY);
	DrawDebugOverlay(GDI_SURFACE);
	BlitBackBufferToWindow(window);
}

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
		BeginPaint(window, &paintInfo);
		RedrawEverythingIntoWindow(window);
		EndPaint(window, &paintInfo);
		return 0;
	} break;

	case WM_SYSKEYDOWN:
	case WM_SYSKEYUP:
	case WM_KEYDOWN:
	case WM_KEYUP: {
		WORD virtualKeyCode = LOWORD(wParam);
		WORD keyFlags = HIWORD(lParam);
		WORD scanCode = LOBYTE(keyFlags);
		BOOL isExtendedKey = (keyFlags & KF_EXTENDED) == KF_EXTENDED;

		if(isExtendedKey)
			scanCode = MAKEWORD(scanCode, 0xE0);

		BOOL wasKeyDown = (keyFlags & KF_REPEAT) == KF_REPEAT;
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

	case WM_ERASEBKGND: {
		// NOTE: No need for the OS to clear since the entire window is always fully painted
		constexpr bool didEraseBackground = true;
		return didEraseBackground;
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
int WINAPI WinMain(HINSTANCE instance, HINSTANCE, LPSTR,
	int) {
	IntrinsicsReadCPUID();
	ReadKernelVersionInfo();

	UINT requestedSchedulerGranularityInMilliseconds = 1;
	bool didAdjustGranularity = (timeBeginPeriod(requestedSchedulerGranularityInMilliseconds) == TIMERR_NOERROR);
	ASSUME(didAdjustGranularity, "Failed to adjust the process scheduler's time period");
	milliseconds sleepTime = MILLISECONDS_PER_SECOND / TARGET_FRAME_RATE;

	SYSTEM_INFO sysInfo;
	GetSystemInfo(&sysInfo);
	CPU_PERFORMANCE_METRICS.hardwareSystemInfo = sysInfo;

	WNDCLASSEX windowClass = {};
	// TODO Is this really a good idea? Beware the CS_OWNDC footguns...
	// TODO https://devblogs.microsoft.com/oldnewthing/20060601-06/?p=31003
	windowClass.style = CS_OWNDC;

	windowClass.cbSize = sizeof(windowClass);
	windowClass.lpfnWndProc = WindowProcessMessage;
	windowClass.hInstance = instance;
	windowClass.hbrBackground = CreateSolidBrush(RGB_COLOR_RED);
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

	TCHAR executableFileSystemPath[MAX_PATH];
	GetModuleFileNameA(NULL, executableFileSystemPath, MAX_PATH);
	String windowTitle = CountedString(executableFileSystemPath);
	PathStringToBaseNameInPlace(windowTitle);
	PathStringStripFileExtensionInPlace(windowTitle);
	HWND mainWindow = CreateWindowExA(
		0, windowClass.lpszClassName, windowTitle.buffer,
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
	while(!APPLICATION_SHOULD_EXIT) {
		while(PeekMessage(&message, 0, 0, 0, PM_REMOVE)) {
			TranslateMessage(&message);
			DispatchMessageA(&message);
			if(message.message == WM_QUIT)
				APPLICATION_SHOULD_EXIT = true;
		}

		PerformanceMetricsUpdateNow();
		if(!APPLICATION_SHOULD_PAUSE) {

			// NOTE: Application/game state updates should go here (later)
			PLACEHOLDER_DEMO_APP.offsetX++;
			PLACEHOLDER_DEMO_APP.offsetY++;
			PLACEHOLDER_DEMO_APP.offsetY++;

			GamePadPollControllers(PLACEHOLDER_DEMO_APP.offsetX, PLACEHOLDER_DEMO_APP.offsetY);
			DebugDrawUpdateBackgroundPattern();
		}

		RedrawEverythingIntoWindow(mainWindow);

		Sleep(FloatToU32(sleepTime));
	}

	timeEndPeriod(requestedSchedulerGranularityInMilliseconds);

	return 0;
}
