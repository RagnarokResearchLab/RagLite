#include "Win32.hpp"

#define TODO(msg) OutputDebugStringA(msg);

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

INTERNAL const char* ArchitectureToDebugName(WORD wProcessorArchitecture) {

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

#include "Win32/DebugDraw.hpp"

#include "Win32/GamePad.cpp"
#include "Win32/Keyboard.cpp"
#include "Win32/Memory.cpp"
#include "Win32/Time.cpp"
#include "Win32/Windowing.cpp"

#include "Win32/DebugDraw.cpp"

INTERNAL void PlatformUpdateWorldState(world_state_t& worldState) {
	worldState.offsetX++;
	worldState.offsetY++;
	worldState.offsetY++;

	size_t allocationSize = Megabytes(2);
	if(!SystemMemoryCanAllocate(PLACEHOLDER_PROGRAM_MEMORY.persistentMemory, allocationSize)) {
		SystemMemoryReset(PLACEHOLDER_PROGRAM_MEMORY.persistentMemory);
	} else {
		uint8* mainMemory = (uint8*)SystemMemoryAllocate(PLACEHOLDER_PROGRAM_MEMORY.persistentMemory, allocationSize);
		*mainMemory = 0xDE;
		SystemMemoryDebugTouch(PLACEHOLDER_PROGRAM_MEMORY.persistentMemory, mainMemory);
	}

	if(!SystemMemoryCanAllocate(PLACEHOLDER_PROGRAM_MEMORY.transientMemory, 2 * allocationSize)) {
		SystemMemoryReset(PLACEHOLDER_PROGRAM_MEMORY.transientMemory);
	} else {

		uint8* transientMemory = (uint8*)SystemMemoryAllocate(PLACEHOLDER_PROGRAM_MEMORY.transientMemory, 2 * allocationSize);
		*transientMemory = 0xAB;
		SystemMemoryDebugTouch(PLACEHOLDER_PROGRAM_MEMORY.transientMemory, transientMemory);
	}

	GamePadPollControllers(worldState.offsetX, worldState.offsetY);
	DebugDrawUpdateBackgroundPattern();
}

INTERNAL void SurfacePresentFrameBuffer(gdi_surface_t& surface, gdi_offscreen_buffer_t& backBuffer) {
	if(!surface.displayDeviceContext || !surface.offscreenDeviceContext || !backBuffer.handle) {
		// Minimized or not yet initialized
		return;
	}

	int srcW = backBuffer.width;
	int srcH = backBuffer.height;
	int destW = surface.width;
	int destH = surface.height;
	if(!StretchBlt(surface.displayDeviceContext, 0, 0, destW, destH, surface.offscreenDeviceContext,
		   0, 0, srcW, srcH, SRCCOPY)) {
		TODO("StretchBlt failed\n");
	}
}

INTERNAL void SurfaceDrawDebugUI(gdi_surface_t& doubleBufferedWindowSurface) {
	HDC offscreenDeviceContext = doubleBufferedWindowSurface.offscreenDeviceContext;
	if(!offscreenDeviceContext) return;

	DebugDrawMemoryUsageOverlay(offscreenDeviceContext);
	DebugDrawProcessorUsageOverlay(offscreenDeviceContext);
	DebugDrawKeyboardOverlay(offscreenDeviceContext);
}

INTERNAL void MainWindowRedrawEverything(HWND& window) {
	if(IsIconic(window)) {
		// Minimized - no point in drawing this frame
		CPU_PERFORMANCE_METRICS.worldRenderTime = 0;
		CPU_PERFORMANCE_METRICS.userInterfaceRenderTime = 0;
		return;
	}

	hardware_tick_t before = PerformanceMetricsNow();
	DebugDrawIntoFrameBuffer(GDI_BACKBUFFER, PLACEHOLDER_WORLD_STATE.offsetX, PLACEHOLDER_WORLD_STATE.offsetY);
	CPU_PERFORMANCE_METRICS.worldRenderTime = PerformanceMetricsGetTimeSince(before);

	before = PerformanceMetricsNow();
	SurfaceDrawDebugUI(GDI_SURFACE);
	CPU_PERFORMANCE_METRICS.userInterfaceRenderTime = PerformanceMetricsGetTimeSince(before);

	SurfacePresentFrameBuffer(GDI_SURFACE, GDI_BACKBUFFER);
}

INTERNAL void SurfaceResizeBackBuffer(gdi_surface_t& surface, gdi_offscreen_buffer_t& bitmap) {

	DeleteObject(bitmap.handle);
	bitmap.handle = NULL;
	bitmap.pixelBuffer = NULL;

	bitmap.width = surface.width;
	bitmap.height = surface.height;
	bitmap.bytesPerPixel = 4;
	bitmap.stride = surface.width * bitmap.bytesPerPixel;

	ZeroMemory(&bitmap.info, sizeof(bitmap.info));
	bitmap.info.bmiHeader.biSize = sizeof(bitmap.info.bmiHeader);
	bitmap.info.bmiHeader.biWidth = surface.width;
	bitmap.info.bmiHeader.biHeight = -surface.height; // Inverted Y
	bitmap.info.bmiHeader.biPlanes = 1;
	bitmap.info.bmiHeader.biBitCount = 32;
	bitmap.info.bmiHeader.biCompression = BI_RGB;

	DeleteObject(surface.offscreenDeviceContext);
	surface.offscreenDeviceContext = CreateCompatibleDC(surface.displayDeviceContext);
	ASSUME(surface.offscreenDeviceContext, "Failed to create compatible memory DC");

	bitmap.handle = CreateDIBSection(surface.offscreenDeviceContext, &bitmap.info,
		DIB_RGB_COLORS, &bitmap.pixelBuffer, NULL, 0);
	ASSUME(bitmap.handle, "Failed to create DIB handle");
	ASSUME(bitmap.pixelBuffer, "Failed to create DIB buffer");

	SelectObject(surface.offscreenDeviceContext, bitmap.handle);

	uint32* pixelArray = (uint32*)bitmap.pixelBuffer;
	size_t count = (size_t)surface.width * (size_t)surface.height;
	for(size_t i = 0; i < count; ++i)
		pixelArray[i] = UNINITIALIZED_WINDOW_COLOR.bytes;
}

INTERNAL void MainWindowCreateFrameBuffers(HWND& window, gdi_surface_t& surface, gdi_offscreen_buffer_t& backBuffer) {
	RECT clientRect;
	GetClientRect(window, &clientRect);
	surface.width = Max(1, clientRect.right - clientRect.left);
	surface.height = Max(1, clientRect.bottom - clientRect.top);

	surface.displayDeviceContext = GetDC(window);
	ASSUME(surface.displayDeviceContext, "Failed to get GDI device drawing context");

	SurfaceResizeBackBuffer(surface, backBuffer);
}

LRESULT CALLBACK MainWindowProcessIncomingMessage(HWND window, UINT message, WPARAM wParam,
	LPARAM lParam) {
	LRESULT result = 0;

	switch(message) {
		case WM_CREATE: {
			TODO("Received WM_CREATE\n");
			// TODO Initialize child windows here?
		} break;

		case WM_DISPLAYCHANGE:
		case WM_MOVE:
		case WM_MOVING:
		case WM_SIZING:
		case WM_SIZE: {
			MainWindowCreateFrameBuffers(window, GDI_SURFACE, GDI_BACKBUFFER);
			// NOTE: Updating again allows the simulation to appear more fluid (evaluate UX later)
			DebugDrawUpdateBackgroundPattern();
			MainWindowRedrawEverything(window);
		} break;

		case WM_PAINT: {
			PAINTSTRUCT paintInfo;
			BeginPaint(window, &paintInfo);
			MainWindowRedrawEverything(window);
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

int WINAPI WinMain(HINSTANCE instance, HINSTANCE, LPSTR,
	int) {
	hardware_tick_t applicationStartTime = PerformanceMetricsNow();

	IntrinsicsReadCPUID();
	ReadKernelVersionInfo();

	UINT requestedSchedulerGranularityInMilliseconds = 1;
	bool didAdjustGranularity = (timeBeginPeriod(requestedSchedulerGranularityInMilliseconds) == TIMERR_NOERROR);
	ASSUME(didAdjustGranularity, "Failed to adjust the process scheduler's time period (HW issue or legacy OS?)");

	SYSTEM_INFO sysInfo;
	GetSystemInfo(&sysInfo);
	CPU_PERFORMANCE_INFO.numberOfProcessors = sysInfo.dwNumberOfProcessors;
	CPU_PERFORMANCE_INFO.processorArchitecture = sysInfo.wProcessorArchitecture;
	CPU_PERFORMANCE_INFO.pageSize = sysInfo.dwPageSize;
	CPU_PERFORMANCE_INFO.allocationGranularity = sysInfo.dwAllocationGranularity;

	LARGE_INTEGER ticksPerSecond;
	QueryPerformanceFrequency(&ticksPerSecond);
	MONOTONIC_CLOCK_SPEED = ticksPerSecond.QuadPart;
	hardware_tick_t lastUpdateTime = PerformanceMetricsNow();

	PLACEHOLDER_MEMORY_CONFIGURATION.persistentMemoryOptions = PlatformDefaultAllocationOptions();
	PLACEHOLDER_MEMORY_CONFIGURATION.transientMemoryOptions = PlatformDefaultAllocationOptions();
#ifdef RAGLITE_PREDICTABLE_MEMORY
	PLACEHOLDER_MEMORY_CONFIGURATION.persistentMemoryOptions.startingAddress = (LPVOID)HIGHEST_VIRTUAL_ADDRESS;
#endif
	PLACEHOLDER_MEMORY_CONFIGURATION.persistentMemoryOptions.reservedSize = RAGLITE_PERSISTENT_MEMORY;
	PLACEHOLDER_MEMORY_CONFIGURATION.transientMemoryOptions.reservedSize = RAGLITE_TRANSIENT_MEMORY;
	PlatformInitializeProgramMemory(PLACEHOLDER_PROGRAM_MEMORY, PLACEHOLDER_MEMORY_CONFIGURATION);

	WNDCLASSEX windowClass = {};
	// TODO Is this really a good idea? Beware the CS_OWNDC footguns...
	// TODO https://devblogs.microsoft.com/oldnewthing/20060601-06/?p=31003
	windowClass.style = CS_OWNDC;

	windowClass.cbSize = sizeof(windowClass);
	windowClass.lpfnWndProc = MainWindowProcessIncomingMessage;
	windowClass.hInstance = instance;
	windowClass.hbrBackground = CreateSolidBrush(ColorRef(RGB_COLOR_BRIGHTEST));
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

	// TODO: On modern Windows systems, MAX_PATH is insufficient and Unicode paths should ideally be supported (later?)
	TCHAR executableFileSystemPath[MAX_PATH];
	DWORD copiedStringLength = GetModuleFileNameA(NULL, executableFileSystemPath, MAX_PATH);
	ASSUME(copiedStringLength != 0, "Failed to get module file name (check last error code if this ever happens)");
	ASSUME(copiedStringLength != MAX_PATH, "Module file name may have been truncated (ERROR_INSUFFICIENT_BUFFER?)");
	String windowTitle = CountedString(executableFileSystemPath);
	PathStringToBaseNameInPlace(windowTitle);
	PathStringStripFileExtensionInPlace(windowTitle);
	StringAppend(windowTitle, " [");
	StringAppend(windowTitle, RAGLITE_COMMIT_HASH);
	StringAppend(windowTitle, "]");
	HWND mainWindow = CreateWindowExA(
		0, windowClass.lpszClassName, windowTitle.buffer,
		WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_MAXIMIZE, CW_USEDEFAULT,
		CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, instance, 0);
	if(!mainWindow) {
		TODO("Failed to CreateWindowExA - Exiting...");
		return EXIT_FAILURE;
	}
	MainWindowCreateFrameBuffers(mainWindow, GDI_SURFACE, GDI_BACKBUFFER);

	CPU_PERFORMANCE_INFO.applicationLaunchTime = PerformanceMetricsGetTimeSince(applicationStartTime);

	MSG message;
	while(!APPLICATION_SHOULD_EXIT) {
		lastUpdateTime = PerformanceMetricsNow();
		CPU_PERFORMANCE_METRICS.applicationUptime = PerformanceMetricsGetTimeSince(applicationStartTime);

		while(PeekMessage(&message, 0, 0, 0, PM_REMOVE)) {

			TranslateMessage(&message);
			DispatchMessageA(&message);
			if(message.message == WM_QUIT)
				APPLICATION_SHOULD_EXIT = true;
		}
		CPU_PERFORMANCE_METRICS.messageProcessingTime = PerformanceMetricsGetTimeSince(lastUpdateTime);

		hardware_tick_t before = PerformanceMetricsNow();
		if(!APPLICATION_SHOULD_PAUSE) {
			PlatformUpdateWorldState(PLACEHOLDER_WORLD_STATE);
		}
		CPU_PERFORMANCE_METRICS.worldUpdateTime = PerformanceMetricsGetTimeSince(before);

		MainWindowRedrawEverything(mainWindow);

		milliseconds maxResponsiveSleepTime = MAX_FRAME_TIME;
		milliseconds sleepTime = maxResponsiveSleepTime - CPU_PERFORMANCE_METRICS.frameTime;
		hardware_tick_t beforeSleep = PerformanceMetricsNow();
		if(sleepTime > 0) Sleep((DWORD)sleepTime);
		CPU_PERFORMANCE_METRICS.sleepTime = sleepTime;
		CPU_PERFORMANCE_METRICS.suspendedTime = PerformanceMetricsGetTimeSince(beforeSleep);

		milliseconds frameTime = PerformanceMetricsGetTimeSince(lastUpdateTime);
		CPU_PERFORMANCE_METRICS.frameTime = frameTime;

		PerformanceMetricsRecordSample(CPU_PERFORMANCE_METRICS, PERFORMANCE_METRICS_HISTORY);
	}

	timeEndPeriod(requestedSchedulerGranularityInMilliseconds);

	return 0;
}
