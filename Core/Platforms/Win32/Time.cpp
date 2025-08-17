typedef double percentage; // TBD float or double?
constexpr double EPSILON = 0.001;
GLOBAL double TARGET_FPS = 120;

// typedef struct cpu_performance_metrics {
// 	bool isInitialized; // TODO count samples?
// 	bool wasUpdatedThisFrame; // TODO use system utime
// 	// TODO update these also, or remove them? Not sure if useful in practice...
// 	FILETIME previousSystemTimesIdle;
// 	FILETIME previousSystemTimesKernel;
// 	FILETIME previousSystemTimesUser;
// 	FILETIME processCreationTime;
// 	FILETIME processExitTime; // TBD err, what?
// 	FILETIME processKernelTime;
// 	FILETIME processUserTime;
// 	percentage processorUsageAllCores; // TODO update once, query afterwards
// 	percentage processorUsageSingleCore;
// } performance_metrics_t;

typedef struct performance_metrics_t {
	bool isInitialized;
	bool wasUpdatedThisFrame;

	// CPU
	FILETIME prevSysKernel;
	FILETIME prevSysUser;
	FILETIME prevProcKernel;
	FILETIME prevProcUser;
	percentage processorUsageAllCores;
	percentage processorUsageSingleCore;

	// Frame timing
	LARGE_INTEGER prevCounter;
	double deltaTimeMs;
	double smoothedDeltaTimeMs;
	double fps;
	double smoothedFps;

	// Sleep accuracy
	double requestedSleepMs;
	double actualSleepMs;

	// Even though this info won't change, store it here for cache locality
	SYSTEM_INFO hardwareSystemInfo;

} performance_metrics_t;

GLOBAL performance_metrics_t CPU_PERFORMANCE_METRICS = {};

double GetProcessorUsageAllCores() {
	static FILETIME prevSysKernel, prevSysUser; // TODO store GLOBAL in perf struct (same as perf counter)
	static FILETIME prevProcKernel, prevProcUser;
	static bool firstCall = true;

	FILETIME sysIdle, sysKernel, sysUser;
	FILETIME procCreation, procExit, procKernel, procUser;

	if(!GetSystemTimes(&sysIdle, &sysKernel, &sysUser))
		return 0.0;

	if(!GetProcessTimes(GetCurrentProcess(), &procCreation, &procExit, &procKernel, &procUser))
		return 0.0;

	if(firstCall) {
		prevSysKernel = sysKernel;
		prevSysUser = sysUser;
		prevProcKernel = procKernel;
		prevProcUser = procUser;
		firstCall = false;
		return 0.0; // Need at least two samples to measure
	}

	ULONGLONG sysKernelDiff = (((ULONGLONG)sysKernel.dwHighDateTime << 32) | sysKernel.dwLowDateTime) - (((ULONGLONG)prevSysKernel.dwHighDateTime << 32) | prevSysKernel.dwLowDateTime);
	ULONGLONG sysUserDiff = (((ULONGLONG)sysUser.dwHighDateTime << 32) | sysUser.dwLowDateTime) - (((ULONGLONG)prevSysUser.dwHighDateTime << 32) | prevSysUser.dwLowDateTime);

	ULONGLONG procKernelDiff = (((ULONGLONG)procKernel.dwHighDateTime << 32) | procKernel.dwLowDateTime) - (((ULONGLONG)prevProcKernel.dwHighDateTime << 32) | prevProcKernel.dwLowDateTime);
	ULONGLONG procUserDiff = (((ULONGLONG)procUser.dwHighDateTime << 32) | procUser.dwLowDateTime) - (((ULONGLONG)prevProcUser.dwHighDateTime << 32) | prevProcUser.dwLowDateTime);

	prevSysKernel = sysKernel;
	prevSysUser = sysUser;
	prevProcKernel = procKernel;
	prevProcUser = procUser;

	ULONGLONG sysTotal = sysKernelDiff + sysUserDiff;
	ULONGLONG procTotal = procKernelDiff + procUserDiff;

	if(sysTotal == 0)
		return 0.0;

	// denominator = (global_kernel_time - old_global_kernel_time) + (global_user_time - old_global_user_time)
	// ((kernel_time - old_kernel_time) + (user_time - old_user_time)) / denominator * 100
	return (double)procTotal / (double)sysTotal;
}

// double GetProcessorUsageSingleCore() {
// 	// TODO Calling this twice in the same frame needs to recompute (revisit later)
// 	// It's not exactly an accurate interpolation, but alas...

// }

inline int Percent(double percentage) {
	if(percentage - 1.0 > EPSILON) return 100;
	if(percentage < EPSILON) return 0;
	percentage *= 100.0;
	return (int)percentage;
}

int FloatToString(char* buffer, double value, int decimals) {
	if(value < 0) {
		*buffer++ = '-';
		value = -value;
	}

	ULONGLONG intPart = (ULONGLONG)value;
	double frac = value - (double)intPart;

	char temp[32];
	int intLen = 0;
	do {
		temp[intLen++] = '0' + (int)(intPart % 10);
		intPart /= 10;
	} while(intPart > 0);

	for(int i = intLen - 1; i >= 0; --i) {
		*buffer++ = temp[i];
	}

	if(decimals > 0) {
		*buffer++ = '.';
		for(int d = 0; d < decimals; d++) {
			frac *= 10.0;
			int digit = (int)frac;
			*buffer++ = '0' + digit;
			frac -= digit;
		}
	}

	*buffer = '\0';
	return (int)(buffer - temp);
}

void PerformanceMetricsUpdateNow() {
	LARGE_INTEGER freq, now;
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&now);

	if(!CPU_PERFORMANCE_METRICS.isInitialized) {
		CPU_PERFORMANCE_METRICS.prevCounter = now;
		CPU_PERFORMANCE_METRICS.isInitialized = true;
		return;
	}

	// --- Frame time
	LONGLONG counterDiff = now.QuadPart - CPU_PERFORMANCE_METRICS.prevCounter.QuadPart;
	CPU_PERFORMANCE_METRICS.prevCounter = now;
	double deltaMs = (1000.0 * (double)counterDiff) / (double)freq.QuadPart;
	CPU_PERFORMANCE_METRICS.deltaTimeMs = deltaMs;

	// Smooth with exponential moving average
	CPU_PERFORMANCE_METRICS.smoothedDeltaTimeMs = CPU_PERFORMANCE_METRICS.smoothedDeltaTimeMs * 0.9 + deltaMs * 0.1;

	CPU_PERFORMANCE_METRICS.fps = (deltaMs > 0.0) ? (1000.0 / deltaMs) : 0.0;
	CPU_PERFORMANCE_METRICS.smoothedFps = CPU_PERFORMANCE_METRICS.smoothedFps * 0.9 + CPU_PERFORMANCE_METRICS.fps * 0.1;

	// --- CPU usage (same as before)
	CPU_PERFORMANCE_METRICS.processorUsageAllCores = GetProcessorUsageAllCores();
	SYSTEM_INFO sysInfo;
	GetSystemInfo(&sysInfo);
	CPU_PERFORMANCE_METRICS.processorUsageSingleCore = CPU_PERFORMANCE_METRICS.processorUsageAllCores * sysInfo.dwNumberOfProcessors;

	// --- Sleep measurement
	double req = 1000.0 / TARGET_FPS;
	LARGE_INTEGER beforeSleep, afterSleep;
	QueryPerformanceCounter(&beforeSleep);
	Sleep((DWORD)req); // later replace with high-accuracy sleep
	QueryPerformanceCounter(&afterSleep);
	double actualMs = (1000.0 * (afterSleep.QuadPart - beforeSleep.QuadPart)) / (double)freq.QuadPart;

	CPU_PERFORMANCE_METRICS.requestedSleepMs = req;
	CPU_PERFORMANCE_METRICS.actualSleepMs = actualMs;

	// TODO Check if this makes any difference (unlikely); if so, write only once and skip this part
	CPU_PERFORMANCE_METRICS.hardwareSystemInfo = sysInfo;

	// TODO remove?
	CPU_PERFORMANCE_METRICS.wasUpdatedThisFrame = true;
}
