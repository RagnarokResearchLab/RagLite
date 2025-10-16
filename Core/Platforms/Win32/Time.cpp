typedef uint64 hardware_tick_t;

typedef struct system_performance_metrics {
	FILETIME prevSysKernel;
	FILETIME prevSysUser;
	FILETIME prevProcKernel;
	FILETIME prevProcUser;

	milliseconds applicationUptime;
	milliseconds frameTime;
	milliseconds messageProcessingTime;
	milliseconds sleepTime;
	milliseconds suspendedTime;
	milliseconds userInterfaceRenderTime;
	milliseconds simulationStepTime;
	milliseconds worldRenderTime;
} performance_metrics_t;

typedef struct system_performance_info {
	milliseconds applicationLaunchTime;
	DWORD pageSize;
	DWORD allocationGranularity;
	DWORD numberOfProcessors;
	WORD processorArchitecture;
} performance_info_t;

constexpr uint32 PERFORMANCE_HISTORY_SECONDS = 10;
constexpr uint32 PERFORMANCE_HISTORY_SIZE = 256 * ((uint32)(TARGET_FRAME_RATE * PERFORMANCE_HISTORY_SECONDS) / 256);
typedef struct performance_history_cache {
	performance_metrics_t recordedSamples[PERFORMANCE_HISTORY_SIZE];
	milliseconds highestObservedFrameTime;
	uint32 oldestRecordedSampleIndex;
} performance_history_t;

GLOBAL hardware_tick_t MONOTONIC_CLOCK_SPEED = {};
GLOBAL performance_metrics_t CPU_PERFORMANCE_METRICS = {};
GLOBAL performance_info_t CPU_PERFORMANCE_INFO = {};
GLOBAL performance_history_t PERFORMANCE_METRICS_HISTORY = {};

INTERNAL inline uint64 FileTimeToUnsigned64(FILETIME& fileTime) {
	ULARGE_INTEGER converted;

	converted.LowPart = fileTime.dwLowDateTime;
	converted.HighPart = fileTime.dwHighDateTime;

	return converted.QuadPart;
}

INTERNAL percentage GetProcessorUsageAllCores() {
	FILETIME sysIdle, sysKernel, sysUser;
	FILETIME procCreation, procExit, procKernel, procUser;

	if(!GetSystemTimes(&sysIdle, &sysKernel, &sysUser))
		return 0.0;

	if(!GetProcessTimes(GetCurrentProcess(), &procCreation, &procExit, &procKernel, &procUser))
		return 0.0;

	int64 sysKernelDiff = FileTimeToUnsigned64(sysKernel) - FileTimeToUnsigned64(CPU_PERFORMANCE_METRICS.prevSysKernel);
	int64 sysUserDiff = FileTimeToUnsigned64(sysUser) - FileTimeToUnsigned64(CPU_PERFORMANCE_METRICS.prevSysUser);
	int64 procKernelDiff = FileTimeToUnsigned64(procKernel) - FileTimeToUnsigned64(CPU_PERFORMANCE_METRICS.prevProcKernel);
	int64 procUserDiff = FileTimeToUnsigned64(procUser) - FileTimeToUnsigned64(CPU_PERFORMANCE_METRICS.prevProcUser);

	CPU_PERFORMANCE_METRICS.prevSysKernel = sysKernel;
	CPU_PERFORMANCE_METRICS.prevSysUser = sysUser;
	CPU_PERFORMANCE_METRICS.prevProcKernel = procKernel;
	CPU_PERFORMANCE_METRICS.prevProcUser = procUser;

	int64 sysTotal = sysKernelDiff + sysUserDiff;
	int64 procTotal = procKernelDiff + procUserDiff;

	if(sysTotal == 0)
		return 0.0;

	return (percentage)procTotal / (percentage)sysTotal;
}

INTERNAL inline hardware_tick_t PerformanceMetricsNow() {
	LARGE_INTEGER highResolutionTimestamp;
	QueryPerformanceCounter(&highResolutionTimestamp);
	return (hardware_tick_t)highResolutionTimestamp.QuadPart;
}

INTERNAL inline seconds PerformanceMetricsElapsedSeconds(hardware_tick_t before) {
	hardware_tick_t after = PerformanceMetricsNow();
	seconds elapsed = (seconds)(after - before);
	return elapsed / (seconds)MONOTONIC_CLOCK_SPEED;
}

INTERNAL inline milliseconds PerformanceMetricsGetTimeSince(hardware_tick_t before) {
	return PerformanceMetricsElapsedSeconds(before) * MILLISECONDS_PER_SECOND;
}

INTERNAL inline void PerformanceMetricsRecordSample(performance_metrics_t metrics, performance_history_t& history) {
	history.recordedSamples[history.oldestRecordedSampleIndex] = metrics;

	if(history.oldestRecordedSampleIndex == 0) {
		history.highestObservedFrameTime = 0;
		line_drawing_style_t newLineDrawingMethod = (line_drawing_style_t)(SELECTED_LINE_DRAWING_METHOD + 1);
		SELECTED_LINE_DRAWING_METHOD = (line_drawing_style_t)(newLineDrawingMethod % LINE_STYLE_COUNT);
	}
	history.highestObservedFrameTime = Max(history.highestObservedFrameTime, metrics.frameTime);

	history.oldestRecordedSampleIndex = (history.oldestRecordedSampleIndex + 1) % PERFORMANCE_HISTORY_SIZE;
}