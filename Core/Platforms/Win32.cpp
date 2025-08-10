#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define GLOBAL static;
#define INTERNAL static;
#define TODO(msg) OutputDebugStringA(msg);

GLOBAL BITMAPINFO bitmapInfo;
GLOBAL void *bitmapBuffer;
GLOBAL HBITMAP bitmap;
GLOBAL HDC bitmapDeviceContext;

GLOBAL bool APPLICATION_SHOULD_EXIT = false;
GLOBAL const char *WINDOW_TITLE = "RagLite2 - Win32/GDI";

INTERNAL void ResizeBackBuffer(int width, int height) {
  if (bitmap) {
    DeleteObject(bitmap);
  }

  if (!bitmapDeviceContext) {
    bitmapDeviceContext = CreateCompatibleDC(0);
  }

  bitmapInfo.bmiHeader.biSize = sizeof(bitmapInfo.bmiHeader);
  bitmapInfo.bmiHeader.biWidth = width;
  bitmapInfo.bmiHeader.biHeight = height;
  bitmapInfo.bmiHeader.biPlanes = 1;
  bitmapInfo.bmiHeader.biBitCount = 32;
  bitmapInfo.bmiHeader.biCompression = BI_RGB;

  bitmap = CreateDIBSection(bitmapDeviceContext, &bitmapInfo, DIB_RGB_COLORS,
                            &bitmapBuffer, 0, 0);
}

INTERNAL void OnUpdate(HDC displayDeviceContext, int x, int y, int width,
                       int height) {
  StretchDIBits(displayDeviceContext, x, y, width, height, x, y, width, height,
                bitmapBuffer, &bitmapInfo, DIB_RGB_COLORS, SRCCOPY);
}

LRESULT CALLBACK OnMessage(HWND window, auto message, auto argW, auto argL) {
  LRESULT result = 0;

  switch (message) {
  case WM_SIZE: {
    RECT clientRec;
    GetClientRect(window, &clientRec);
    int width = clientRec.right - clientRec.left;
    int height = clientRec.bottom - clientRec.top;
    ResizeBackBuffer(width, height);
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
    OnUpdate(displayDeviceContext, x, y, width, height);
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
      MSG message;
      constexpr HWND WINDOW_AND_THREAD = NULL;
      constexpr auto MINMAX_FILTER_NONE = NULL;
      while (!APPLICATION_SHOULD_EXIT) {
        BOOL result = GetMessageA(&message, WINDOW_AND_THREAD,
                                  MINMAX_FILTER_NONE, MINMAX_FILTER_NONE);
        if (result > 0) {
          TranslateMessage(&message);
          DispatchMessageA(&message);
        } else if (result < 0) {
          TODO("Unexpected error in main loop - Exiting...");
          break;
        } else {
          TODO("Received WM_QUIT - Exiting...");
          break;
        }
      }
    } else {
      TODO("Failed to CreateWindowExA - Exiting...");
    }
  } else {
    TODO("Failed to RegisterClassEx - Exiting...");
  }

  return 0;
}
