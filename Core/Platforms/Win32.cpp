#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define GLOBAL static
#define INTERNAL static

#define TODO(msg) OutputDebugStringA(msg);

typedef struct gdi_bitmap {
  int width;
  int height;
  BITMAPINFO info;
  void *pixelBuffer;
  int bytesPerPixel;
  int stride;
} gdi_bitmap_t;

GLOBAL gdi_bitmap_t GDI_BACKBUFFER = {.bytesPerPixel = 4};

GLOBAL bool APPLICATION_SHOULD_EXIT = false;
GLOBAL const char *WINDOW_TITLE = "RagLite2";

enum gdi_debug_pattern {
  PATTERN_SHIFTING_GRADIENT,
  PATTERN_CIRCULAR_RIPPLE,
  PATTERN_CHECKERBOARD,
  PATTERN_AXIS_GRADIENTS,
  PATTERN_GRID_SCANLINE,
  PATTERN_COUNT
};
GLOBAL gdi_debug_pattern GDI_DEBUG_PATTERN = PATTERN_SHIFTING_GRADIENT;

void DebugDraw_UpdatePattern() {
  DWORD MS_PER_SECOND = 1000;

  DWORD ticks = GetTickCount();
  DWORD seconds = ticks / MS_PER_SECOND;
  DWORD updateInterval = 5;

  GDI_DEBUG_PATTERN =
      (gdi_debug_pattern)((seconds / updateInterval) % PATTERN_COUNT);
}

INTERNAL void DebugDraw_ShiftingGradient(gdi_bitmap_t &bitmap, int offsetBlue,
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

// TODO Eliminate this
#include <math.h>

INTERNAL void DebugDraw_CircularRipple(gdi_bitmap_t &bitmap, int time,
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

INTERNAL void DebugDraw_Checkerboard(gdi_bitmap_t &bitmap, int time,
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

INTERNAL void DebugDraw_AxisGradients(gdi_bitmap_t &bitmap, int time,
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

INTERNAL void DebugDraw_GridScanline(gdi_bitmap_t &bitmap, int time,
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

INTERNAL void DebugDraw_WriteBitmap(gdi_bitmap_t &bitmap, int paramA,
                                    int paramB) {
  switch (GDI_DEBUG_PATTERN) {
  case PATTERN_SHIFTING_GRADIENT:
    DebugDraw_ShiftingGradient(bitmap, paramA, paramB);
    break;
  case PATTERN_CIRCULAR_RIPPLE:
    DebugDraw_CircularRipple(bitmap, paramA, paramB);
    break;
  case PATTERN_CHECKERBOARD:
    DebugDraw_Checkerboard(bitmap, paramA, paramB);
    break;
  case PATTERN_AXIS_GRADIENTS:
    DebugDraw_AxisGradients(bitmap, paramA, paramB);
    break;
  case PATTERN_GRID_SCANLINE:
    DebugDraw_GridScanline(bitmap, paramA, paramB);
    break;
  }
}

// TODO Might want to fix the stretching/aspect ratio bugs
INTERNAL void ResizeBackBuffer(gdi_bitmap_t &bitmap, int width, int height) {
  if (bitmap.pixelBuffer) {
    VirtualFree(bitmap.pixelBuffer, 0, MEM_RELEASE);
  }

  bitmap.width = width;
  bitmap.height = height;

  bitmap.info.bmiHeader.biSize = sizeof(bitmap.info.bmiHeader);
  bitmap.info.bmiHeader.biWidth = bitmap.width;
  bitmap.info.bmiHeader.biHeight = -bitmap.height; // Inverted y
  bitmap.info.bmiHeader.biPlanes = 1;
  bitmap.info.bmiHeader.biBitCount = 32;
  bitmap.info.bmiHeader.biCompression = BI_RGB; // Alpha is unused

  bitmap.stride = width * bitmap.bytesPerPixel;
  int bufferSize = height * bitmap.stride;
  TODO("VirtualAlloc outside global arena\n")
  bitmap.pixelBuffer =
      VirtualAlloc(0, bufferSize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
  // TODO Reset to clear color here?
}

INTERNAL void OnUpdate(HDC displayDeviceContext, RECT *clientRect, int x, int y,
                       gdi_bitmap_t &bitmap) {
  int xDest = 0;
  int yDest = 0;
  int xSrc = 0;
  int ySrc = 0;

  int destWidth = bitmap.width;
  int destHeight = bitmap.height;

  int windowWidth = clientRect->right - clientRect->left;
  int windowHeight = clientRect->bottom - clientRect->top;
  int srcWidth = windowWidth;
  int srcHeight = windowHeight;

  StretchDIBits(displayDeviceContext, xDest, yDest, destWidth, destHeight, xSrc,
                ySrc, srcWidth, srcHeight, bitmap.pixelBuffer, &bitmap.info,
                DIB_RGB_COLORS, SRCCOPY);
}

LRESULT CALLBACK OnMessage(HWND window, UINT message, WPARAM argW,
                           LPARAM argL) {
  LRESULT result = 0;

  switch (message) {
  case WM_SIZE: {
    RECT clientRec;
    GetClientRect(window, &clientRec);
    int width = clientRec.right - clientRec.left;
    int height = clientRec.bottom - clientRec.top;
    ResizeBackBuffer(GDI_BACKBUFFER, width, height);
  } break;

  case WM_CLOSE: {
    TODO("Received WM_CLOSE\n");
    APPLICATION_SHOULD_EXIT = true;
  } break;

  case WM_ACTIVATEAPP: {
    TODO("Received WM_ACTIVATEAPP\n");
  } break;

  case WM_DESTROY: {
    TODO("Received WM_DESTROY\n");
  } break;

  case WM_PAINT: {
    PAINTSTRUCT paintInfo;
    HDC displayDeviceContext = BeginPaint(window, &paintInfo);
    int x = paintInfo.rcPaint.left;
    int y = paintInfo.rcPaint.top;
    int width = paintInfo.rcPaint.right - paintInfo.rcPaint.left;
    int height = paintInfo.rcPaint.bottom - paintInfo.rcPaint.top;
    RECT clientRect;
    GetClientRect(window, &clientRect);
    OnUpdate(displayDeviceContext, &clientRect, x, y, GDI_BACKBUFFER);
    EndPaint(window, &paintInfo);
  } break;

  default: {
    result = DefWindowProc(window, message, argW, argL);
  } break;
  }

  return result;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE unused, LPSTR commandLine,
                   int showFlag) {

  WNDCLASSEX windowClass = {};
  // TODO Is this really a good idea? Beware the CS_OWNDC footguns...
  // TODO https://devblogs.microsoft.com/oldnewthing/20060601-06/?p=31003
  windowClass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;

  windowClass.cbSize = sizeof(windowClass);
  windowClass.lpfnWndProc = OnMessage;
  windowClass.hInstance = instance;
  windowClass.lpszClassName = "RagLiteWindowClass";
  windowClass.hIcon =
      (HICON)LoadImage(instance, TEXT("DEFAULT_APP_ICON"), IMAGE_ICON,
                       GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON),
                       LR_DEFAULTCOLOR);
  windowClass.hIconSm =
      (HICON)LoadImage(instance, TEXT("DEFAULT_APP_ICON"), IMAGE_ICON,
                       GetSystemMetrics(SM_CXSMICON),
                       GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);

  if (RegisterClassEx(&windowClass)) {
    HWND mainWindow = CreateWindowExA(
        0, windowClass.lpszClassName, WINDOW_TITLE,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
        CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, instance, 0);
    if (mainWindow) {
      HDC displayDeviceContext = GetDC(mainWindow);

      RECT clientRect;
      // TODO Can safely remove?
      GetClientRect(mainWindow, &clientRect);
      ResizeBackBuffer(GDI_BACKBUFFER, clientRect.right - clientRect.left,
                       clientRect.bottom - clientRect.top);

      MSG message;
      int offsetX = 0;
      int offsetY = 0;
      while (!APPLICATION_SHOULD_EXIT) {
        while (PeekMessage(&message, 0, 0, 0, PM_REMOVE)) {
          TranslateMessage(&message);
          DispatchMessageA(&message);
          if (message.message == WM_QUIT)
            APPLICATION_SHOULD_EXIT = true;
        }
        DebugDraw_UpdatePattern();
        DebugDraw_WriteBitmap(GDI_BACKBUFFER, offsetX, offsetY);

        RECT clientRect;
        GetClientRect(mainWindow, &clientRect);
        int windowWidth = clientRect.right - clientRect.left;
        int windowHeight = clientRect.bottom - clientRect.top;
        OnUpdate(displayDeviceContext, &clientRect, 0, 0, GDI_BACKBUFFER);

        ++offsetX;
        offsetY += 2;
      }
    } else {
      TODO("Failed to CreateWindowExA - Exiting...");
    }
  } else {
    TODO("Failed to RegisterClassEx - Exiting...");
  }

  return 0;
}
