
// TODO Eliminate this
#include <math.h>

typedef struct gdi_bitmap {
  HBITMAP activeHandle;
  HBITMAP inactiveHandle;
  BITMAPINFO info;
  int width;
  int height;
  int bytesPerPixel;
  int stride;
  void *pixelBuffer;
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

void DebugDrawUpdateBackgroundPattern() {
  DWORD MS_PER_SECOND = 1000;

  DWORD ticks = GetTickCount();
  DWORD seconds = ticks / MS_PER_SECOND;
  DWORD updateInterval = 5;

  GDI_DEBUG_PATTERN =
      (gdi_debug_pattern)((seconds / updateInterval) % PATTERN_COUNT);
}

INTERNAL void DebugDrawUseMarchingGradientPattern(gdi_bitmap_t &bitmap,
                                                  int offsetBlue,
                                                  int offsetGreen) {
  if (!bitmap.pixelBuffer)
    return;

  uint8 *row = (uint8 *)bitmap.pixelBuffer;
  for (int y = 0; y < bitmap.height; ++y) {
    uint32 *pixel = (uint32 *)row;
    for (int x = 0; x < bitmap.width; ++x) {
      uint8 blue = (x + offsetBlue) & 0xFF;
      uint8 green = (y + offsetGreen) & 0xFF;

      *pixel++ = ((green << 8) | blue);
    }

    row += bitmap.stride;
  }
}

INTERNAL void DebugDrawUseRipplingSpiralPattern(gdi_bitmap_t &bitmap, int time,
                                                int unused) {
  if (!bitmap.pixelBuffer)
    return;

  uint8 *row = (uint8 *)bitmap.pixelBuffer;

  for (int y = 0; y < bitmap.height; ++y) {
    uint32 *pixel = (uint32 *)row;
    for (int x = 0; x < bitmap.width; ++x) {

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

INTERNAL void DebugDrawUseCheckeredFloorPattern(gdi_bitmap_t &bitmap, int time,
                                                int unused) {
  if (!bitmap.pixelBuffer)
    return;

  uint8 *row = (uint8 *)bitmap.pixelBuffer;

  float angle = time * 0.02f;
  float cosA = cosf(angle);
  float sinA = sinf(angle);

  int cx = bitmap.width / 2;
  int cy = bitmap.height / 2;

  int squareSize = 32;

  for (int y = 0; y < bitmap.height; ++y) {
    uint32 *pixel = (uint32 *)row;
    for (int x = 0; x < bitmap.width; ++x) {
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

INTERNAL void DebugDrawUseColorGradientPattern(gdi_bitmap_t &bitmap, int time,
                                               int unused) {
  if (!bitmap.pixelBuffer)
    return;

  uint8 *row = (uint8 *)bitmap.pixelBuffer;

  int cx = bitmap.width / 2;
  int cy = bitmap.height / 2;

  for (int y = 0; y < bitmap.height; ++y) {
    uint32 *pixel = (uint32 *)row;
    for (int x = 0; x < bitmap.width; ++x) {
      uint8 red = (uint8)((x * 255) / bitmap.width);
      uint8 green = (uint8)((y * 255) / bitmap.height);
      uint8 blue = 0;

      if (x == cx || y == cy) {
        red = green = blue = 255;
      }

      *pixel++ = (red << 16) | (green << 8) | blue;
    }
    row += bitmap.stride;
  }
}

INTERNAL void DebugDrawUseMovingScanlinePattern(gdi_bitmap_t &bitmap, int time,
                                                int unused) {
  if (!bitmap.pixelBuffer)
    return;

  uint8 *row = (uint8 *)bitmap.pixelBuffer;

  int gridSpacing = 32;
  int scanY = (time / 2) % bitmap.height;

  for (int y = 0; y < bitmap.height; ++y) {
    uint32 *pixel = (uint32 *)row;
    for (int x = 0; x < bitmap.width; ++x) {
      uint8 c = 180;

      if (x % gridSpacing == 0 || y % gridSpacing == 0)
        c = 100;

      if (y == scanY)
        c = 255;

      *pixel++ = (c << 16) | (c << 8) | c;
    }
    row += bitmap.stride;
  }
}

INTERNAL void DebugDrawUpdateFrameBuffer(gdi_bitmap_t &bitmap, int paramA,
                                         int paramB) {
  switch (GDI_DEBUG_PATTERN) {
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

INTERNAL void ResizeBackBuffer(gdi_bitmap_t &bitmap, int width, int height,
                               HWND window) {
  if (GDI_SURFACE.offscreenDeviceContext) {
    if (bitmap.inactiveHandle) {
      SelectObject(GDI_SURFACE.offscreenDeviceContext, bitmap.inactiveHandle);
      bitmap.inactiveHandle = NULL;
    }
    DeleteDC(GDI_SURFACE.offscreenDeviceContext);
    GDI_SURFACE.offscreenDeviceContext = NULL;
  }

  if (bitmap.activeHandle) {
    DeleteObject(bitmap.activeHandle);
    bitmap.activeHandle = NULL;
  }

  if (bitmap.pixelBuffer) {
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
  if (!GDI_SURFACE.offscreenDeviceContext) {
    TODO("CreateCompatibleDC failed\n");
    return;
  }

  void *pixels = NULL;
  bitmap.activeHandle =
      CreateDIBSection(GDI_SURFACE.offscreenDeviceContext, &bitmap.info,
                       DIB_RGB_COLORS, &pixels, NULL, 0);
  if (!bitmap.activeHandle || !pixels) {
    TODO("CreateDIBSection failed\n");
    DeleteDC(GDI_SURFACE.offscreenDeviceContext);
    GDI_SURFACE.offscreenDeviceContext = NULL;
    return;
  }
  bitmap.pixelBuffer = pixels;

  bitmap.inactiveHandle = (HBITMAP)SelectObject(
      GDI_SURFACE.offscreenDeviceContext, bitmap.activeHandle);

  uint32 *pixelArray = (uint32 *)bitmap.pixelBuffer;
  size_t count = (size_t)width * (size_t)height;
  for (size_t i = 0; i < count; ++i)
    pixelArray[i] = UNINITIALIZED_WINDOW_COLOR;
}

INTERNAL void SurfaceDisplayBitmap(gdi_surface_t &windowSurface,
                                   gdi_bitmap_t &bitmap) {
  int destX = 0;
  int destY = 0;
  int srcX = 0;
  int srcY = 0;

  int srcW = bitmap.width;
  int srcH = bitmap.height;
  int destW = windowSurface.width;
  int destH = windowSurface.height;

  if (!StretchDIBits(windowSurface.displayDeviceContext, destX, destY, destW,
                     destH, srcX, srcY, srcW, srcH, bitmap.pixelBuffer,
                     &bitmap.info, DIB_RGB_COLORS, SRCCOPY)) {
    TODO("StretchDIBits failed in WM_PAINT\n");
  }
}

INTERNAL void SurfaceGetWindowDimensions(gdi_surface_t &surface, HWND window) {
  RECT clientRect;
  GetClientRect(window, &clientRect);
  int windowWidth = clientRect.right - clientRect.left;
  int windowHeight = clientRect.bottom - clientRect.top;
  surface.width = windowWidth;
  surface.height = windowHeight;
}