#pragma once

typedef struct gdi_bitmap {
	HBITMAP handle;
	BITMAPINFO info;
	int width;
	int height;
	int bytesPerPixel;
	int stride;
	void* pixelBuffer;
} gdi_offscreen_buffer_t;

typedef struct gdi_surface {
	HDC displayDeviceContext;
	HDC offscreenDeviceContext;
	int width;
	int height;
} gdi_surface_t;

typedef enum : uint8 {
	PATTERN_SHIFTING_GRADIENT,
	PATTERN_CIRCULAR_RIPPLE,
	PATTERN_CHECKERBOARD,
	PATTERN_AXIS_GRADIENTS,
	PATTERN_GRID_SCANLINE,
	PATTERN_COUNT
} gdi_debug_pattern_t;

GLOBAL gdi_offscreen_buffer_t GDI_BACKBUFFER = {};
GLOBAL gdi_surface_t GDI_SURFACE = {};
GLOBAL gdi_debug_pattern_t GDI_DEBUG_PATTERN = PATTERN_SHIFTING_GRADIENT;

typedef union gdi_rgba_color {
	// NOTE: For simplicity, ensure this matches the pixel format used by GDI bitmaps
	struct {
		uint8 blue;
		uint8 green;
		uint8 red;
		uint8 alpha;
	};
	uint32 bytes;
} gdi_color_t;

constexpr gdi_color_t UNINITIALIZED_WINDOW_COLOR = { .bytes = 0xFF202020 };

typedef struct gdi_progress_bar {
	int x;
	int y;
	int width;
	int height;
	int percent;
} progress_bar_t;

typedef enum {
	XY_LINES_PLOTTED,
	AREA_PERCENT_STACKED,
} history_graph_style_t;

typedef enum {
	DEFAULT_GDI_LINE,
	BRESENHAM_INTEGER_LINE,
	DDA_FLOAT_LINE,
	WU_FLOAT_LINE,
	LINE_STYLE_COUNT,

} line_drawing_style_t;

GLOBAL line_drawing_style_t SELECTED_LINE_DRAWING_METHOD = DEFAULT_GDI_LINE;