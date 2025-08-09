#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
	MessageBoxA(0, "Hello world", "RagLite2", MB_OK | MB_ICONINFORMATION);
}
