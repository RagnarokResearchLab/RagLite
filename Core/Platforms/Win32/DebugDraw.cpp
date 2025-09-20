#include "DebugDraw.hpp"

// TODO Eliminate this
#include <math.h>

constexpr int DISPLAY_SCREEN_WIDTH = 1920;
GLOBAL int DEBUG_OVERLAY_LINE_HEIGHT = 18;
constexpr int DEBUG_OVERLAY_MARGIN_SIZE = 8;
constexpr int DEBUG_OVERLAY_PADDING_SIZE = 8;

constexpr size_t LINE_COUNT = 57;

constexpr int PROGRESS_BAR_HEIGHT = 16;
constexpr int PROGRESS_BAR_WIDTH = 256;

constexpr int MEMORY_OVERLAY_WIDTH = 1024 + 128 + 2 * DEBUG_OVERLAY_PADDING_SIZE;
GLOBAL int MEMORY_OVERLAY_HEIGHT = (DEBUG_OVERLAY_LINE_HEIGHT * LINE_COUNT) + 2 * DEBUG_OVERLAY_PADDING_SIZE;

constexpr int PERFORMANCE_OVERLAY_WIDTH = PROGRESS_BAR_WIDTH + 2 * DEBUG_OVERLAY_PADDING_SIZE;
GLOBAL int PERFORMANCE_OVERLAY_HEIGHT = (DEBUG_OVERLAY_LINE_HEIGHT * LINE_COUNT) + 2 * DEBUG_OVERLAY_PADDING_SIZE;

constexpr COLORREF RGB_COLOR_CYAN = RGB(120, 192, 255);
constexpr COLORREF RGB_COLOR_DARKEST = RGB(0, 0, 00);
constexpr COLORREF RGB_COLOR_DARKER = RGB(30, 30, 30);
constexpr COLORREF RGB_COLOR_DARK = RGB(50, 50, 50);
constexpr COLORREF RGB_COLOR_BLUE = RGB(0, 0, 255);
constexpr COLORREF RGB_COLOR_DARKGREEN = RGB(0, 100, 0);
constexpr COLORREF RGB_COLOR_GRAY = RGB(80, 80, 80);
constexpr COLORREF RGB_COLOR_LIGHTGRAY = RGB(192, 192, 192);
constexpr COLORREF RGB_COLOR_GREEN = RGB(0, 200, 0);
constexpr COLORREF RGB_COLOR_ORANGE = RGB(255, 128, 0);
constexpr COLORREF RGB_COLOR_PURPLE = RGB(64, 0, 255);
constexpr COLORREF RGB_COLOR_RED = RGB(200, 0, 0);
constexpr COLORREF RGB_COLOR_TURQUOISE = RGB(0, 100, 100);
constexpr COLORREF RGB_COLOR_YELLOW = RGB(200, 200, 0);
constexpr COLORREF RGB_COLOR_WHITE = RGB(200, 200, 200);
constexpr COLORREF RGB_COLOR_BRIGHTEST = RGB(255, 255, 255);
constexpr COLORREF RGB_COLOR_VIOLET = RGB(210, 168, 255);
constexpr COLORREF RGB_COLOR_VIOLET2 = RGB(128, 128, 255);
constexpr COLORREF RGB_COLOR_FADING = RGB(196, 186, 218);
constexpr COLORREF RGB_COLOR_GOLD = RGB(236, 206, 71);
constexpr COLORREF RGB_COLOR_DARKGOLD = RGB(170, 150, 15);

constexpr COLORREF UI_PANEL_COLOR = RGB_COLOR_DARKER;
constexpr COLORREF UI_BACKGROUND_COLOR = RGB_COLOR_DARK;
constexpr COLORREF UI_TEXT_COLOR = RGB_COLOR_WHITE;
constexpr COLORREF UI_HIGHLIGHT_COLOR = RGB_COLOR_RED;

constexpr COLORREF USED_MEMORY_BLOCK_COLOR = RGB_COLOR_GREEN;
constexpr COLORREF COMMITTED_MEMORY_BLOCK_COLOR = RGB_COLOR_GRAY;
constexpr COLORREF RESERVED_MEMORY_BLOCK_COLOR = RGB_COLOR_DARK;

constexpr int32 GRAPH_BORDER_WIDTH = 1;

constexpr int32 DEFAULT_LINE_WIDTH = 1;
INTERNAL inline void DebugDrawColoredLine(HDC& displayDeviceContext, int startX, int startY, int endX, int endY, COLORREF color) {
	HPEN graphPen = CreatePen(PS_SOLID, DEFAULT_LINE_WIDTH, color);
	HGDIOBJ oldPen = SelectObject(displayDeviceContext, graphPen);

	MoveToEx(displayDeviceContext, startX, startY, NULL);
	LineTo(displayDeviceContext, endX, endY);

	SelectObject(displayDeviceContext, oldPen);
	DeleteObject(graphPen);
}

INTERNAL void DebugDrawHistoryGraph(HDC& displayDeviceContext, int topLeftX, int topLeftY, int panelWidth, int panelHeight, history_graph_style_t chartType) {
	HBRUSH backgroundBrush = CreateSolidBrush(UI_BACKGROUND_COLOR);
	int left = topLeftX + GRAPH_BORDER_WIDTH;
	int top = topLeftY + GRAPH_BORDER_WIDTH;
	int right = left + panelWidth - GRAPH_BORDER_WIDTH;
	int bottom = top + panelHeight - GRAPH_BORDER_WIDTH;
	RECT panelRect = { left, top, right, bottom };
	FillRect(displayDeviceContext, &panelRect, backgroundBrush);
	DeleteObject(backgroundBrush);

	milliseconds maxFrameTime = Max(PERFORMANCE_METRICS_HISTORY.highestObservedFrameTime, MAX_FRAME_TIME);
	percentage graphScale = (percentage)(panelHeight / maxFrameTime);
	if(maxFrameTime < EPSILON) return;

	switch(chartType) {

	case XY_LINES_PLOTTED: {
		int fpsTargetLineOffsetY = panelRect.bottom - (int)(MAX_FRAME_TIME * graphScale);
		DebugDrawColoredLine(displayDeviceContext, panelRect.left, fpsTargetLineOffsetY, panelRect.right, fpsTargetLineOffsetY, RGB_COLOR_LIGHTGRAY);

		int lineStartX = panelRect.left;
		int lineStartY = panelRect.bottom;
		for(int offset = 0; offset < PERFORMANCE_HISTORY_SIZE; offset++) {
			int recordIndex = (PERFORMANCE_METRICS_HISTORY.oldestRecordedSampleIndex + offset) % PERFORMANCE_HISTORY_SIZE;
			performance_metrics_t recorded = PERFORMANCE_METRICS_HISTORY.recordedSamples[recordIndex];
			if(recorded.frameTime < EPSILON) continue;

			int lineEndX = panelRect.left + offset * panelWidth / PERFORMANCE_HISTORY_SIZE;
			int barHeight = (int)(recorded.frameTime * graphScale);
			int lineEndY = panelRect.bottom - barHeight;

			if(recordIndex == 0) lineStartX = lineEndX; // There's no previous line to connect to

			lineStartX = ClampToInterval(lineStartX, panelRect.left + GRAPH_BORDER_WIDTH, panelRect.right - GRAPH_BORDER_WIDTH);
			lineEndX = ClampToInterval(lineEndX, panelRect.left + GRAPH_BORDER_WIDTH, panelRect.right - GRAPH_BORDER_WIDTH);
			lineStartY = ClampToInterval(lineStartY, panelRect.top + GRAPH_BORDER_WIDTH, panelRect.bottom - GRAPH_BORDER_WIDTH);
			lineEndY = ClampToInterval(lineEndY, panelRect.top + GRAPH_BORDER_WIDTH, panelRect.bottom - GRAPH_BORDER_WIDTH);

			if(recorded.frameTime >= EPSILON) DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineEndX, lineEndY, RGB_COLOR_CYAN);

			lineStartX = lineEndX;
			lineStartY = lineEndY;
		}
	} break;

	case AREA_PERCENT_STACKED: {

		for(int offset = 0; offset < PERFORMANCE_HISTORY_SIZE; offset++) {
			int recordIndex = (PERFORMANCE_METRICS_HISTORY.oldestRecordedSampleIndex + offset) % PERFORMANCE_HISTORY_SIZE;
			performance_metrics_t recorded = PERFORMANCE_METRICS_HISTORY.recordedSamples[recordIndex];
			if(recorded.frameTime < EPSILON) continue;

			int lineStartX = panelRect.left + offset * panelWidth / PERFORMANCE_HISTORY_SIZE;
			lineStartX = ClampToInterval(lineStartX, panelRect.left + GRAPH_BORDER_WIDTH, panelRect.right - GRAPH_BORDER_WIDTH);
			int lineEndX = lineStartX;
			int lineStartY = panelRect.bottom - GRAPH_BORDER_WIDTH;

			int barHeight = panelHeight;

			percentage filled = (percentage)(recorded.userInterfaceRenderTime / recorded.frameTime);
			int lineEndY = lineStartY - (int)(filled * barHeight) + 1;
			DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_GOLD);
			lineStartY = ClampToInterval(lineEndY, panelRect.top + GRAPH_BORDER_WIDTH, panelRect.bottom - GRAPH_BORDER_WIDTH);

			filled = (percentage)(recorded.worldUpdateTime / recorded.frameTime);
			lineEndY = lineStartY - (int)(filled * barHeight) + 1;
			DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_VIOLET);
			lineStartY = ClampToInterval(lineEndY, panelRect.top + GRAPH_BORDER_WIDTH, panelRect.bottom - GRAPH_BORDER_WIDTH);

			filled = (percentage)(recorded.worldRenderTime / recorded.frameTime);
			lineEndY = lineStartY - (int)(filled * barHeight) + 1;
			DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_TURQUOISE);
			lineStartY = ClampToInterval(lineEndY, panelRect.top + GRAPH_BORDER_WIDTH, panelRect.bottom - GRAPH_BORDER_WIDTH);

			filled = (percentage)(recorded.suspendedTime / recorded.frameTime);
			lineEndY = lineStartY - (int)(filled * barHeight) + 1;
			DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_DARKGREEN);
			lineStartY = ClampToInterval(lineEndY, panelRect.top + GRAPH_BORDER_WIDTH, panelRect.bottom - GRAPH_BORDER_WIDTH);

			filled = (percentage)(recorded.messageProcessingTime / recorded.frameTime);
			lineEndY = lineStartY - (int)(filled * barHeight) + 1;
			DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_ORANGE);
			lineStartY = ClampToInterval(lineEndY, panelRect.top + GRAPH_BORDER_WIDTH, panelRect.bottom - GRAPH_BORDER_WIDTH);

			lineEndY = panelRect.top;
			DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_GRAY);
		}
	} break;
	}

	HPEN borderPen = CreatePen(PS_SOLID, GRAPH_BORDER_WIDTH, RGB_COLOR_WHITE);
	HGDIOBJ oldPen = SelectObject(displayDeviceContext, borderPen);
	HGDIOBJ oldBrush = SelectObject(displayDeviceContext, GetStockObject(HOLLOW_BRUSH));
	Rectangle(displayDeviceContext, panelRect.left, panelRect.top, panelRect.right, panelRect.bottom);

	SelectObject(displayDeviceContext, oldPen);
	SelectObject(displayDeviceContext, oldBrush);
	DeleteObject(borderPen);
}

inline COLORREF ProgressBarGetDeficitColor(int percent) {
	if(percent < 50) return RGB_COLOR_GREEN;
	if(percent < 75) return RGB_COLOR_YELLOW;
	if(percent < 90) return RGB_COLOR_ORANGE;
	return RGB_COLOR_RED;
}

inline COLORREF ProgressBarGetCompletionColor(int percent) {
	if(percent >= 90) return RGB_COLOR_GREEN;
	if(percent >= 75) return RGB_COLOR_YELLOW;
	if(percent >= 50) return RGB_COLOR_ORANGE;
	return RGB_COLOR_RED;
}

INTERNAL inline void DrawSolidColorRectangle(HDC& displayDeviceContext, RECT rectangle, COLORREF color) {
	HBRUSH brush = CreateSolidBrush(color);
	FillRect(displayDeviceContext, &rectangle, brush);
	DeleteObject(brush);
	FrameRect(displayDeviceContext, &rectangle, (HBRUSH)GetStockObject(WHITE_BRUSH));
}

INTERNAL void DrawProgressBarWithColors(HDC& displayDeviceContext, progress_bar_t& bar, COLORREF foregroundColor) {
	HBRUSH backgroundBrush = CreateSolidBrush(UI_BACKGROUND_COLOR);
	RECT rect = { bar.x, bar.y, bar.x + bar.width, bar.y + bar.height };
	FillRect(displayDeviceContext, &rect, backgroundBrush);
	DeleteObject(backgroundBrush);

	int filledWidth = (bar.width * bar.percent) / 100;
	HBRUSH foregroundBrush = CreateSolidBrush(foregroundColor);
	RECT fillRect = { bar.x, bar.y, bar.x + filledWidth, bar.y + bar.height };
	FillRect(displayDeviceContext, &fillRect, foregroundBrush);
	DeleteObject(foregroundBrush);

	FrameRect(displayDeviceContext, &rect, (HBRUSH)GetStockObject(WHITE_BRUSH));
}

INTERNAL inline void DrawProgressBar(HDC& displayDeviceContext, progress_bar_t& bar) {
	COLORREF foregroundColor = ProgressBarGetDeficitColor(bar.percent);
	DrawProgressBarWithColors(displayDeviceContext, bar, foregroundColor);
}

INTERNAL void DebugDrawMemoryUsageOverlay(HDC& displayDeviceContext) {
	SetBkMode(displayDeviceContext, TRANSPARENT);
	HFONT font = (HFONT)GetStockObject(ANSI_VAR_FONT);
	HFONT oldFont = (HFONT)SelectObject(displayDeviceContext, font);

	int startX = 0 + DEBUG_OVERLAY_MARGIN_SIZE;
	int startY = 300;
	RECT backgroundPanelRect = {
		startX,
		startY,
		startX + MEMORY_OVERLAY_WIDTH,
		startY + MEMORY_OVERLAY_HEIGHT
	};
	HBRUSH panelBrush = CreateSolidBrush(UI_PANEL_COLOR);
	FillRect(displayDeviceContext, &backgroundPanelRect, panelBrush);
	DeleteObject(panelBrush);

	SetTextColor(displayDeviceContext, UI_TEXT_COLOR);

	constexpr size_t FORMAT_BUFFER_SIZE = 256;
	char formatBuffer[FORMAT_BUFFER_SIZE];
	LONG lineY = startY + DEBUG_OVERLAY_PADDING_SIZE;

	//-------------------------------------------------
	// Arena stats
	//-------------------------------------------------
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== MEMORY ARENAS ===", lstrlenA("=== MEMORY ARENAS ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Name: %s", MAIN_MEMORY.name);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Lifetime: %s", MAIN_MEMORY.lifetime);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Base: 0x%p", MAIN_MEMORY.baseAddress);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Reserved: %d KB", MAIN_MEMORY.reservedSize / Kilobytes(1));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Committed: %d KB", MAIN_MEMORY.committedSize / Kilobytes(1));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Used: %d KB", MAIN_MEMORY.used / Kilobytes(1));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Free: %d KB", (MAIN_MEMORY.committedSize - MAIN_MEMORY.used) / Kilobytes(1));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Allocations: %d", MAIN_MEMORY.allocationCount);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	const size_t blockSize = Kilobytes(64);
	size_t totalBlocks = MAIN_MEMORY.reservedSize / blockSize;
	size_t usedBlocks = MAIN_MEMORY.used / blockSize;
	size_t committedBlocks = MAIN_MEMORY.committedSize / blockSize;

	LONG ARENA_BLOCK_WIDTH = 2;
	LONG ARENA_BLOCK_HEIGHT = 4;
	LONG blocksPerRow = 256 + 128; // Wrap to multiple rows if the arena is too large
	LONG arenaStartX = startX + DEBUG_OVERLAY_PADDING_SIZE;
	LONG arenaStartY = lineY;

	//-------------------------------------------------
	// Blocks
	//-------------------------------------------------
	for(LONG blockID = 0; blockID < totalBlocks; ++blockID) {
		COLORREF color;
		if(blockID < usedBlocks) {
			color = USED_MEMORY_BLOCK_COLOR;
		} else if(blockID < committedBlocks) {
			color = COMMITTED_MEMORY_BLOCK_COLOR;
		} else {
			color = RESERVED_MEMORY_BLOCK_COLOR;
		}

		HBRUSH brush = CreateSolidBrush(color);
		RECT block = {
			arenaStartX + (blockID % blocksPerRow) * (ARENA_BLOCK_WIDTH + 1), // TBD NARROW +
			arenaStartY + (blockID / blocksPerRow) * (ARENA_BLOCK_HEIGHT + 1),
			arenaStartX + (blockID % blocksPerRow) * (ARENA_BLOCK_WIDTH + 1) + ARENA_BLOCK_WIDTH,
			arenaStartY + (blockID / blocksPerRow) * (ARENA_BLOCK_HEIGHT + 1) + ARENA_BLOCK_HEIGHT
		};
		FillRect(displayDeviceContext, &block, brush);
		DeleteObject(brush);
	}

	SelectObject(displayDeviceContext, oldFont);
}

INTERNAL void DebugDrawProcessorUsageOverlay(HDC& displayDeviceContext) {
	SetBkMode(displayDeviceContext, TRANSPARENT);
	HFONT font = (HFONT)GetStockObject(ANSI_VAR_FONT);
	HFONT oldFont = (HFONT)SelectObject(displayDeviceContext, font);

	int startX = DISPLAY_SCREEN_WIDTH - PERFORMANCE_OVERLAY_WIDTH - DEBUG_OVERLAY_MARGIN_SIZE;
	int startY = DEBUG_OVERLAY_MARGIN_SIZE;
	RECT panelRect = {
		startX,
		startY,
		startX + PERFORMANCE_OVERLAY_WIDTH,
		startY + PERFORMANCE_OVERLAY_HEIGHT
	};
	HBRUSH panelBrush = CreateSolidBrush(UI_PANEL_COLOR);
	FillRect(displayDeviceContext, &panelRect, panelBrush);
	DeleteObject(panelBrush);

	SetTextColor(displayDeviceContext, UI_TEXT_COLOR);

	constexpr size_t FORMAT_BUFFER_SIZE = 256;
	char formatBuffer[FORMAT_BUFFER_SIZE];
	char uptimeBuffer[FORMAT_BUFFER_SIZE];
	int lineY = startY + DEBUG_OVERLAY_PADDING_SIZE;
	StrFromTimeIntervalA(uptimeBuffer, FORMAT_BUFFER_SIZE, (DWORD)CPU_PERFORMANCE_METRICS.applicationUptime, FOUR_DIGITS);
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Uptime:%s", uptimeBuffer);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Startup Time: %.0f ms", CPU_PERFORMANCE_INFO.applicationLaunchTime);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	//-------------------------------------------------
	// CPU usage stats
	//-------------------------------------------------
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== CPU UTILIZATION ===", lstrlenA("=== CPU UTILIZATION ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	percentage processorUsageAllCores = GetProcessorUsageAllCores();
	percentage processorUsageSingleCore = processorUsageAllCores * CPU_PERFORMANCE_INFO.numberOfProcessors;
	int cpuUsage = Percent(processorUsageSingleCore);
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Main Thread (Single Core): %d%%", cpuUsage);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	progress_bar_t progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = PROGRESS_BAR_WIDTH, .height = PROGRESS_BAR_HEIGHT, .percent = cpuUsage };
	DrawProgressBar(displayDeviceContext, progressBar);
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	cpuUsage = Percent(processorUsageAllCores);
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Process (All Cores): %d%%", cpuUsage);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	progressBar.y = lineY;
	progressBar.percent = cpuUsage;
	DrawProgressBar(displayDeviceContext, progressBar);
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	//-------------------------------------------------
	// Frame timings
	//-------------------------------------------------
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== FRAME STATS ===", lstrlenA("=== FRAME STATS ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	char timeBuffer[32];

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Frame Time: %.0f ms", CPU_PERFORMANCE_METRICS.frameTime);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Highest Recorded Inter-Frame Delay: %.0f ms", PERFORMANCE_METRICS_HISTORY.highestObservedFrameTime);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	int historyGraphHeight = DEBUG_OVERLAY_LINE_HEIGHT * 3;
	DebugDrawHistoryGraph(displayDeviceContext,
		startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		PROGRESS_BAR_WIDTH, historyGraphHeight, XY_LINES_PLOTTED);
	lineY += historyGraphHeight + DEBUG_OVERLAY_MARGIN_SIZE;

	FPS frameRate = MILLISECONDS_PER_SECOND / CPU_PERFORMANCE_METRICS.frameTime; // TODO lastFrameTime
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Uncapped Frame Rate: %.0f FPS (Target: %.0f FPS)", frameRate, TARGET_FRAME_RATE);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	percentage frameBudgetUtilization = CPU_PERFORMANCE_METRICS.frameTime / MAX_FRAME_TIME;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Frame Budget: ");
	DoubleToString(timeBuffer, MAX_FRAME_TIME, ZERO_DIGITS);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, timeBuffer);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, " ms");
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, " (Used: ");
	DoubleToString(timeBuffer, Percent(frameBudgetUtilization), ZERO_DIGITS);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, timeBuffer);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, "%)");
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	progressBar.y = lineY;
	progressBar.percent = Percent(frameBudgetUtilization);
	DrawProgressBar(displayDeviceContext, progressBar);
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;

	percentage messageProcessingPercentage = CPU_PERFORMANCE_METRICS.messageProcessingTime / CPU_PERFORMANCE_METRICS.frameTime;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Message Processing: %.0f ms (%d%%)", CPU_PERFORMANCE_METRICS.messageProcessingTime, Percent(messageProcessingPercentage));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	percentage interfaceDrawPercentage = CPU_PERFORMANCE_METRICS.userInterfaceRenderTime / CPU_PERFORMANCE_METRICS.frameTime;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "User Interface: %.0f ms (%d%%)", CPU_PERFORMANCE_METRICS.userInterfaceRenderTime,
		Percent(interfaceDrawPercentage));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	// TODO DRY
	percentage worldRenderPercentage = CPU_PERFORMANCE_METRICS.worldRenderTime / CPU_PERFORMANCE_METRICS.frameTime;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "World Render: %.0f ms (%d%%)", CPU_PERFORMANCE_METRICS.worldRenderTime,
		Percent(worldRenderPercentage));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	percentage worldUpdatePercentage = CPU_PERFORMANCE_METRICS.worldUpdateTime / CPU_PERFORMANCE_METRICS.frameTime;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "World Update: %.0f ms (%d%%)", CPU_PERFORMANCE_METRICS.worldUpdateTime,
		Percent(worldUpdatePercentage));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Sleep: ");
	DoubleToString(timeBuffer, CPU_PERFORMANCE_METRICS.sleepTime, ZERO_DIGITS);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, timeBuffer);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, " ms (Suspended: ");
	DoubleToString(timeBuffer, CPU_PERFORMANCE_METRICS.suspendedTime, ZERO_DIGITS);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, timeBuffer);
	StringCchCatA(formatBuffer, FORMAT_BUFFER_SIZE, " ms)");
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "History (%d samples over %d sec):", PERFORMANCE_HISTORY_SIZE, PERFORMANCE_HISTORY_SECONDS);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	int breakdownGraphHeight = DEBUG_OVERLAY_LINE_HEIGHT * 3;
	DebugDrawHistoryGraph(displayDeviceContext,
		startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		PROGRESS_BAR_WIDTH, breakdownGraphHeight, AREA_PERCENT_STACKED);
	lineY += breakdownGraphHeight + DEBUG_OVERLAY_MARGIN_SIZE;

	//-------------------------------------------------
	// System stats
	//-------------------------------------------------
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== SYSTEM MEMORY ===", lstrlenA("=== SYSTEM MEMORY ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	MEMORYSTATUSEX memoryUsageInfo = {};
	memoryUsageInfo.dwLength = sizeof(memoryUsageInfo);
	PROCESS_MEMORY_COUNTERS_EX pmc;

	if(!GlobalMemoryStatusEx(&memoryUsageInfo)) {
		DWORD err = GetLastError();
		LPTSTR errStr = FormatErrorString(err);

		StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "N/A: %lu (%s)", err, errStr);
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;
	} else {
		StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Total Physical Memory: %d MB (%.0f GB)",
			(int)(memoryUsageInfo.ullTotalPhys / Megabytes(1)),
			(double)memoryUsageInfo.ullTotalPhys / Gigabytes(1));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Available Physical Memory: %d MB (%.0f GB)", (int)(memoryUsageInfo.ullAvailPhys / Megabytes(1)), (double)memoryUsageInfo.ullAvailPhys / Gigabytes(1));
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		lineY += DEBUG_OVERLAY_MARGIN_SIZE;
		StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Physical Memory Load: %d MB / %d MB (%d%%)",
			(int)((memoryUsageInfo.ullTotalPhys - memoryUsageInfo.ullAvailPhys) / Megabytes(1)),

			(int)(memoryUsageInfo.ullTotalPhys / Megabytes(1)),
			memoryUsageInfo.dwMemoryLoad);
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		int sysUsage = memoryUsageInfo.dwMemoryLoad;
		progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = PROGRESS_BAR_WIDTH, .height = PROGRESS_BAR_HEIGHT, .percent = sysUsage };
		DrawProgressBar(displayDeviceContext,
			progressBar);
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		//-------------------------------------------------
		// Process stats
		//-------------------------------------------------
		lineY += DEBUG_OVERLAY_MARGIN_SIZE;
		lineY += DEBUG_OVERLAY_MARGIN_SIZE;
		TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
			"=== PROCESS MEMORY	 ===", lstrlenA("=== PROCESS MEMORY ==="));
		lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		if(GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
			StringCbPrintfA(formatBuffer,
				FORMAT_BUFFER_SIZE,
				"Total Virtual Memory: %d MB (%.0f GB)",
				(int)(memoryUsageInfo.ullTotalPageFile / Megabytes(1)),
				(double)memoryUsageInfo.ullTotalPageFile / Gigabytes(1));
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Available Virtual Memory: %d MB (%.0f GB)",
				(int)(memoryUsageInfo.ullAvailPageFile / Megabytes(1)),
				(double)memoryUsageInfo.ullAvailPageFile / Gigabytes(1));
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

			lineY += DEBUG_OVERLAY_MARGIN_SIZE;
			uint64 virtualMemoryUsed = memoryUsageInfo.ullTotalPageFile - memoryUsageInfo.ullAvailPageFile;
			percentage virtualMemoryUsage = DoubleToFloat((double)virtualMemoryUsed / memoryUsageInfo.ullTotalPageFile);
			progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = PROGRESS_BAR_WIDTH, .height = PROGRESS_BAR_HEIGHT, .percent = Percent(virtualMemoryUsage) };
			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Virtual Memory Load: %d MB / %d MB (%d%%)",
				(int)(virtualMemoryUsed / Megabytes(1)),
				(int)(memoryUsageInfo.ullTotalPageFile / Megabytes(1)),
				progressBar.percent);

			progressBar.y += DEBUG_OVERLAY_LINE_HEIGHT;
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;
			DrawProgressBar(displayDeviceContext, progressBar);
			lineY += DEBUG_OVERLAY_MARGIN_SIZE;

			lineY += DEBUG_OVERLAY_LINE_HEIGHT;
			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Private Set: %d MB", (int)(pmc.PrivateUsage / Megabytes(1)));
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Working Set: %d MB (Peak: %d MB)", (int)(pmc.WorkingSetSize / Megabytes(1)), (int)(pmc.PeakWorkingSetSize / Megabytes(1)));
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Page File Usage: %d MB (Peak: %d MB)", (int)(pmc.PagefileUsage / Megabytes(1)), (int)(pmc.PeakPagefileUsage / Megabytes(1)));
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

			lineY += DEBUG_OVERLAY_MARGIN_SIZE;
			percentage procPercent = DoubleToFloat((double)pmc.WorkingSetSize / memoryUsageInfo.ullTotalPhys);
			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Memory Usage: %d MB / %d MB (%d%%)",
				(int)(pmc.WorkingSetSize / Megabytes(1)),
				(int)(memoryUsageInfo.ullTotalPhys / Megabytes(1)), Percent(procPercent));

			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE,
				lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

			progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = PROGRESS_BAR_WIDTH, .height = PROGRESS_BAR_HEIGHT, .percent = Percent(procPercent) };
			DrawProgressBarWithColors(displayDeviceContext, progressBar, ProgressBarGetCompletionColor(progressBar.percent));

			DrawProgressBar(displayDeviceContext, progressBar);
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;

		} else {
			DWORD err = GetLastError();
			LPTSTR errStr = FormatErrorString(err);

			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "N/A: %lu (%s)", err, errStr);
			TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
			lineY += DEBUG_OVERLAY_LINE_HEIGHT;
		}
	}

	//-------------------------------------------------
	// Native system info
	//-------------------------------------------------
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== HARDWARE INFORMATION ===", lstrlenA("=== HARDWARE INFORMATION ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE,
		"%s",
		NTDLL_VERSION_STRING);

	TextOutA(displayDeviceContext,
		startX + DEBUG_OVERLAY_PADDING_SIZE,
		lineY,
		formatBuffer,
		lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "CPU: %s", CPU_BRAND_STRING);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	const char* arch = ArchitectureToDebugName(CPU_PERFORMANCE_INFO.processorArchitecture);
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Processor Architecture: %s (%d bit)", arch, BITS_PER_BYTE * PLATFORM_POINTER_SIZE);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Number of Cores: %u", CPU_PERFORMANCE_INFO.numberOfProcessors);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Page Size: %u KB", CPU_PERFORMANCE_INFO.pageSize);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Allocation Granularity: %u KB", CPU_PERFORMANCE_INFO.allocationGranularity / Kilobytes(1));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	SelectObject(displayDeviceContext, oldFont);
}

constexpr int KEYBOARD_DEBUG_OVERLAY_CELL_WIDTH = 100;
constexpr int KEYBOARD_DEBUG_OVERLAY_CELL_HEIGHT = 18;

INTERNAL void DebugDrawKeyboardOverlay(HDC& displayDeviceContext) {
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
	DWORD ticks = GetTickCount();
	seconds elapsed = (seconds)ticks / MILLISECONDS_PER_SECOND;
	seconds updateInterval = 5.0f;

	gdi_debug_pattern_t newPattern = (gdi_debug_pattern_t)(elapsed / updateInterval);
	GDI_DEBUG_PATTERN = (gdi_debug_pattern_t)(newPattern % PATTERN_COUNT);
}

INTERNAL void DebugDrawUseMarchingGradientPattern(gdi_offscreen_buffer_t& bitmap,
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

INTERNAL void DebugDrawUseRipplingSpiralPattern(gdi_offscreen_buffer_t& bitmap, int time,
	int) {
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

INTERNAL void DebugDrawUseCheckeredFloorPattern(gdi_offscreen_buffer_t& bitmap, int time,
	int) {
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

			uint8 c = (checkerX ^ checkerY) ? (PROGRESS_BAR_WIDTH - 1) : 80;
			*pixel++ = (c << 16) | (c << 8) | c;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseColorGradientPattern(gdi_offscreen_buffer_t& bitmap, int,
	int) {
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

INTERNAL void DebugDrawUseMovingScanlinePattern(gdi_offscreen_buffer_t& bitmap, int time,
	int) {
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

INTERNAL void DebugDrawIntoFrameBuffer(gdi_offscreen_buffer_t& bitmap, int paramA,
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
