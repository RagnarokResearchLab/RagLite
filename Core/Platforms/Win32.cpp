#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define GLOBAL static
#define INTERNAL static

#define TODO(msg) OutputDebugStringA(msg);

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

GLOBAL gdi_bitmap_t GDI_BACKBUFFER = {};
GLOBAL gdi_surface_t GDI_SURFACE = {};

constexpr uint32 UNINITIALIZED_WINDOW_COLOR = 0xFF202020;

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

typedef struct virtual_key_info {
  const char *name;
  unsigned char code;
  const char *description;
} virtual_key_info_t;

constexpr int KEYBOARD_DEBUG_OVERLAY_CELL_WIDTH = 100;
constexpr int KEYBOARD_DEBUG_OVERLAY_CELL_HEIGHT = 18;

INTERNAL constexpr virtual_key_info_t vkTable[256] = {
    {"VK_NULL", 0x00, "Null (not used)"},
    {"VK_LBUTTON", 0x01, "Left mouse button"},
    {"VK_RBUTTON", 0x02, "Right mouse button"},
    {"VK_CANCEL", 0x03, "Control-break processing"},
    {"VK_MBUTTON", 0x04, "Middle mouse button"},
    {"VK_XBUTTON1", 0x05, "X1 mouse button"},
    {"VK_XBUTTON2", 0x06, "X2 mouse button"},
    {"RSRVD_07", 0x07, "Reserved"},
    {"VK_BACK", 0x08, "Backspace key"},
    {"VK_TAB", 0x09, "Tab key"},
    {"RSRVD_0A", 0x0A, "Reserved"},
    {"RSRVD_0B", 0x0B, "Reserved"},
    {"VK_CLEAR", 0x0C, "Clear key"},
    {"VK_RETURN", 0x0D, "Enter key"},
    {"UNSSGN_0E", 0x0E, "Unassigned"},
    {"UNSSGN_0F", 0x0F, "Unassigned"},
    {"VK_SHIFT", 0x10, "Shift key"},
    {"VK_CONTROL", 0x11, "Ctrl key"},
    {"VK_MENU", 0x12, "Alt key"},
    {"VK_PAUSE", 0x13, "Pause key"},
    {"VK_CAPITAL", 0x14, "Caps Lock key"},
    {"VK_KANA", 0x15, "IME Kana/Hangul mode"},
    {"VK_IME_ON", 0x16, "IME On"},
    {"VK_JUNJA", 0x17, "IME Junja mode"},
    {"VK_FINAL", 0x18, "IME Final mode"},
    {"VK_HANJA", 0x19, "IME Hanja/Kanji mode"},
    {"VK_IME_OFF", 0x1A, "IME Off"},
    {"VK_ESCAPE", 0x1B, "Escape key"},
    {"VK_CNVRT", 0x1C, "IME Convert"},
    {"VK_NOCNVRT", 0x1D, "IME Nonconvert"},
    {"VK_ACCEPT", 0x1E, "IME Accept"},
    {"VK_MDCHNG", 0x1F, "IME Mode change request"},
    {"VK_SPACE", 0x20, "Spacebar"},
    {"VK_PRIOR", 0x21, "Page Up key"},
    {"VK_NEXT", 0x22, "Page Down key"},
    {"VK_END", 0x23, "End key"},
    {"VK_HOME", 0x24, "Home key"},
    {"VK_LEFT", 0x25, "Left arrow key"},
    {"VK_UP", 0x26, "Up arrow key"},
    {"VK_RIGHT", 0x27, "Right arrow key"},
    {"VK_DOWN", 0x28, "Down arrow key"},
    {"VK_SELECT", 0x29, "Select key"},
    {"VK_PRINT", 0x2A, "Print key"},
    {"VK_EXECUTE", 0x2B, "Execute key"},
    {"VK_SNAPSHOT", 0x2C, "Print Screen key"},
    {"VK_INSERT", 0x2D, "Insert key"},
    {"VK_DELETE", 0x2E, "Delete key"},
    {"VK_HELP", 0x2F, "Help key"},
    {"0", 0x30, "0 key"},
    {"1", 0x31, "1 key"},
    {"2", 0x32, "2 key"},
    {"3", 0x33, "3 key"},
    {"4", 0x34, "4 key"},
    {"5", 0x35, "5 key"},
    {"6", 0x36, "6 key"},
    {"7", 0x37, "7 key"},
    {"8", 0x38, "8 key"},
    {"9", 0x39, "9 key"},
    {"UNDEF_3A", 0x3A, "Undefined"},
    {"UNDEF_3B", 0x3B, "Undefined"},
    {"UNDEF_3C", 0x3C, "Undefined"},
    {"UNDEF_3D", 0x3D, "Undefined"},
    {"UNDEF_3E", 0x3E, "Undefined"},
    {"UNDEF_3F", 0x3F, "Undefined"},
    {"UNDEF_40", 0x40, "Undefined"},
    {"A", 0x41, "A key"},
    {"B", 0x42, "B key"},
    {"C", 0x43, "C key"},
    {"D", 0x44, "D key"},
    {"E", 0x45, "E key"},
    {"F", 0x46, "F key"},
    {"G", 0x47, "G key"},
    {"H", 0x48, "H key"},
    {"I", 0x49, "I key"},
    {"J", 0x4A, "J key"},
    {"K", 0x4B, "K key"},
    {"L", 0x4C, "L key"},
    {"M", 0x4D, "M key"},
    {"N", 0x4E, "N key"},
    {"O", 0x4F, "O key"},
    {"P", 0x50, "P key"},
    {"Q", 0x51, "Q key"},
    {"R", 0x52, "R key"},
    {"S", 0x53, "S key"},
    {"T", 0x54, "T key"},
    {"U", 0x55, "U key"},
    {"V", 0x56, "V key"},
    {"W", 0x57, "W key"},
    {"X", 0x58, "X key"},
    {"Y", 0x59, "Y key"},
    {"Z", 0x5A, "Z key"},
    {"VK_LWIN", 0x5B, "Left Windows key"},
    {"VK_RWIN", 0x5C, "Right Windows key"},
    {"VK_APPS", 0x5D, "Application key"},
    {"RSRVD_5E", 0x5E, "Reserved"},
    {"VK_SLEEP", 0x5F, "Computer Sleep key"},
    {"VK_NUMPAD0", 0x60, "Numeric keypad 0"},
    {"VK_NUMPAD1", 0x61, "Numeric keypad 1"},
    {"VK_NUMPAD2", 0x62, "Numeric keypad 2"},
    {"VK_NUMPAD3", 0x63, "Numeric keypad 3"},
    {"VK_NUMPAD4", 0x64, "Numeric keypad 4"},
    {"VK_NUMPAD5", 0x65, "Numeric keypad 5"},
    {"VK_NUMPAD6", 0x66, "Numeric keypad 6"},
    {"VK_NUMPAD7", 0x67, "Numeric keypad 7"},
    {"VK_NUMPAD8", 0x68, "Numeric keypad 8"},
    {"VK_NUMPAD9", 0x69, "Numeric keypad 9"},
    {"VK_MULTIPLY", 0x6A, "Multiply key"},
    {"VK_ADD", 0x6B, "Add key"},
    {"VK_SPRTR", 0x6C, "Separator key"},
    {"VK_SBTRCT", 0x6D, "Subtract key"},
    {"VK_DCML", 0x6E, "Decimal key"},
    {"VK_DVD", 0x6F, "Divide key"},
    {"VK_F1", 0x70, "F1 key"},
    {"VK_F2", 0x71, "F2 key"},
    {"VK_F3", 0x72, "F3 key"},
    {"VK_F4", 0x73, "F4 key"},
    {"VK_F5", 0x74, "F5 key"},
    {"VK_F6", 0x75, "F6 key"},
    {"VK_F7", 0x76, "F7 key"},
    {"VK_F8", 0x77, "F8 key"},
    {"VK_F9", 0x78, "F9 key"},
    {"VK_F10", 0x79, "F10 key"},
    {"VK_F11", 0x7A, "F11 key"},
    {"VK_F12", 0x7B, "F12 key"},
    {"VK_F13", 0x7C, "F13 key"},
    {"VK_F14", 0x7D, "F14 key"},
    {"VK_F15", 0x7E, "F15 key"},
    {"VK_F16", 0x7F, "F16 key"},
    {"VK_F17", 0x80, "F17 key"},
    {"VK_F18", 0x81, "F18 key"},
    {"VK_F19", 0x82, "F19 key"},
    {"VK_F20", 0x83, "F20 key"},
    {"VK_F21", 0x84, "F21 key"},
    {"VK_F22", 0x85, "F22 key"},
    {"VK_F23", 0x86, "F23 key"},
    {"VK_F24", 0x87, "F24 key"},
    {"RSRVD_88", 0x88, "Reserved"},
    {"RSRVD_89", 0x89, "Reserved"},
    {"RSRVD_8A", 0x8A, "Reserved"},
    {"RSRVD_8B", 0x8B, "Reserved"},
    {"RSRVD_8C", 0x8C, "Reserved"},
    {"RSRVD_8D", 0x8D, "Reserved"},
    {"RSRVD_8E", 0x8E, "Reserved"},
    {"RSRVD_8F", 0x8F, "Reserved"},
    {"VK_NUMLOCK", 0x90, "Num Lock key"},
    {"VK_SCROLL", 0x91, "Scroll Lock key"},
    {"OEM_SPCF_92", 0x92, "OEM specific"},
    {"OEM_SPCF_93", 0x93, "OEM specific"},
    {"OEM_SPCF_94", 0x94, "OEM specific"},
    {"OEM_SPCF_95", 0x95, "OEM specific"},
    {"OEM_SPCF_96", 0x96, "OEM specific"},
    {"UNSSGN_97", 0x97, "Unassigned"},
    {"UNSSGN_98", 0x98, "Unassigned"},
    {"UNSSGN_99", 0x99, "Unassigned"},
    {"UNSSGN_9A", 0x9A, "Unassigned"},
    {"UNSSGN_9B", 0x9B, "Unassigned"},
    {"UNSSGN_9C", 0x9C, "Unassigned"},
    {"UNSSGN_9D", 0x9D, "Unassigned"},
    {"UNSSGN_9E", 0x9E, "Unassigned"},
    {"UNSSGN_9F", 0x9F, "Unassigned"},
    {"VK_LSHIFT", 0xA0, "Left Shift key"},
    {"VK_RSHIFT", 0xA1, "Right Shift key"},
    {"VK_LCONTROL", 0xA2, "Left Ctrl key"},
    {"VK_RCONTROL", 0xA3, "Right Ctrl key"},
    {"VK_LMENU", 0xA4, "Left Alt key"},
    {"VK_RMENU", 0xA5, "Right Alt key"},
    {"VK_BRW_BACK", 0xA6, "Browser Back key"},
    {"VK_BRW_FRWRD", 0xA7, "Browser Forward key"},
    {"VK_BRW_RFRSH", 0xA8, "Browser Refresh key"},
    {"VK_BRW_STOP", 0xA9, "Browser Stop key"},
    {"VK_BRW_SEARCH", 0xAA, "Browser Search key"},
    {"VK_BRW_FVRTS", 0xAB, "Browser Favorites key"},
    {"VK_BRW_HOME", 0xAC, "Browser Start/Home key"},
    {"VK_VOL_MUTE", 0xAD, "Volume Mute key"},
    {"VK_VOL_DOWN", 0xAE, "Volume Down key"},
    {"VK_UP", 0xAF, "Volume Up key"},
    {"VK_MD_NEXT", 0xB0, "Next Track key"},
    {"VK_MD_PREV", 0xB1, "Previous Track key"},
    {"VK_MD_STOP", 0xB2, "Stop Media key"},
    {"VK_MD_PLAY", 0xB3, "Play/Pause Media key"},
    {"VK_MAIL", 0xB4, "Start Mail key"},
    {"VK_MSELECT", 0xB5, "Select Media key"},
    {"VK_APP1", 0xB6, "Start Application 1 key"},
    {"VK_APP2", 0xB7, "Start Application 2 key"},
    {"RSRVD_B8", 0xB8, "Reserved"},
    {"RSRVD_B9", 0xB9, "Reserved"},
    {"VK_OEM_1", 0xBA, "OEM 1 (;:) key (US keyboard)"},
    {"VK_OEM_PLS", 0xBB, "OEM Plus (+ =) key"},
    {"VK_OEM_CMM", 0xBC, "OEM Comma (< ,) key"},
    {"VK_OEM_MNS", 0xBD, "OEM Minus (_ -) key"},
    {"VK_OEM_PRD", 0xBE, "OEM Period (> .) key"},
    {"VK_OEM_2", 0xBF, "OEM 2 (/ ?) key"},
    {"VK_OEM_3", 0xC0, "OEM 3 (~ `) key"},
    {"RSRVD_C1", 0xC1, "Reserved"},
    {"RSRVD_C2", 0xC2, "Reserved"},
    {"RSRVD_C3", 0xC3, "Reserved"},
    {"RSRVD_C4", 0xC4, "Reserved"},
    {"RSRVD_C5", 0xC5, "Reserved"},
    {"RSRVD_C6", 0xC6, "Reserved"},
    {"RSRVD_C7", 0xC7, "Reserved"},
    {"RSRVD_C8", 0xC8, "Reserved"},
    {"RSRVD_C9", 0xC9, "Reserved"},
    {"RSRVD_CA", 0xCA, "Reserved"},
    {"RSRVD_CB", 0xCB, "Reserved"},
    {"RSRVD_CC", 0xCC, "Reserved"},
    {"RSRVD_CD", 0xCD, "Reserved"},
    {"RSRVD_CE", 0xCE, "Reserved"},
    {"RSRVD_CF", 0xCF, "Reserved"},
    {"RSRVD_D0", 0xD0, "Reserved"},
    {"RSRVD_D1", 0xD1, "Reserved"},
    {"RSRVD_D2", 0xD2, "Reserved"},
    {"RSRVD_D3", 0xD3, "Reserved"},
    {"RSRVD_D4", 0xD4, "Reserved"},
    {"RSRVD_D5", 0xD5, "Reserved"},
    {"RSRVD_D6", 0xD6, "Reserved"},
    {"RSRVD_D7", 0xD7, "Reserved"},
    {"UNSSGN_D8", 0xD8, "Unassigned"},
    {"UNSSGN_D9", 0xD9, "Unassigned"},
    {"UNSSGN_DA", 0xDA, "Unassigned"},
    {"VK_OEM_4", 0xDB, "OEM 4 ([ {) key"},
    {"VK_OEM_5", 0xDC, "OEM 5 (\\ |) key"},
    {"VK_OEM_6", 0xDD, "OEM 6 (] }) key"},
    {"VK_OEM_7", 0xDE, "OEM 7 (' \") key"},
    {"VK_OEM_8", 0xDF, "OEM 8 key"},
    {"RSRVD_E0", 0xE0, "Reserved"},
    {"OEM_SPCF_E1", 0xE1, "OEM specific"},
    {"VK_OEM_102", 0xE2, "OEM 102 (> <) key"},
    {"OEM_SPCF_E3", 0xE3, "OEM specific"},
    {"OEM_SPCF_E4", 0xE4, "OEM specific"},
    {"VK_PRCSSKY", 0xE5, "IME Process key"},
    {"OEM_SPCF_E6", 0xE6, "OEM specific"},
    {"VK_PACKET", 0xE7, "Packet key"},
    {"UNSSGN_E8", 0xE8, "Unassigned"},
    {"OEM_SPCF_E9", 0xE9, "OEM specific"},
    {"OEM_SPCF_EA", 0xEA, "OEM specific"},
    {"OEM_SPCF_EB", 0xEB, "OEM specific"},
    {"OEM_SPCF_EC", 0xEC, "OEM specific"},
    {"OEM_SPCF_ED", 0xED, "OEM specific"},
    {"OEM_SPCF_EE", 0xEE, "OEM specific"},
    {"OEM_SPCF_EF", 0xEF, "OEM specific"},
    {"OEM_SPCF_F0", 0xF0, "OEM specific"},
    {"OEM_SPCF_F1", 0xF1, "OEM specific"},
    {"OEM_SPCF_F2", 0xF2, "OEM specific"},
    {"OEM_SPCF_F3", 0xF3, "OEM specific"},
    {"OEM_SPCF_F4", 0xF4, "OEM specific"},
    {"OEM_SPCF_F5", 0xF5, "OEM specific"},
    {"VK_ATTN", 0xF6, "Attn key"},
    {"VK_CRSEL", 0xF7, "CrSel key"},
    {"VK_EXSEL", 0xF8, "ExSel key"},
    {"VK_EREOF", 0xF9, "Erase EOF key"},
    {"VK_PLAY", 0xFA, "Play key"},
    {"VK_ZOOM", 0xFB, "Zoom key"},
    {"VK_NONAME", 0xFC, "Reserved (VK_NONAME)"},
    {"VK_PA1", 0xFD, "PA1 key"},
    {"VK_OEM_CLEAR", 0xFE, "Clear key"},
    {"UNDEF_FF", 0xFF, "Undefined"}};

const char *KeyCodeToDebugName(short virtualKeyCode) {
  static char buf[8];
  if (virtualKeyCode >= 'A' && virtualKeyCode <= 'Z') {
    buf[0] = (char)virtualKeyCode;
    buf[1] = 0;
    return buf;
  }
  if (virtualKeyCode >= '0' && virtualKeyCode <= '9') {
    buf[0] = (char)virtualKeyCode;
    buf[1] = 0;
    return buf;
  }

  virtual_key_info_t virtualKeyDetails = vkTable[virtualKeyCode];
  return virtualKeyDetails.name;
}

INTERNAL void DebugDrawKeyboardOverlay(gdi_surface_t &surface) {
  HDC offscreenDeviceContext = surface.offscreenDeviceContext;
  if (!offscreenDeviceContext)
    return;

  SetBkMode(offscreenDeviceContext, TRANSPARENT);
  HFONT font = (HFONT)GetStockObject(ANSI_VAR_FONT);
  HFONT oldFont = (HFONT)SelectObject(offscreenDeviceContext, font);

  for (int virtualKeyCode = 0; virtualKeyCode < 256; ++virtualKeyCode) {
    int column = virtualKeyCode % 16;
    int row = virtualKeyCode / 16;
    int x = column * KEYBOARD_DEBUG_OVERLAY_CELL_WIDTH;
    int y = row * KEYBOARD_DEBUG_OVERLAY_CELL_HEIGHT;
    RECT textArea = {x, y, x + KEYBOARD_DEBUG_OVERLAY_CELL_WIDTH,
                     y + KEYBOARD_DEBUG_OVERLAY_CELL_HEIGHT};

    SHORT keyFlags = GetKeyState(virtualKeyCode);
    BOOL wasKeyDown = (keyFlags & KF_REPEAT) == KF_REPEAT;
    WORD repeatCount = LOWORD(keyFlags);
    BOOL isKeyReleased = (keyFlags & KF_UP) == KF_UP;

    COLORREF backgroundColor = RGB(50, 50, 50);
    if (wasKeyDown)
      backgroundColor = RGB(0, 120, 0);

    HBRUSH brush = CreateSolidBrush(backgroundColor);
    FillRect(offscreenDeviceContext, &textArea, brush);
    DeleteObject(brush);

    SetTextColor(offscreenDeviceContext, RGB(255, 255, 255));
    const char *label = KeyCodeToDebugName(virtualKeyCode);
    DrawTextA(offscreenDeviceContext, label, -1, &textArea,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  }

  SelectObject(offscreenDeviceContext, oldFont);
}

GLOBAL WINDOWPLACEMENT LAST_WINDOW_PLACEMENT = {};

void WindowedModeToFullscreen(HWND window, const DWORD &windowStyle) {
  MONITORINFO monitorInfo = {sizeof(monitorInfo)};

  if (!GetWindowPlacement(window, &LAST_WINDOW_PLACEMENT))
    return;
  if (!GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTOPRIMARY),
                      &monitorInfo))
    return;

  SetWindowLong(window, GWL_STYLE, windowStyle & ~WS_OVERLAPPEDWINDOW);
  SetWindowPos(window, HWND_TOP, monitorInfo.rcMonitor.left,
               monitorInfo.rcMonitor.top,
               monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left,
               monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top,
               SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
}

void FullscreenModeToWindowed(HWND window, const DWORD &windowStyle) {
  SetWindowLong(window, GWL_STYLE, windowStyle | WS_OVERLAPPEDWINDOW);
  SetWindowPlacement(window, &LAST_WINDOW_PLACEMENT);
  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                   SWP_FRAMECHANGED);
}

void WindowToggleFullscreen(HWND window) {
  DWORD windowStyle = GetWindowLong(window, GWL_STYLE);
  bool isInWindowedMode = (windowStyle & WS_OVERLAPPEDWINDOW);
  if (isInWindowedMode)
    WindowedModeToFullscreen(window, windowStyle);
  else
    FullscreenModeToWindowed(window, windowStyle);
}

LRESULT CALLBACK WindowProcessMessage(HWND window, UINT message, WPARAM wParam,
                                      LPARAM lParam) {
  LRESULT result = 0;

  switch (message) {
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

    if (!GDI_SURFACE.offscreenDeviceContext || !GDI_BACKBUFFER.activeHandle) {
      EndPaint(window, &paintInfo);
      return 0;
    }

    DebugDrawKeyboardOverlay(GDI_SURFACE);

    int srcW = GDI_BACKBUFFER.width;
    int srcH = GDI_BACKBUFFER.height;
    int destW = GDI_SURFACE.width;
    int destH = GDI_SURFACE.height;
    if (!StretchBlt(hdc, 0, 0, destW, destH, GDI_SURFACE.offscreenDeviceContext,
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

    WORD virtualKeyCode = LOWORD(wParam);
    WORD keyFlags = HIWORD(lParam);
    WORD scanCode = LOBYTE(keyFlags);
    BOOL isExtendedKey = (keyFlags & KF_EXTENDED) == KF_EXTENDED;

    if (isExtendedKey)
      scanCode = MAKEWORD(scanCode, 0xE0);

    BOOL wasKeyDown = (keyFlags & KF_REPEAT) == KF_REPEAT;
    WORD repeatCount = LOWORD(lParam);

    BOOL isKeyReleased = (keyFlags & KF_UP) == KF_UP;
    BOOL isKeyDown = !isKeyReleased;

    switch (virtualKeyCode) {
    case VK_SHIFT:
    case VK_CONTROL:
    case VK_MENU:
      // TODO Handle virtual key code mappings (maybe later)
      virtualKeyCode = LOWORD(MapVirtualKeyW(scanCode, MAPVK_VSC_TO_VK_EX));
      break;
    }

    if (wasKeyDown != isKeyDown) {
      // TODO Proper keyboard event handling (forward/queue?)
      if (virtualKeyCode == 'W') {
      } else if (virtualKeyCode == 'A') {
      } else if (virtualKeyCode == 'S') {
      } else if (virtualKeyCode == 'D') {
      } else if (virtualKeyCode == 'Q') {
      } else if (virtualKeyCode == 'E') {
      } else if (virtualKeyCode == VK_UP) {
      } else if (virtualKeyCode == VK_LEFT) {
      } else if (virtualKeyCode == VK_DOWN) {
      } else if (virtualKeyCode == VK_RIGHT) {
      } else if (virtualKeyCode == VK_ESCAPE) {
        if (wasKeyDown && !isKeyDown) {
          PostQuitMessage(0);
        }
      } else if (virtualKeyCode == VK_SPACE) {
        if (wasKeyDown && !isKeyDown) {
          WindowToggleFullscreen(window);
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

  WNDCLASSEX windowClass = {};
  // TODO Is this really a good idea? Beware the CS_OWNDC footguns...
  // TODO https://devblogs.microsoft.com/oldnewthing/20060601-06/?p=31003
  windowClass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;

  windowClass.cbSize = sizeof(windowClass);
  windowClass.lpfnWndProc = WindowProcessMessage;
  windowClass.hInstance = instance;
  windowClass.hbrBackground = (HBRUSH)COLOR_BACKGROUND;
  windowClass.lpszClassName = "RagLiteWindowClass";
  windowClass.hIcon =
      (HICON)LoadImage(instance, TEXT("DEFAULT_APP_ICON"), IMAGE_ICON,
                       GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON),
                       LR_DEFAULTCOLOR);
  windowClass.hIconSm =
      (HICON)LoadImage(instance, TEXT("DEFAULT_APP_ICON"), IMAGE_ICON,
                       GetSystemMetrics(SM_CXSMICON),
                       GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);

  if (!RegisterClassEx(&windowClass)) {
    TODO("Failed to register window class\n");
    return EXIT_FAILURE;
  }

  HWND mainWindow = CreateWindowExA(
      0, windowClass.lpszClassName, WINDOW_TITLE,
      WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_MAXIMIZE, CW_USEDEFAULT,
      CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, instance, 0);
  if (!mainWindow) {
    TODO("Failed to CreateWindowExA - Exiting...");
    return EXIT_FAILURE;
  }

  SurfaceGetWindowDimensions(GDI_SURFACE, mainWindow);
  ResizeBackBuffer(GDI_BACKBUFFER, max(1, GDI_SURFACE.width),
                   max(1, GDI_SURFACE.height), mainWindow);

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
    InvalidateRect(mainWindow, NULL, FALSE);

    ++offsetX;
    offsetY += 2;
  }

  return 0;
}
