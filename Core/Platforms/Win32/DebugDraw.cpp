
// TODO Eliminate this
#include <math.h>

#include <intrin.h>

typedef struct gdi_bitmap {
	HBITMAP activeHandle;
	HBITMAP inactiveHandle;
	BITMAPINFO info;
	int width;
	int height;
	int bytesPerPixel;
	int stride;
	void* pixelBuffer;
} gdi_bitmap_t;

typedef struct gdi_surface {
	HDC displayDeviceContext;
	HDC offscreenDeviceContext;
	int width;
	int height;
} gdi_surface_t;

enum gdi_debug_pattern {
	PATTERN_SHIFTING_GRADIENT,
	PATTERN_CIRCULAR_RIPPLE,
	PATTERN_CHECKERBOARD,
	PATTERN_AXIS_GRADIENTS,
	PATTERN_GRID_SCANLINE,
	PATTERN_COUNT
};

GLOBAL gdi_bitmap_t GDI_BACKBUFFER = {};
GLOBAL gdi_surface_t GDI_SURFACE = {};
GLOBAL gdi_debug_pattern GDI_DEBUG_PATTERN = PATTERN_SHIFTING_GRADIENT;

constexpr uint32 UNINITIALIZED_WINDOW_COLOR = 0xFF202020;

constexpr int DEBUG_OVERLAY_LINE_HEIGHT = 18;
constexpr int DEBUG_OVERLAY_MARGIN_SIZE = 8;
constexpr int DEBUG_OVERLAY_PADDING_SIZE = 8;

constexpr COLORREF RGB_COLOR_CYAN = RGB(120, 192, 255);
constexpr COLORREF RGB_COLOR_DARKEST = RGB(0, 0, 00);
constexpr COLORREF RGB_COLOR_DARKER = RGB(30, 30, 30);
constexpr COLORREF RGB_COLOR_DARK = RGB(50, 50, 50);
constexpr COLORREF RGB_COLOR_GRAY = RGB(80, 80, 80);
constexpr COLORREF RGB_COLOR_GREEN = RGB(0, 200, 0);
constexpr COLORREF RGB_COLOR_ORANGE = RGB(255, 128, 0);
constexpr COLORREF RGB_COLOR_RED = RGB(200, 0, 0);
constexpr COLORREF RGB_COLOR_YELLOW = RGB(200, 200, 0);
constexpr COLORREF RGB_COLOR_WHITE = RGB(200, 200, 200);
constexpr COLORREF RGB_COLOR_BRIGHTEST = RGB(255, 255, 255);
constexpr COLORREF RGB_COLOR_VIOLET = RGB(210, 168, 255);

constexpr COLORREF UI_PANEL_COLOR = RGB_COLOR_DARKER;
constexpr COLORREF UI_BACKGROUND_COLOR = RGB_COLOR_DARK;
constexpr COLORREF UI_TEXT_COLOR = RGB_COLOR_WHITE;
constexpr COLORREF UI_HIGHLIGHT_COLOR = RGB_COLOR_RED;

constexpr COLORREF USED_MEMORY_BLOCK_COLOR = RGB_COLOR_GREEN;
constexpr COLORREF COMMITTED_MEMORY_BLOCK_COLOR = RGB_COLOR_GRAY;
constexpr COLORREF RESERVED_MEMORY_BLOCK_COLOR = RGB_COLOR_DARK;

typedef struct gdi_progress_bar {
	int x;
	int y;
	int width;
	int height;
	int percent;
} progress_bar_t;

COLORREF ProgressBarGetColor(int percent) {
	if(percent < 50) return RGB_COLOR_GREEN;
	if(percent < 75) return RGB_COLOR_YELLOW;
	if(percent < 90) return RGB_COLOR_ORANGE;
	return RGB_COLOR_RED;
}

INTERNAL void DrawProgressBar(HDC displayDeviceContext, progress_bar_t& bar) {
	HBRUSH backgroundBrush = CreateSolidBrush(UI_BACKGROUND_COLOR);
	RECT rect = { bar.x, bar.y, bar.x + bar.width, bar.y + bar.height };
	FillRect(displayDeviceContext, &rect, backgroundBrush);
	DeleteObject(backgroundBrush);

	int filledWidth = (bar.width * bar.percent) / 100;
	HBRUSH foregroundBrush = CreateSolidBrush(ProgressBarGetColor(bar.percent));
	RECT fillRect = { bar.x, bar.y, bar.x + filledWidth, bar.y + bar.height };
	FillRect(displayDeviceContext, &fillRect, foregroundBrush);
	DeleteObject(foregroundBrush);

	FrameRect(displayDeviceContext, &rect, (HBRUSH)GetStockObject(WHITE_BRUSH));
}

GLOBAL int MEMORY_OVERLAY_WIDTH = 1024 + 128 + 16;

INTERNAL void DebugDrawMemoryUsageOverlay(gdi_surface_t& surface) {
	// TODO param arena, startX, startY
	HDC offscreenDeviceContext = surface.offscreenDeviceContext;
	if(!offscreenDeviceContext)
		return;

	SetBkMode(offscreenDeviceContext, TRANSPARENT);
	HFONT font = (HFONT)GetStockObject(ANSI_VAR_FONT);
	HFONT oldFont = (HFONT)SelectObject(offscreenDeviceContext, font);

	int x = 0;
	int y = 0;

	constexpr int NUM_SECTIONS = 5;
	constexpr int Y_PER_SECTION = 8; // Questionable

	int startX = 0;
	int startY = 300;
	RECT backgroundPanelRect = {
		startX,
		startY,
		startX + MEMORY_OVERLAY_WIDTH,
		startY + (DEBUG_OVERLAY_LINE_HEIGHT * NUM_SECTIONS * Y_PER_SECTION) + DEBUG_OVERLAY_LINE_HEIGHT
	};
	HBRUSH panelBrush = CreateSolidBrush(UI_PANEL_COLOR);
	FillRect(offscreenDeviceContext, &backgroundPanelRect, panelBrush);
	DeleteObject(panelBrush);

	SetTextColor(offscreenDeviceContext, UI_TEXT_COLOR);

	char buffer[256];
	int lineY = startY + DEBUG_OVERLAY_PADDING_SIZE;

	//-------------------------------------------------
	// Arena stats
	//-------------------------------------------------
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== MEMORY ARENAS ===", lstrlenA("=== MEMORY ARENAS ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Name: %s", MAIN_MEMORY.name);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Lifetime: %s", MAIN_MEMORY.lifetime);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Base: 0x%p", MAIN_MEMORY.base);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Reserved: %d KB", MAIN_MEMORY.reservedSize / 1024);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Committed: %d KB", MAIN_MEMORY.committedSize / 1024);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Used: %d KB", MAIN_MEMORY.used / 1024);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Free: %d KB", (MAIN_MEMORY.committedSize - MAIN_MEMORY.used) / 1024);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Allocations: %d", MAIN_MEMORY.allocationCount);
	TextOutA(offscreenDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	// lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	const int blockSize = 64 * 1024; // 64KB
	int totalBlocks = MAIN_MEMORY.reservedSize / blockSize;
	int usedBlocks = MAIN_MEMORY.used / blockSize;
	int committedBlocks = MAIN_MEMORY.committedSize / blockSize;

	int blockWidth = 2; // 6;
	int blockHeight = 4; // 12;
	int blocksPerRow = 256 + 128; // wrap to multiple rows if arena is large
	int arenaX = startX + DEBUG_OVERLAY_PADDING_SIZE;
	int arenaY = lineY;

	for(int i = 0; i < totalBlocks; ++i) {
		COLORREF color;
		if(i < usedBlocks) {
			color = USED_MEMORY_BLOCK_COLOR;
		} else if(i < committedBlocks) {
			color = COMMITTED_MEMORY_BLOCK_COLOR;
		} else {
			color = RESERVED_MEMORY_BLOCK_COLOR;
		}

		HBRUSH brush = CreateSolidBrush(color);
		RECT block = {
			arenaX + (i % blocksPerRow) * (blockWidth + 1),
			arenaY + (i / blocksPerRow) * (blockHeight + 1),
			arenaX + (i % blocksPerRow) * (blockWidth + 1) + blockWidth,
			arenaY + (i / blocksPerRow) * (blockHeight + 1) + blockHeight
		};
		FillRect(offscreenDeviceContext, &block, brush);
		DeleteObject(brush);
	}

	lineY = arenaY + ((totalBlocks / blocksPerRow) + 1) * (blockHeight + 1); // + DEBUG_OVERLAY_LINE_HEIGHT;

	SelectObject(offscreenDeviceContext, oldFont);
}

INTERNAL void DebugDrawProcessorUsageOverlay(gdi_surface_t& surface) {
	HDC displayDeviceContext = surface.offscreenDeviceContext;
	if(!displayDeviceContext) return;

	SetBkMode(displayDeviceContext, TRANSPARENT);
	HFONT font = (HFONT)GetStockObject(ANSI_VAR_FONT);
	HFONT oldFont = (HFONT)SelectObject(displayDeviceContext, font);

	int LINE_COUNT = 28 + 13; // CPU/performance + system memory + process memory + hardware info
	int PANEL_WIDTH = 360;

	int startX = MEMORY_OVERLAY_WIDTH + DEBUG_OVERLAY_MARGIN_SIZE;
	int startY = 300;
	RECT panelRect = {
		startX,
		startY,
		startX + PANEL_WIDTH,
		startY + (DEBUG_OVERLAY_LINE_HEIGHT * LINE_COUNT)
	};
	HBRUSH panelBrush = CreateSolidBrush(UI_PANEL_COLOR);
	FillRect(displayDeviceContext, &panelRect, panelBrush);
	DeleteObject(panelBrush);

	SetTextColor(displayDeviceContext, UI_TEXT_COLOR);

	char buffer[128];
	int lineY = startY + DEBUG_OVERLAY_PADDING_SIZE;

	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== PERFORMANCE ===", lstrlenA("=== PERFORMANCE ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// CPU
	int cpuUsage = Percent(CPU_PERFORMANCE_METRICS.processorUsageSingleCore);
	wsprintfA(buffer, "Main Thread (Single Core): %d%%", cpuUsage);
	TextOutA(displayDeviceContext, startX + 8, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	progress_bar_t progressBar = { .x = startX + 8, .y = lineY, .width = 200, .height = 16, .percent = cpuUsage };
	DrawProgressBar(displayDeviceContext, progressBar);
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	cpuUsage = Percent(CPU_PERFORMANCE_METRICS.processorUsageAllCores);
	wsprintfA(buffer, "Process (All Cores): %d%%", cpuUsage);
	TextOutA(displayDeviceContext, startX + 8, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	progressBar.y = lineY;
	progressBar.percent = cpuUsage;
	DrawProgressBar(displayDeviceContext, progressBar);
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// Frame timing
	char num[32];
	FloatToString(num, CPU_PERFORMANCE_METRICS.deltaTimeMs, 2);
	lstrcpyA(buffer, "Frame: "); // Clear buffer first
	lstrcatA(buffer, num); // Append
	lstrcatA(buffer, " ms");

	lstrcatA(buffer, " (smoothed: ");
	FloatToString(num, CPU_PERFORMANCE_METRICS.deltaTimeMs, 2);
	lstrcatA(buffer, num);
	lstrcatA(buffer, " ms)");
	TextOutA(displayDeviceContext, startX + 8, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lstrcpyA(buffer, "FPS: ");
	FloatToString(num, CPU_PERFORMANCE_METRICS.fps, 1);
	lstrcatA(buffer, num);
	lstrcatA(buffer, " (smoothed: ");
	FloatToString(num, CPU_PERFORMANCE_METRICS.smoothedFps, 1);
	lstrcatA(buffer, num);
	lstrcatA(buffer, ")");
	TextOutA(displayDeviceContext, startX + 8, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// Sleep accuracy
	lstrcpyA(buffer, "Sleep requested: ");
	FloatToString(num, CPU_PERFORMANCE_METRICS.requestedSleepMs, 2);
	lstrcatA(buffer, num);
	lstrcatA(buffer, " (actual: ");
	FloatToString(num, CPU_PERFORMANCE_METRICS.actualSleepMs, 2);
	lstrcatA(buffer, num);
	lstrcatA(buffer, ")");
	TextOutA(displayDeviceContext, startX + 8, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Sleep requested: %.2f ms", CPU_PERFORMANCE_METRICS.requestedSleepMs);

	//-------------------------------------------------
	// System stats
	//-------------------------------------------------
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== SYSTEM MEMORY ===", lstrlenA("=== SYSTEM MEMORY ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	MEMORYSTATUSEX memoryUsageInfo = {};
	memoryUsageInfo.dwLength = sizeof(memoryUsageInfo);
	PROCESS_MEMORY_COUNTERS_EX pmc;

	if(!GlobalMemoryStatusEx(&memoryUsageInfo)) {
		DWORD err = GetLastError();
		LPTSTR errStr = FormatErrorString(err);

		wsprintfA(buffer, "N/A: %lu (%s)", err, errStr);
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	} else {
		wsprintfA(buffer, "Total Physical Memory: %d MB", (int)(memoryUsageInfo.ullTotalPhys / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		wsprintfA(buffer, "Available Physical Memory: %d MB", memoryUsageInfo.ullAvailPhys / (1024 * 1024));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		// wsprintfA(buffer, "Avail Virtual: %d MB", (int)(memoryUsageInfo.ullAvailVirtual / (1024 * 1024)));
		// TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		// lineY += DEBUG_OVERLAY_LINE_HEIGHT * 1;

		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
		wsprintfA(buffer, "Physical Memory Load: %d%%", memoryUsageInfo.dwMemoryLoad);
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		int sysUsage = memoryUsageInfo.dwMemoryLoad;
		progress_bar_t progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = 200, .height = 16, .percent = sysUsage };
		DrawProgressBar(displayDeviceContext,
			progressBar);
		lineY += 24;

		// TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		// 	"System Usage:", lstrlenA("System Usage:"));
		// lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		// lineY += DEBUG_OVERLAY_LINE_HEIGHT * 1;

		//-------------------------------------------------
		// Process usage bar
		//-------------------------------------------------
		// TODO Eliminate the redundant fetch
		if(GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
			int procPercent = (int)((pmc.WorkingSetSize * 100) / memoryUsageInfo.ullTotalPhys);

			wsprintfA(buffer, "Process: %d MB / %d MB",
				(int)(pmc.WorkingSetSize / (1024 * 1024)),
				(int)(memoryUsageInfo.ullTotalPhys / (1024 * 1024)));

			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE,
				lineY, buffer, lstrlenA(buffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

			progress_bar_t progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = 200, .height = 16, .percent = procPercent };

			DrawProgressBar(displayDeviceContext, progressBar);
			lineY += 24;
		} else {
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE,
				lineY, "Process stats unavailable", lstrlenA("Process stats unavailable"));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT * 2;
		}
	}

	//-------------------------------------------------
	// Process stats
	//-------------------------------------------------
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== PROCESS MEMORY	 ===", lstrlenA("=== PROCESS MEMORY ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	if(GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
		wsprintfA(buffer, "Virtual Memory Commit Limit: %d MB", (int)(memoryUsageInfo.ullTotalPageFile / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		wsprintfA(buffer, "Virtual Memory Commit Capacity : %d MB", (int)(memoryUsageInfo.ullAvailPageFile / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
		// TODO use real32 instead of double, unless necessary (2x speedup due to better FPU utilization in HW)
		progress_bar_t progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = 200, .height = 16, .percent = Percent((double)memoryUsageInfo.ullAvailPageFile / memoryUsageInfo.ullTotalPageFile) };
		wsprintfA(buffer, "Virtual Memory Load: %d%%", progressBar.percent);
		progressBar.y += DEBUG_OVERLAY_LINE_HEIGHT;
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
		DrawProgressBar(displayDeviceContext, progressBar);
			lineY += 24;

		wsprintfA(buffer, "Working Set: %d MB", (int)(pmc.WorkingSetSize / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		wsprintfA(buffer, "Private Bytes: %d MB", (int)(pmc.PrivateUsage / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		wsprintfA(buffer, "Commit Size: %d MB", (int)(pmc.PagefileUsage / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		wsprintfA(buffer, "Peak Working Set: %d MB", (int)(pmc.PeakWorkingSetSize / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		wsprintfA(buffer, "Peak Pagefile: %d MB", (int)(pmc.PeakPagefileUsage / (1024 * 1024)));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	} else {
				DWORD err = GetLastError();
		LPTSTR errStr = FormatErrorString(err);

		wsprintfA(buffer, "N/A: %lu (%s)", err, errStr);
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	}

	//-------------------------------------------------
	// Native system info
	// (TODO doesn't change, no need to fetch it more than once?)
	//-------------------------------------------------

	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== HARDWARE INFORMATION ===", lstrlenA("=== HARDWARE INFORMATION ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO Disable outside debug mode? Let's not risk messing with the OS too much in releases
	// TODO avoid doing this every frame
	typedef LONG(WINAPI * RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

	RTL_OSVERSIONINFOW vi = { 0 };
	vi.dwOSVersionInfoSize = sizeof(vi);

	HMODULE hNtdll = GetModuleHandleW(L"ntdll.dll");
	if(hNtdll) {

		RtlGetVersionPtr pRtlGetVersion = (RtlGetVersionPtr)GetProcAddress(hNtdll, "RtlGetVersion");
		if(pRtlGetVersion && pRtlGetVersion((PRTL_OSVERSIONINFOW)&vi) == 0) {
			wsprintfA(buffer,
				"Operating System: Windows %u.%u (Build %u) %S",
				vi.dwMajorVersion,
				vi.dwMinorVersion,
				vi.dwBuildNumber,
				vi.szCSDVersion);
			TextOutA(displayDeviceContext,
				startX + DEBUG_OVERLAY_PADDING_SIZE,
				lineY,
				buffer,
				lstrlenA(buffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;
		}
	} else {
		wsprintfA(buffer,
			"Operating System: N/A (Failed to GetModuleHandle for NTDLL.DLL) %S",
			vi.dwMajorVersion,
			vi.dwMinorVersion,
			vi.dwBuildNumber,
			vi.szCSDVersion);
		TextOutA(displayDeviceContext,
			startX + DEBUG_OVERLAY_PADDING_SIZE,
			lineY,
			buffer,
			lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	}
	// lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO Does that work on GCC? Move to platform defines.
	// TODO intrinsics -> not here
	int cpuInfo[4] = { 0 };
	char cpuBrand[0x40] = { 0 };

	__cpuid(cpuInfo, 0x80000000);
	unsigned int nExIds = cpuInfo[0];

	if(nExIds >= 0x80000004) {
		__cpuid((int*)cpuInfo, 0x80000002);
		memcpy(cpuBrand, cpuInfo, sizeof(cpuInfo));

		__cpuid((int*)cpuInfo, 0x80000003);
		memcpy(cpuBrand + 16, cpuInfo, sizeof(cpuInfo));

		__cpuid((int*)cpuInfo, 0x80000004);
		memcpy(cpuBrand + 32, cpuInfo, sizeof(cpuInfo));

		wsprintfA(buffer, "CPU: %s", cpuBrand);
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
			buffer, lstrlenA(buffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	}

	const char* arch = "Unknown";
	switch(CPU_PERFORMANCE_METRICS.hardwareSystemInfo.wProcessorArchitecture) {
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

	wsprintfA(buffer, "Processor Architecture: %s", arch);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	// TODO useless
	// wsprintfA(buffer, "OEM ID: %u", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.dwOemId);
	// TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	// lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Page Size: %u KB", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.dwPageSize);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO useless
	// wsprintfA(buffer, "Minimum Application Address: 0x%lX", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.lpMinimumApplicationAddress);
	// TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	// lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO useless
		// wsprintfA(buffer, "Maximum Application Address: 0x%lX", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.lpMaximumApplicationAddress);
		// TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
		// lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO useless
	wsprintfA(buffer, "Active Processor Mask: %u", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.dwActiveProcessorMask);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Number of Processors: %u", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.dwNumberOfProcessors);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO useless
	wsprintfA(buffer, "Processor Type: %u", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.dwProcessorType);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO unit?
	// TODO macro KILOBYTES(amount)
	wsprintfA(buffer, "Allocation Granularity: %u KB", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.dwAllocationGranularity / 1024);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	wsprintfA(buffer, "Processor Level: %u", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.wProcessorLevel);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO useless
	wsprintfA(buffer, "Processor Revision: %u", CPU_PERFORMANCE_METRICS.hardwareSystemInfo.wProcessorRevision);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, buffer, lstrlenA(buffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	// TODO show meaningful info for these
	// GetNativeSystemInfo -> Architecture

	// CPUID -> Brand string

	SelectObject(displayDeviceContext, oldFont);
}

constexpr int KEYBOARD_DEBUG_OVERLAY_CELL_WIDTH = 100;
constexpr int KEYBOARD_DEBUG_OVERLAY_CELL_HEIGHT = 18;

INTERNAL void DebugDrawKeyboardOverlay(gdi_surface_t& surface) {
	HDC displayDeviceContext = surface.offscreenDeviceContext;
	if(!displayDeviceContext)
		return;

	SetBkMode(displayDeviceContext, TRANSPARENT);
	HFONT font = (HFONT)GetStockObject(ANSI_VAR_FONT);
	HFONT oldFont = (HFONT)SelectObject(displayDeviceContext, font);

	for(int virtualKeyCode = 0; virtualKeyCode < 256; ++virtualKeyCode) {
		int column = virtualKeyCode % 16;
		int row = virtualKeyCode / 16;
		int x = column * KEYBOARD_DEBUG_OVERLAY_CELL_WIDTH;
		int y = row * KEYBOARD_DEBUG_OVERLAY_CELL_HEIGHT;
		RECT textArea = { x, y, x + KEYBOARD_DEBUG_OVERLAY_CELL_WIDTH,
			y + KEYBOARD_DEBUG_OVERLAY_CELL_HEIGHT };

		SHORT keyFlags = GetKeyState(virtualKeyCode);
		BOOL wasKeyDown = (keyFlags & KF_REPEAT) == KF_REPEAT;
		WORD repeatCount = LOWORD(keyFlags);
		BOOL isKeyReleased = (keyFlags & KF_UP) == KF_UP;

		COLORREF backgroundColor = UI_PANEL_COLOR;
		if(wasKeyDown)
			backgroundColor = UI_HIGHLIGHT_COLOR;

		HBRUSH brush = CreateSolidBrush(backgroundColor);
		FillRect(displayDeviceContext, &textArea, brush);
		DeleteObject(brush);

		SetTextColor(displayDeviceContext, UI_TEXT_COLOR);
		const char* label = KeyCodeToDebugName(virtualKeyCode);
		DrawTextA(displayDeviceContext, label, -1, &textArea,
			DT_CENTER | DT_VCENTER | DT_SINGLELINE);
	}

	SelectObject(displayDeviceContext, oldFont);
}

INTERNAL void DebugDrawUpdateBackgroundPattern() {
	DWORD MS_PER_SECOND = 1000;

	DWORD ticks = GetTickCount();
	DWORD seconds = ticks / MS_PER_SECOND;
	DWORD updateInterval = 5;

	GDI_DEBUG_PATTERN = (gdi_debug_pattern)((seconds / updateInterval) % PATTERN_COUNT);
}

INTERNAL void DebugDrawUseMarchingGradientPattern(gdi_bitmap_t& bitmap,
	int offsetBlue,
	int offsetGreen) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;
	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			uint8 blue = (x + offsetBlue) & 0xFF;
			uint8 green = (y + offsetGreen) & 0xFF;

			*pixel++ = ((green << 8) | blue);
		}

		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseRipplingSpiralPattern(gdi_bitmap_t& bitmap, int time,
	int unused) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {

			int centerX = bitmap.width / 2;
			int centerY = bitmap.height / 2;
			float dx = (float)(x - centerX);
			float dy = (float)(y - centerY);
			float dist = sqrtf(dx * dx + dy * dy);
			float wave = 0.5f + 0.5f * sinf(dist / 5.0f - time * 0.1f);

			uint8 blue = (uint8)(wave * 255);
			uint8 green = (uint8)((1.0f - wave) * 255);
			uint8 red = (uint8)((0.5f + 0.5f * sinf(time * 0.05f)) * 255);

			*pixel++ = (red << 16) | (green << 8) | blue;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseCheckeredFloorPattern(gdi_bitmap_t& bitmap, int time,
	int unused) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	float angle = time * 0.02f;
	float cosA = cosf(angle);
	float sinA = sinf(angle);

	int cx = bitmap.width / 2;
	int cy = bitmap.height / 2;

	int squareSize = 32;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			int rx = x - cx;
			int ry = y - cy;

			float rX = rx * cosA - ry * sinA;
			float rY = rx * sinA + ry * cosA;

			int checkerX = ((int)floorf(rX / squareSize)) & 1;
			int checkerY = ((int)floorf(rY / squareSize)) & 1;

			uint8 c = (checkerX ^ checkerY) ? 200 : 80;
			*pixel++ = (c << 16) | (c << 8) | c;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseColorGradientPattern(gdi_bitmap_t& bitmap, int time,
	int unused) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	int cx = bitmap.width / 2;
	int cy = bitmap.height / 2;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			uint8 red = (uint8)((x * 255) / bitmap.width);
			uint8 green = (uint8)((y * 255) / bitmap.height);
			uint8 blue = 0;

			if(x == cx || y == cy) {
				red = green = blue = 255;
			}

			*pixel++ = (red << 16) | (green << 8) | blue;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseMovingScanlinePattern(gdi_bitmap_t& bitmap, int time,
	int unused) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	int gridSpacing = 32;
	int scanY = (time / 2) % bitmap.height;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			uint8 c = 180;

			if(x % gridSpacing == 0 || y % gridSpacing == 0)
				c = 100;

			if(y == scanY)
				c = 255;

			*pixel++ = (c << 16) | (c << 8) | c;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUpdateFrameBuffer(gdi_bitmap_t& bitmap, int paramA,
	int paramB) {
	switch(GDI_DEBUG_PATTERN) {
	case PATTERN_SHIFTING_GRADIENT:
		DebugDrawUseMarchingGradientPattern(bitmap, paramA, paramB);
		break;
	case PATTERN_CIRCULAR_RIPPLE:
		DebugDrawUseRipplingSpiralPattern(bitmap, paramA, paramB);
		break;
	case PATTERN_CHECKERBOARD:
		DebugDrawUseCheckeredFloorPattern(bitmap, paramA, paramB);
		break;
	case PATTERN_AXIS_GRADIENTS:
		DebugDrawUseColorGradientPattern(bitmap, paramA, paramB);
		break;
	case PATTERN_GRID_SCANLINE:
		DebugDrawUseMovingScanlinePattern(bitmap, paramA, paramB);
		break;
	}
}

INTERNAL void ResizeBackBuffer(gdi_bitmap_t& bitmap, int width, int height,
	HWND window) {
	if(GDI_SURFACE.offscreenDeviceContext) {
		if(bitmap.inactiveHandle) {
			SelectObject(GDI_SURFACE.offscreenDeviceContext, bitmap.inactiveHandle);
			bitmap.inactiveHandle = NULL;
		}
		DeleteDC(GDI_SURFACE.offscreenDeviceContext);
		GDI_SURFACE.offscreenDeviceContext = NULL;
	}

	if(bitmap.activeHandle) {
		DeleteObject(bitmap.activeHandle);
		bitmap.activeHandle = NULL;
	}

	if(bitmap.pixelBuffer) {
		bitmap.pixelBuffer = NULL;
	}

	bitmap.width = width;
	bitmap.height = height;
	bitmap.bytesPerPixel = 4;
	bitmap.stride = width * bitmap.bytesPerPixel;

	ZeroMemory(&bitmap.info, sizeof(bitmap.info));
	bitmap.info.bmiHeader.biSize = sizeof(bitmap.info.bmiHeader);
	bitmap.info.bmiHeader.biWidth = width;
	bitmap.info.bmiHeader.biHeight = -height; // Inverted Y
	bitmap.info.bmiHeader.biPlanes = 1;
	bitmap.info.bmiHeader.biBitCount = 32;
	bitmap.info.bmiHeader.biCompression = BI_RGB;

	HDC displayDeviceContext = GetDC(window);
	GDI_SURFACE.offscreenDeviceContext = CreateCompatibleDC(displayDeviceContext);
	ReleaseDC(window, displayDeviceContext);
	if(!GDI_SURFACE.offscreenDeviceContext) {
		TODO("CreateCompatibleDC failed\n");
		return;
	}

	void* pixels = NULL;
	bitmap.activeHandle = CreateDIBSection(GDI_SURFACE.offscreenDeviceContext, &bitmap.info,
		DIB_RGB_COLORS, &pixels, NULL, 0);
	if(!bitmap.activeHandle || !pixels) {
		TODO("CreateDIBSection failed\n");
		DeleteDC(GDI_SURFACE.offscreenDeviceContext);
		GDI_SURFACE.offscreenDeviceContext = NULL;
		return;
	}
	bitmap.pixelBuffer = pixels;

	bitmap.inactiveHandle = (HBITMAP)SelectObject(
		GDI_SURFACE.offscreenDeviceContext, bitmap.activeHandle);

	uint32* pixelArray = (uint32*)bitmap.pixelBuffer;
	size_t count = (size_t)width * (size_t)height;
	for(size_t i = 0; i < count; ++i)
		pixelArray[i] = UNINITIALIZED_WINDOW_COLOR;
}

INTERNAL void SurfaceDisplayBitmap(gdi_surface_t& windowSurface,
	gdi_bitmap_t& bitmap) {
	int destX = 0;
	int destY = 0;
	int srcX = 0;
	int srcY = 0;

	int srcW = bitmap.width;
	int srcH = bitmap.height;
	int destW = windowSurface.width;
	int destH = windowSurface.height;

	if(!StretchDIBits(windowSurface.displayDeviceContext, destX, destY, destW,
		   destH, srcX, srcY, srcW, srcH, bitmap.pixelBuffer,
		   &bitmap.info, DIB_RGB_COLORS, SRCCOPY)) {
		TODO("StretchDIBits failed in WM_PAINT\n");
	}
}

INTERNAL void SurfaceGetWindowDimensions(gdi_surface_t& surface, HWND window) {
	RECT clientRect;
	GetClientRect(window, &clientRect);
	int windowWidth = clientRect.right - clientRect.left;
	int windowHeight = clientRect.bottom - clientRect.top;
	surface.width = windowWidth;
	surface.height = windowHeight;
}