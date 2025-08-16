GLOBAL bool APPLICATION_SHOULD_EXIT = false;
GLOBAL bool APPLICATION_SHOULD_PAUSE = false;
GLOBAL const char* WINDOW_TITLE = "RagLite2";

GLOBAL WINDOWPLACEMENT LAST_WINDOW_PLACEMENT = {};

void WindowedModeToFullscreen(HWND window, const DWORD& windowStyle) {
	MONITORINFO monitorInfo = { sizeof(monitorInfo) };

	if(!GetWindowPlacement(window, &LAST_WINDOW_PLACEMENT))
		return;
	if(!GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTOPRIMARY),
		   &monitorInfo))
		return;

	SetWindowLong(window, GWL_STYLE, windowStyle & ~WS_OVERLAPPEDWINDOW);
	SetWindowPos(window, HWND_TOP, monitorInfo.rcMonitor.left,
		monitorInfo.rcMonitor.top,
		monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left,
		monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top,
		SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
}

void FullscreenModeToWindowed(HWND window, const DWORD& windowStyle) {
	SetWindowLong(window, GWL_STYLE, windowStyle | WS_OVERLAPPEDWINDOW);
	SetWindowPlacement(window, &LAST_WINDOW_PLACEMENT);
	SetWindowPos(window, nullptr, 0, 0, 0, 0,
		SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
}

void WindowToggleFullscreen(HWND window) {
	DWORD windowStyle = GetWindowLong(window, GWL_STYLE);
	bool isInWindowedMode = (windowStyle & WS_OVERLAPPEDWINDOW);
	if(isInWindowedMode)
		WindowedModeToFullscreen(window, windowStyle);
	else
		FullscreenModeToWindowed(window, windowStyle);
}