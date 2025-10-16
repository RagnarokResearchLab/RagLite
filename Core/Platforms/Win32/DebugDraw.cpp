constexpr int DISPLAY_SCREEN_WIDTH = 1920;
GLOBAL int DEBUG_OVERLAY_LINE_HEIGHT = 18;
constexpr int DEBUG_OVERLAY_MARGIN_SIZE = 8;
constexpr int DEBUG_OVERLAY_PADDING_SIZE = 8;

constexpr size_t LINE_COUNT = 57;

constexpr int PROGRESS_BAR_HEIGHT = 16;
constexpr int PROGRESS_BAR_WIDTH = 256;
constexpr int UI_GRID_PANEL_WIDTH = PROGRESS_BAR_WIDTH + 2 * DEBUG_OVERLAY_PADDING_SIZE;

constexpr int MEMORY_OVERLAY_PANELS = 5;
constexpr int MEMORY_OVERLAY_WIDTH = MEMORY_OVERLAY_PANELS * UI_GRID_PANEL_WIDTH + (MEMORY_OVERLAY_PANELS - 1) * DEBUG_OVERLAY_MARGIN_SIZE + 2 * DEBUG_OVERLAY_PADDING_SIZE;
GLOBAL int MEMORY_OVERLAY_HEIGHT = (DEBUG_OVERLAY_LINE_HEIGHT * 40) + 3 * DEBUG_OVERLAY_PADDING_SIZE;

constexpr int PERFORMANCE_OVERLAY_PANELS = 1;
constexpr int PERFORMANCE_OVERLAY_WIDTH = PERFORMANCE_OVERLAY_PANELS * UI_GRID_PANEL_WIDTH;
GLOBAL int PERFORMANCE_OVERLAY_HEIGHT = (DEBUG_OVERLAY_LINE_HEIGHT * LINE_COUNT) + 2 * DEBUG_OVERLAY_PADDING_SIZE;

#define ColorRef(color) RGB(color.red, color.green, color.blue)
#define ColorFromRGB(r, g, b) { .blue = b, .green = g, .red = r, .alpha = 255 }
#define ColorFromRGBA(r, g, b, a) { .blue = b, .green = g, .red = r, .alpha = a }
constexpr gdi_color_t RGB_COLOR_CYAN = ColorFromRGB(120, 192, 255);
constexpr gdi_color_t RGB_COLOR_DARKEST = ColorFromRGB(0, 0, 00);
constexpr gdi_color_t RGB_COLOR_DARKER = ColorFromRGB(30, 30, 30);
constexpr gdi_color_t RGB_COLOR_DARK = ColorFromRGB(50, 50, 50);
constexpr gdi_color_t RGB_COLOR_BLUE = ColorFromRGB(0, 0, 255);
constexpr gdi_color_t RGB_COLOR_DARKGREEN = ColorFromRGB(0, 100, 0);
constexpr gdi_color_t RGB_COLOR_GRAY = ColorFromRGB(80, 80, 80);
constexpr gdi_color_t RGB_COLOR_LIGHTGRAY = ColorFromRGB(192, 192, 192);
constexpr gdi_color_t RGB_COLOR_GREEN = ColorFromRGB(0, 200, 0);
constexpr gdi_color_t RGB_COLOR_ORANGE = ColorFromRGB(255, 128, 0);
constexpr gdi_color_t RGB_COLOR_PURPLE = ColorFromRGB(64, 0, 255);
constexpr gdi_color_t RGB_COLOR_RED = ColorFromRGB(200, 0, 0);
constexpr gdi_color_t RGB_COLOR_TURQUOISE = ColorFromRGB(0, 100, 100);
constexpr gdi_color_t RGB_COLOR_YELLOW = ColorFromRGB(200, 200, 0);
constexpr gdi_color_t RGB_COLOR_WHITE = ColorFromRGB(200, 200, 200);
constexpr gdi_color_t RGB_COLOR_BRIGHTEST = ColorFromRGB(255, 255, 255);
constexpr gdi_color_t RGB_COLOR_VIOLET = ColorFromRGB(210, 168, 255);
constexpr gdi_color_t RGB_COLOR_VIOLET2 = ColorFromRGB(128, 128, 255);
constexpr gdi_color_t RGB_COLOR_FADING = ColorFromRGB(196, 186, 218);
constexpr gdi_color_t RGB_COLOR_GOLD = ColorFromRGB(236, 206, 71);
constexpr gdi_color_t RGB_COLOR_DARKGOLD = ColorFromRGB(170, 150, 15);

constexpr gdi_color_t UI_PANEL_COLOR = RGB_COLOR_DARKER;
constexpr gdi_color_t UI_BACKGROUND_COLOR = RGB_COLOR_DARK;
constexpr gdi_color_t UI_TEXT_COLOR = RGB_COLOR_WHITE;
constexpr gdi_color_t UI_HIGHLIGHT_COLOR = RGB_COLOR_RED;

constexpr gdi_color_t USED_MEMORY_BLOCK_COLOR = RGB_COLOR_GREEN;
constexpr gdi_color_t COMMITTED_MEMORY_BLOCK_COLOR = RGB_COLOR_GRAY;
constexpr gdi_color_t RESERVED_MEMORY_BLOCK_COLOR = RGB_COLOR_DARK;

INTERNAL inline void DebugDrawClipToScreen(gdi_offscreen_buffer_t& backBuffer, int& x, int& y) {
	x = ClampToInterval(x, 0, backBuffer.bitmap.width - 1);
	y = ClampToInterval(y, 0, backBuffer.bitmap.height - 1);
}

INTERNAL inline void DebugDrawClipPointToRectangle(int& x, int& y, RECT& rectangle) {
	x = ClampToInterval(x, rectangle.left, rectangle.right - 1);
	y = ClampToInterval(y, rectangle.top, rectangle.bottom - 1);
}

INTERNAL inline void DebugDrawClipPointToScreen(gdi_offscreen_buffer_t& backBuffer, int& x, int& y) {
	x = ClampToInterval(x, 0, backBuffer.bitmap.width - 1);
	y = ClampToInterval(y, 0, backBuffer.bitmap.height - 1);
}

INTERNAL inline void DebugDrawClipRectangleToScreen(gdi_offscreen_buffer_t& backBuffer, RECT& rectangle) {
	rectangle.left = ClampToInterval(rectangle.left, 0, backBuffer.bitmap.width - 1);
	rectangle.right = ClampToInterval(rectangle.right, 0, backBuffer.bitmap.width - 1);
	rectangle.top = ClampToInterval(rectangle.top, 0, backBuffer.bitmap.height - 1);
	rectangle.bottom = ClampToInterval(rectangle.bottom, 0, backBuffer.bitmap.height - 1);
}

INTERNAL inline bool DebugDrawIsPointOffscreen(int x, int y) {
	if(x >= GDI_BACKBUFFER.bitmap.width) return true;
	if(x <= 0) return true;
	if(y >= GDI_BACKBUFFER.bitmap.height) return true;
	if(y <= 0) return true;

	return false;
}

INTERNAL inline bool DebugDrawIsRectangleOffscreen(RECT& rectangle) {
	ASSUME(rectangle.left <= rectangle.right, "Unexpected horizontal orientation (don't do this, it's confusing)");
	ASSUME(rectangle.bottom >= rectangle.top, "Unexpected vertical orientation (don't do this, it's confusing)");

	if(rectangle.left >= GDI_BACKBUFFER.bitmap.width) return true;
	if(rectangle.right <= 0) return true;
	if(rectangle.top >= GDI_BACKBUFFER.bitmap.height) return true;
	if(rectangle.bottom <= 0) return true;

	return false;
}

constexpr int32 UI_BORDER_WIDTH = 1;

INTERNAL inline int DoubleGetIntegerPart(double number) {
	return (int)floor(number);
}

INTERNAL inline double DoubleGetDecimalPart(double number) {
	return number - floor(number);
}

INTERNAL inline double DoubleGetReverseDecimalPart(double number) {
	return 1.0 - DoubleGetDecimalPart(number);
}

INTERNAL inline void DebugDrawBlendPixelRGBA(gdi_color_t& source, gdi_color_t& destination, gdi_color_t& blended) {
	// TODO: Improve performance, accuracy/gamma, SSE etc. (don't try this at home, use the GPU instead)
	if(source.alpha == 0) {
		blended.red = destination.red;
		blended.blue = destination.blue;
		blended.green = destination.green;
		blended.alpha = destination.alpha;
		return;
	}

	if(source.alpha == 255) {
		blended.red = source.red;
		blended.blue = source.blue;
		blended.green = source.green;
		blended.alpha = 255;
		return;
	}

	uint8 oneMinusAlpha = 255 - source.alpha;
	int r = ((int)source.red * (int)source.alpha + (int)destination.red * oneMinusAlpha + 127) / 255;
	int g = ((int)source.green * (int)source.alpha + (int)destination.green * oneMinusAlpha + 127) / 255;
	int b = ((int)source.blue * (int)source.alpha + (int)destination.blue * oneMinusAlpha + 127) / 255;

	int a = ((int)source.alpha * 255 + (int)destination.alpha * oneMinusAlpha + 127) / 255;

	blended.red = ClampToInterval((uint8)r, 0, 255);
	blended.green = ClampToInterval((uint8)g, 0, 255);
	blended.blue = ClampToInterval((uint8)b, 0, 255);
	blended.alpha = ClampToInterval((uint8)a, 0, 255);
}

INTERNAL inline void DebugDrawSetPixelColor(int x, int y, gdi_color_t source) {
	if(x < 0 || y < 0 || x >= (int)GDI_BACKBUFFER.bitmap.width || y >= (int)GDI_BACKBUFFER.bitmap.height) {
		return;
	}

	if(source.alpha == 0) {
		return;
	}

	uint32* pixelArray = (uint32*)GDI_BACKBUFFER.bitmap.pixelBuffer;
	DebugDrawClipPointToScreen(GDI_BACKBUFFER, x, y);
	size_t pixelIndex = (size_t)x + (size_t)y * (size_t)GDI_BACKBUFFER.bitmap.width;
	gdi_color_t blended = source;
	if(source.alpha == 255) {
		blended = source;
		blended.alpha = 255;
		pixelArray[pixelIndex] = blended.bytes;
		return;
	}

	gdi_color_t destination = { .bytes = pixelArray[pixelIndex] };
	DebugDrawBlendPixelRGBA(source, destination, blended);
	pixelArray[pixelIndex] = blended.bytes;
}

INTERNAL inline void DebugDrawPlotAntiAliased(int x, int y, double alpha, gdi_color_t color) {
	if(alpha <= 0.0) return;
	if(alpha > 1.0) alpha = 1.0;
	color.alpha = (uint8)ClampToInterval((int)round(255.0 * alpha), 0, 255);
	DebugDrawSetPixelColor(x, y, color);
}

// Xiaolin Wu's Anti-Aliased Line Drawing Algorithm
INTERNAL void DebugDrawColoredLineWAA(double x0, double y0, double x1, double y1, gdi_color_t color) {
	bool isSteepLine = fabs(y1 - y0) > fabs(x1 - x0);

	if(isSteepLine) {
		Swap(x0, y0, double);
		Swap(x1, y1, double);
	}

	if(x0 > x1) {
		Swap(x0, x1, double);
		Swap(y0, y1, double);
	}

	double deltaX = x1 - x0;
	double deltaY = y1 - y0;
	double gradient = (deltaX == 0.0) ? 1.0 : deltaY / deltaX;

	// First endpoint
	double xEnd = round(x0);
	double yEnd = y0 + gradient * (xEnd - x0);
	double xGap = DoubleGetReverseDecimalPart(x0 + 0.5);
	int xPixel1 = (int)xEnd;
	int yPixel1 = DoubleGetIntegerPart(yEnd);

	if(isSteepLine) {
		DebugDrawPlotAntiAliased(yPixel1, xPixel1, DoubleGetReverseDecimalPart(yEnd) * xGap, color);
		DebugDrawPlotAntiAliased(yPixel1 + 1, xPixel1, DoubleGetDecimalPart(yEnd) * xGap, color);
	} else {
		DebugDrawPlotAntiAliased(xPixel1, yPixel1, DoubleGetReverseDecimalPart(yEnd) * xGap, color);
		DebugDrawPlotAntiAliased(xPixel1, yPixel1 + 1, DoubleGetDecimalPart(yEnd) * xGap, color);
	}

	double errY = yEnd + gradient;

	// Second endpoint
	xEnd = round(x1);
	yEnd = y1 + gradient * (xEnd - x1);
	xGap = DoubleGetDecimalPart(x1 + 0.5);
	int xPixel2 = (int)xEnd;
	int yPixel2 = DoubleGetIntegerPart(yEnd);

	if(isSteepLine) {
		DebugDrawPlotAntiAliased(yPixel2, xPixel2, DoubleGetReverseDecimalPart(yEnd) * xGap, color);
		DebugDrawPlotAntiAliased(yPixel2 + 1, xPixel2, DoubleGetDecimalPart(yEnd) * xGap, color);
	} else {
		DebugDrawPlotAntiAliased(xPixel2, yPixel2, DoubleGetReverseDecimalPart(yEnd) * xGap, color);
		DebugDrawPlotAntiAliased(xPixel2, yPixel2 + 1, DoubleGetDecimalPart(yEnd) * xGap, color);
	}

	// Main loop
	if(isSteepLine) {
		for(int x = xPixel1 + 1; x < xPixel2; x++) {
			DebugDrawPlotAntiAliased(DoubleGetIntegerPart(errY), x, DoubleGetReverseDecimalPart(errY), color);
			DebugDrawPlotAntiAliased(DoubleGetIntegerPart(errY) + 1, x, DoubleGetDecimalPart(errY), color);
			errY += gradient;
		}
	} else {
		for(int x = xPixel1 + 1; x < xPixel2; x++) {
			DebugDrawPlotAntiAliased(x, DoubleGetIntegerPart(errY), DoubleGetReverseDecimalPart(errY), color);
			DebugDrawPlotAntiAliased(x, DoubleGetIntegerPart(errY) + 1, DoubleGetDecimalPart(errY), color);
			errY += gradient;
		}
	}
}

// Digital Differential Analyzer Line Drawing Algorithm
INTERNAL void DebugDrawColoredLineDDA(double startX, double startY, double endX, double endY, gdi_color_t color) {
	double deltaX = endX - startX;
	double deltaY = endY - startY;
	double absDeltaX = fabs(deltaX);
	double absDeltaY = fabs(deltaY);

	int steps = (absDeltaX > absDeltaY) ? (int)absDeltaX : (int)absDeltaY;
	double xIncrement = deltaX / steps;
	double yIncrement = deltaY / steps;

	double x = startX;
	double y = startY;
	for(int i = 0; i <= steps; i++) {
		DebugDrawSetPixelColor((int)round(x), (int)round(y), color);
		x += xIncrement;
		y += yIncrement;
	}
}

// Bresenham's Integer Line Drawing Algorithm
INTERNAL void DebugDrawColoredLineBHI(int x0, int y0, int x1, int y1, gdi_color_t color) {
	int deltaX = abs(x1 - x0);
	int stepX = (x0 < x1) ? 1 : -1;
	int deltaY = -abs(y1 - y0);
	int stepY = (y0 < y1) ? 1 : -1;
	int accumulatedError = deltaX + deltaY;

	while(true) {
		DebugDrawSetPixelColor(x0, y0, color);
		if(x0 == x1 && y0 == y1) break;
		int errorThreshold = 2 * accumulatedError;
		if(errorThreshold >= deltaY) {
			accumulatedError += deltaY;
			x0 += stepX;
		}
		if(errorThreshold <= deltaX) {
			accumulatedError += deltaX;
			y0 += stepY;
		}
	}
}

constexpr int32 DEFAULT_LINE_WIDTH = 1;
INTERNAL inline void DebugDrawColoredLineGDI(HDC& displayDeviceContext, int startX, int startY, int endX, int endY, gdi_color_t color) {
	// TODO: Cache the pens, or select from an array of preallocated ones to begin with
	HPEN graphPen = CreatePen(PS_SOLID, DEFAULT_LINE_WIDTH, RGB(color.red, color.green, color.blue));
	HGDIOBJ oldPen = SelectObject(displayDeviceContext, graphPen);

	MoveToEx(displayDeviceContext, startX, startY, NULL);
	LineTo(displayDeviceContext, endX, endY);

	SelectObject(displayDeviceContext, oldPen);
	DeleteObject(graphPen);
}

INTERNAL inline void DebugDrawColoredLine(HDC& displayDeviceContext, int startX, int startY, int endX, int endY, gdi_color_t color) {
	if(DebugDrawIsPointOffscreen(startX, startY) && DebugDrawIsPointOffscreen(endX, endY)) return;

	ASSUME(SELECTED_LINE_DRAWING_METHOD < LINE_STYLE_COUNT, "Invalid line drawing algorithm selected");

	switch(SELECTED_LINE_DRAWING_METHOD) {
		case DEFAULT_GDI_LINE: {
			DebugDrawColoredLineGDI(displayDeviceContext, startX, startY, endX, endY, color);
		} break;
		case BRESENHAM_INTEGER_LINE: {
			DebugDrawColoredLineBHI(startX, startY, endX, endY, color);
		} break;
		case DDA_FLOAT_LINE: {
			DebugDrawColoredLineDDA(startX, startY, endX, endY, color);
		} break;
		case WU_FLOAT_LINE: {
			DebugDrawColoredLineWAA(startX, startY, endX, endY, color);
		} break;
	}
}

INTERNAL inline void DebugDrawVerticalLine(HDC& displayDeviceContext, int startX, int startY, int endX, int endY, gdi_color_t color) {
	if(DebugDrawIsPointOffscreen(startX, startY) && DebugDrawIsPointOffscreen(endX, endY)) return;

	endX = startX;
	int minY = Min(startY, endY);
	int maxY = Max(startY, endY);

	uint32* pixelArray = (uint32*)GDI_BACKBUFFER.bitmap.pixelBuffer;
	DebugDrawClipPointToScreen(GDI_BACKBUFFER, startX, minY);
	DebugDrawClipPointToScreen(GDI_BACKBUFFER, endX, maxY);
	for(size_t y = minY; y <= maxY; ++y) { // For now: End is inclusive (GDI convention)
		pixelArray[startX + y * GDI_BACKBUFFER.bitmap.width] = color.bytes;
	}
}

INTERNAL inline void DebugDrawSolidColorRectangle(HDC& displayDeviceContext, RECT& rectangle, gdi_color_t color) {
	if(DebugDrawIsRectangleOffscreen(rectangle)) return;

	uint32* pixelArray = (uint32*)GDI_BACKBUFFER.bitmap.pixelBuffer;
	DebugDrawClipRectangleToScreen(GDI_BACKBUFFER, rectangle);

	for(size_t y = rectangle.top; y < rectangle.bottom; ++y) {
		for(size_t x = rectangle.left; x < rectangle.right; ++x) {
			pixelArray[x + y * GDI_BACKBUFFER.bitmap.width] = color.bytes;
		}
	}
}

INTERNAL inline void DebugDrawFramedColorRectangle(HDC& displayDeviceContext, RECT& rectangle, gdi_color_t rgbColor) {
	if(DebugDrawIsRectangleOffscreen(rectangle)) return;

	uint32* pixelArray = (uint32*)GDI_BACKBUFFER.bitmap.pixelBuffer;
	DebugDrawClipRectangleToScreen(GDI_BACKBUFFER, rectangle);

	// Top edge
	for(int x = rectangle.left; x < rectangle.right; ++x) {
		pixelArray[x + rectangle.top * GDI_BACKBUFFER.bitmap.width] = rgbColor.bytes;
	}

	// Bottom edge
	for(int x = rectangle.left; x < rectangle.right; ++x) {
		pixelArray[x + rectangle.bottom * GDI_BACKBUFFER.bitmap.width] = rgbColor.bytes;
	}

	// Left and right edges
	for(int y = rectangle.top; y < rectangle.bottom; ++y) {
		pixelArray[rectangle.left + y * GDI_BACKBUFFER.bitmap.width] = rgbColor.bytes;
		pixelArray[rectangle.right + y * GDI_BACKBUFFER.bitmap.width] = rgbColor.bytes;
	}
}

INTERNAL void DebugDrawHistoryGraph(HDC& displayDeviceContext, int topLeftX, int topLeftY, int panelWidth, int panelHeight, history_graph_style_t chartType) {
	RECT borderRect = { topLeftX, topLeftY, topLeftX + panelWidth, topLeftY + panelHeight };
	DebugDrawSolidColorRectangle(displayDeviceContext, borderRect, RGB_COLOR_WHITE);

	RECT panelRect = { borderRect.left + UI_BORDER_WIDTH, borderRect.top + UI_BORDER_WIDTH, borderRect.right - UI_BORDER_WIDTH, borderRect.bottom - UI_BORDER_WIDTH };
	DebugDrawSolidColorRectangle(displayDeviceContext, panelRect, UI_BACKGROUND_COLOR);

	milliseconds maxFrameTime = Max(PERFORMANCE_METRICS_HISTORY.highestObservedFrameTime, MAX_FRAME_TIME);
	int innerHeight = panelRect.bottom - panelRect.top;
	int innerWidth = panelRect.right - panelRect.left;
	percentage graphScale = (percentage)(innerHeight / maxFrameTime);
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

				int lineEndX = panelRect.left + offset * innerWidth / PERFORMANCE_HISTORY_SIZE;
				int barHeight = (int)(recorded.frameTime * graphScale);
				int lineEndY = panelRect.bottom - barHeight;

				if(recordIndex == 0) lineStartX = lineEndX; // There's no previous line to connect to

				DebugDrawClipPointToRectangle(lineStartX, lineStartY, panelRect);
				DebugDrawClipPointToRectangle(lineEndX, lineEndY, panelRect);

				if(recorded.frameTime >= EPSILON) DebugDrawColoredLine(displayDeviceContext, lineStartX, lineStartY, lineEndX, lineEndY, RGB_COLOR_CYAN);

				lineStartX = lineEndX;
				lineStartY = lineEndY;
			}
			int cutoffLineX = panelRect.left + PERFORMANCE_METRICS_HISTORY.oldestRecordedSampleIndex * panelWidth / PERFORMANCE_HISTORY_SIZE;
			int cutoffLineY = panelRect.bottom;
			DebugDrawClipPointToRectangle(cutoffLineX, cutoffLineY, panelRect);
			DebugDrawVerticalLine(displayDeviceContext, cutoffLineX, cutoffLineY, cutoffLineX, panelRect.top, RGB_COLOR_DARKGREEN);
		} break;

		case AREA_PERCENT_STACKED: {

			for(int offset = 0; offset < PERFORMANCE_HISTORY_SIZE; offset++) {
				int recordIndex = (PERFORMANCE_METRICS_HISTORY.oldestRecordedSampleIndex + offset) % PERFORMANCE_HISTORY_SIZE;
				performance_metrics_t recorded = PERFORMANCE_METRICS_HISTORY.recordedSamples[recordIndex];
				if(recorded.frameTime < EPSILON) continue;

				int lineStartX = panelRect.left + offset * innerWidth / PERFORMANCE_HISTORY_SIZE;
				int lineStartY = panelRect.bottom - UI_BORDER_WIDTH;
				DebugDrawClipPointToRectangle(lineStartX, lineStartY, panelRect);

				int barHeight = innerHeight;
				int lineEndX = lineStartX;

				percentage filled = (percentage)(recorded.userInterfaceRenderTime / recorded.frameTime);
				int lineEndY = lineStartY - (int)(filled * barHeight) + 1;
				DebugDrawClipPointToRectangle(lineEndX, lineEndY, panelRect);
				DebugDrawVerticalLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_GOLD);
				lineStartY = lineEndY;

				filled = (percentage)(recorded.simulationStepTime / recorded.frameTime);
				lineEndY = lineStartY - (int)(filled * barHeight) + 1;
				DebugDrawClipPointToRectangle(lineEndX, lineEndY, panelRect);
				DebugDrawVerticalLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_VIOLET);
				lineStartY = lineEndY;

				filled = (percentage)(recorded.surfaceBlitTime / recorded.frameTime);
				lineEndY = lineStartY - (int)(filled * barHeight) + 1;
				DebugDrawClipPointToRectangle(lineEndX, lineEndY, panelRect);
				DebugDrawVerticalLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_TURQUOISE);
				lineStartY = lineEndY;

				filled = (percentage)(recorded.suspendedTime / recorded.frameTime);
				lineEndY = lineStartY - (int)(filled * barHeight) + 1;
				DebugDrawClipPointToRectangle(lineEndX, lineEndY, panelRect);
				DebugDrawVerticalLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_DARKGREEN);
				lineStartY = lineEndY;

				filled = (percentage)(recorded.messageProcessingTime / recorded.frameTime);
				lineEndY = lineStartY - (int)(filled * barHeight) + 1;
				DebugDrawClipPointToRectangle(lineEndX, lineEndY, panelRect);
				DebugDrawVerticalLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_ORANGE);
				lineStartY = lineEndY;

				lineEndY = panelRect.top;
				DebugDrawVerticalLine(displayDeviceContext, lineStartX, lineStartY, lineStartX, lineEndY, RGB_COLOR_GRAY);
			}
		} break;
	}
}

inline gdi_color_t ProgressBarGetDeficitColor(int percent) {
	if(percent < 50) return RGB_COLOR_GREEN;
	if(percent < 75) return RGB_COLOR_YELLOW;
	if(percent < 90) return RGB_COLOR_ORANGE;
	return RGB_COLOR_RED;
}

inline gdi_color_t ProgressBarGetCompletionColor(int percent) {
	if(percent >= 90) return RGB_COLOR_GREEN;
	if(percent >= 75) return RGB_COLOR_YELLOW;
	if(percent >= 50) return RGB_COLOR_ORANGE;
	return RGB_COLOR_RED;
}

INTERNAL void DrawProgressBarWithColors(HDC& displayDeviceContext, progress_bar_t& bar, gdi_color_t foregroundColor) {
	RECT borderRect = { bar.x, bar.y, bar.x + bar.width, bar.y + bar.height };
	DebugDrawSolidColorRectangle(displayDeviceContext, borderRect, RGB_COLOR_WHITE);

	RECT barRect = { borderRect.left + UI_BORDER_WIDTH, borderRect.top + UI_BORDER_WIDTH, borderRect.right - UI_BORDER_WIDTH, borderRect.bottom - UI_BORDER_WIDTH };
	DebugDrawSolidColorRectangle(displayDeviceContext, barRect, UI_BACKGROUND_COLOR);

	int innerWidth = barRect.right - barRect.left;
	int filledWidth = (innerWidth * bar.percent) / 100;
	RECT fillRect = { barRect.left, barRect.top, barRect.left + filledWidth, barRect.bottom };
	DebugDrawSolidColorRectangle(displayDeviceContext, fillRect, foregroundColor);
}

INTERNAL inline void DrawProgressBar(HDC& displayDeviceContext, progress_bar_t& bar) {
	gdi_color_t foregroundColor = ProgressBarGetDeficitColor(bar.percent);
	DrawProgressBarWithColors(displayDeviceContext, bar, foregroundColor);
}

INTERNAL void DebugDrawMemoryArenaHeatmap(HDC& displayDeviceContext, memory_arena_t& arena, int startX, int startY, int width, int height) {
	LONG lineY = startY + DEBUG_OVERLAY_PADDING_SIZE;

	RECT borderRect = { startX, startY, startX + width, startY + height };
	DebugDrawSolidColorRectangle(displayDeviceContext, borderRect, RGB_COLOR_WHITE);

	RECT panelRect = { borderRect.left + UI_BORDER_WIDTH, borderRect.top + UI_BORDER_WIDTH, borderRect.right - UI_BORDER_WIDTH, borderRect.bottom - UI_BORDER_WIDTH };
	DebugDrawSolidColorRectangle(displayDeviceContext, panelRect, UI_PANEL_COLOR);

	constexpr size_t FORMAT_BUFFER_SIZE = 256;
	char formatBuffer[FORMAT_BUFFER_SIZE];

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Name: %s", arena.displayName.buffer);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	String lifetime = SystemMemoryDebugLifetime(arena);
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Lifetime: %s", lifetime.buffer);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	String usage = SystemMemoryDebugUsage(arena);
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Usage: %s", usage.buffer);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Base: 0x%p", arena.baseAddress);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	// TBD: This may be too inaccurate for large arenas? Better to select appropripate units automatically
	double committed = (double)arena.committedSize / Megabytes(1);
	double reserved = (double)arena.reservedSize / Megabytes(1);
	percentage committedPercent = DoubleToFloat(committed / Max(reserved, EPSILON));
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Committed: %d MB / %d MB (%d%%)",
		(int)(committed),
		(int)(reserved), Percent(committedPercent));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	progress_bar_t progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = PROGRESS_BAR_WIDTH, .height = PROGRESS_BAR_HEIGHT, .percent = Percent(committedPercent) };
	DrawProgressBar(displayDeviceContext, progressBar);
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;
	percentage usedPercent = DoubleToFloat((double)(arena.used) / Max(arena.committedSize, EPSILON));
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Allocated: %d MB / %d MB (%d%%)",
		(int)(arena.used / Megabytes(1)),
		(int)(arena.committedSize / Megabytes(1)), Percent(usedPercent));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	progressBar = { .x = startX + DEBUG_OVERLAY_PADDING_SIZE, .y = lineY, .width = PROGRESS_BAR_WIDTH, .height = PROGRESS_BAR_HEIGHT, .percent = Percent(usedPercent) };
	DrawProgressBar(displayDeviceContext, progressBar);
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	const size_t blockSize = CPU_PERFORMANCE_INFO.allocationGranularity;
	size_t totalBlocks = arena.reservedSize / blockSize;
	size_t usedBlocks = arena.used / blockSize;
	size_t committedBlocks = arena.committedSize / blockSize;

	lineY += DEBUG_OVERLAY_MARGIN_SIZE;

	// TODO: Compute this (only in debug mode)
	int totalAllocationCount = 0;
	int avgAllocationSize = 0;
	int totalAllocationSize = 0;
	int avgAllocationsPerSecond = 0;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Allocations: %d - %d - %d - %d - %d", arena.allocationCount, totalAllocationCount, totalAllocationSize, avgAllocationSize, avgAllocationsPerSecond);
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Blocks: %d / %d / %d (%d KB each)", usedBlocks, committedBlocks, totalBlocks, blockSize / Kilobytes(1));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	LONG ARENA_BLOCK_GAP = 1;
	LONG ARENA_BLOCK_WIDTH = 2;
	LONG ARENA_BLOCK_HEIGHT = 4;
	// Wrap to multiple rows if the arena is too large
	int availableContentWidth = (width - 2 * DEBUG_OVERLAY_PADDING_SIZE - ARENA_BLOCK_GAP);
	int totalBlockWidth = (ARENA_BLOCK_WIDTH + ARENA_BLOCK_GAP);
	LONG blocksPerRow = availableContentWidth / totalBlockWidth;
	LONG arenaStartX = startX + DEBUG_OVERLAY_PADDING_SIZE + ARENA_BLOCK_GAP;
	LONG arenaStartY = lineY;

	//-------------------------------------------------
	// Blocks
	//-------------------------------------------------
	for(LONG blockID = 0; blockID < totalBlocks; ++blockID) {
		gdi_color_t color;
		if(blockID < usedBlocks) {
			color = USED_MEMORY_BLOCK_COLOR;
		} else if(blockID < committedBlocks) {
			color = COMMITTED_MEMORY_BLOCK_COLOR;
		} else {
			color = RESERVED_MEMORY_BLOCK_COLOR;
		}

		RECT block = {
			arenaStartX + (blockID % blocksPerRow) * (ARENA_BLOCK_WIDTH + ARENA_BLOCK_GAP),
			arenaStartY + (blockID / blocksPerRow) * (ARENA_BLOCK_HEIGHT + ARENA_BLOCK_GAP),
			arenaStartX + (blockID % blocksPerRow) * (ARENA_BLOCK_WIDTH + ARENA_BLOCK_GAP) + ARENA_BLOCK_WIDTH,
			arenaStartY + (blockID / blocksPerRow) * (ARENA_BLOCK_HEIGHT + ARENA_BLOCK_GAP) + ARENA_BLOCK_HEIGHT
		};
		// For simplicity, just cut off any boxes that don't actually fit the container
		bool boxWillFitEntirely = (block.bottom + DEBUG_OVERLAY_PADDING_SIZE < startY + height);
		if(boxWillFitEntirely) DebugDrawSolidColorRectangle(displayDeviceContext, block, color);
	}
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
	DebugDrawSolidColorRectangle(displayDeviceContext, backgroundPanelRect, UI_PANEL_COLOR);

	SetTextColor(displayDeviceContext, ColorRef(UI_TEXT_COLOR));
	LONG lineY = startY + DEBUG_OVERLAY_PADDING_SIZE;

	//-------------------------------------------------
	// Arena stats
	//-------------------------------------------------
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY,
		"=== MEMORY ARENAS ===", lstrlenA("=== MEMORY ARENAS ==="));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	int headerHeight = lineY - startY;
	int availableHeight = MEMORY_OVERLAY_HEIGHT - headerHeight - DEBUG_OVERLAY_MARGIN_SIZE;
	constexpr int MAIN_MEMORY_PANELS = 1;
	constexpr int TRANSIENT_MEMORY_PANELS = 4;
	constexpr int NUM_HORIZONTAL_GRID_CELLS = MAIN_MEMORY_PANELS + TRANSIENT_MEMORY_PANELS;
	constexpr int NUM_VERTICAL_GRID_CELLS = 1;
	int heatmapWidth = UI_GRID_PANEL_WIDTH;
	int heatmapHeight = availableHeight / NUM_VERTICAL_GRID_CELLS;

	startX += DEBUG_OVERLAY_PADDING_SIZE;

	heatmapWidth = MAIN_MEMORY_PANELS * heatmapWidth + (MAIN_MEMORY_PANELS - 1) * DEBUG_OVERLAY_MARGIN_SIZE;
	DebugDrawMemoryArenaHeatmap(displayDeviceContext, MAIN_MEMORY, startX, lineY, heatmapWidth, heatmapHeight);
	startX += heatmapWidth;
	startX += DEBUG_OVERLAY_MARGIN_SIZE;

	heatmapWidth = TRANSIENT_MEMORY_PANELS * heatmapWidth + (TRANSIENT_MEMORY_PANELS - 1) * DEBUG_OVERLAY_MARGIN_SIZE;
	DebugDrawMemoryArenaHeatmap(displayDeviceContext, TRANSIENT_MEMORY, startX, lineY, heatmapWidth, heatmapHeight);
	startX += heatmapWidth;
	startX += DEBUG_OVERLAY_PADDING_SIZE;

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
	DebugDrawSolidColorRectangle(displayDeviceContext, panelRect, UI_PANEL_COLOR);

	SetTextColor(displayDeviceContext, ColorRef(UI_TEXT_COLOR));

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

	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "GDI Objects: %d", GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS));
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

	FPS frameRate = MILLISECONDS_PER_SECOND / CPU_PERFORMANCE_METRICS.frameTime;
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
	percentage worldRenderPercentage = CPU_PERFORMANCE_METRICS.surfaceBlitTime / CPU_PERFORMANCE_METRICS.frameTime;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Surface Blit: %.0f ms (%d%%)", CPU_PERFORMANCE_METRICS.surfaceBlitTime,
		Percent(worldRenderPercentage));
	TextOutA(displayDeviceContext, startX + DEBUG_OVERLAY_PADDING_SIZE, lineY, formatBuffer, lstrlenA(formatBuffer));
	lineY += DEBUG_OVERLAY_LINE_HEIGHT;

	percentage worldUpdatePercentage = CPU_PERFORMANCE_METRICS.simulationStepTime / CPU_PERFORMANCE_METRICS.frameTime;
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Simulation: %.0f ms (%d%%)", CPU_PERFORMANCE_METRICS.simulationStepTime,
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
			size_t totalMemoryUsed = pmc.PrivateUsage + pmc.WorkingSetSize;
			percentage procPercent = DoubleToFloat((double)(totalMemoryUsed) / memoryUsageInfo.ullTotalPhys);
			StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Memory Usage: %d MB / %d MB (%d%%)",
				(int)(totalMemoryUsed / Megabytes(1)),
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
	StringCbPrintfA(formatBuffer, FORMAT_BUFFER_SIZE, "Page Size: %u KB (Allocation Granularity: %u KB)", CPU_PERFORMANCE_INFO.pageSize, CPU_PERFORMANCE_INFO.allocationGranularity / Kilobytes(1));
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

		gdi_color_t backgroundColor = UI_PANEL_COLOR;
		if(wasKeyDown)
			backgroundColor = UI_HIGHLIGHT_COLOR;

		DebugDrawSolidColorRectangle(displayDeviceContext, textArea, backgroundColor);

		SetTextColor(displayDeviceContext, ColorRef(UI_TEXT_COLOR));
		const char* label = KeyCodeToDebugName(virtualKeyCode);
		DrawTextA(displayDeviceContext, label, -1, &textArea,
			DT_CENTER | DT_VCENTER | DT_SINGLELINE);
	}

	SelectObject(displayDeviceContext, oldFont);
}
