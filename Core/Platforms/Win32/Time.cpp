typedef struct system_performance_metrics {
	bool isInitialized;

	FILETIME prevSysKernel;
	FILETIME prevSysUser;
	FILETIME prevProcKernel;
	FILETIME prevProcUser;
	percentage processorUsageAllCores;
	percentage processorUsageSingleCore;

	LARGE_INTEGER prevCounter;
	milliseconds deltaTime;
	milliseconds smoothedDeltaTime;
	FPS frameRate;
	FPS smoothedFrameRate;

	milliseconds desiredSleepTime;
	milliseconds observedSleepTime;

	// Even though this info won't change, store it here for cache locality
	SYSTEM_INFO hardwareSystemInfo;

} performance_metrics_t;

GLOBAL performance_metrics_t CPU_PERFORMANCE_METRICS = {};

double GetProcessorUsageAllCores() {
	FILETIME sysIdle, sysKernel, sysUser;
	FILETIME procCreation, procExit, procKernel, procUser;

	if(!GetSystemTimes(&sysIdle, &sysKernel, &sysUser))
		return 0.0;

	if(!GetProcessTimes(GetCurrentProcess(), &procCreation, &procExit, &procKernel, &procUser))
		return 0.0;

	if(!CPU_PERFORMANCE_METRICS.isInitialized) {
		CPU_PERFORMANCE_METRICS.prevSysKernel = sysKernel;
		CPU_PERFORMANCE_METRICS.prevSysUser = sysUser;
		CPU_PERFORMANCE_METRICS.prevProcKernel = procKernel;
		CPU_PERFORMANCE_METRICS.prevProcUser = procUser;
		CPU_PERFORMANCE_METRICS.isInitialized = true;
		return 0.0; // Need at least two samples to measure
	}

	ULONGLONG sysKernelDiff = (((ULONGLONG)sysKernel.dwHighDateTime << 32) | sysKernel.dwLowDateTime) - (((ULONGLONG)CPU_PERFORMANCE_METRICS.prevSysKernel.dwHighDateTime << 32) | CPU_PERFORMANCE_METRICS.prevSysKernel.dwLowDateTime);
	ULONGLONG sysUserDiff = (((ULONGLONG)sysUser.dwHighDateTime << 32) | sysUser.dwLowDateTime) - (((ULONGLONG)CPU_PERFORMANCE_METRICS.prevSysUser.dwHighDateTime << 32) | CPU_PERFORMANCE_METRICS.prevSysUser.dwLowDateTime);

	ULONGLONG procKernelDiff = (((ULONGLONG)procKernel.dwHighDateTime << 32) | procKernel.dwLowDateTime) - (((ULONGLONG)CPU_PERFORMANCE_METRICS.prevProcKernel.dwHighDateTime << 32) | CPU_PERFORMANCE_METRICS.prevProcKernel.dwLowDateTime);
	ULONGLONG procUserDiff = (((ULONGLONG)procUser.dwHighDateTime << 32) | procUser.dwLowDateTime) - (((ULONGLONG)CPU_PERFORMANCE_METRICS.prevProcUser.dwHighDateTime << 32) | CPU_PERFORMANCE_METRICS.prevProcUser.dwLowDateTime);

	CPU_PERFORMANCE_METRICS.prevSysKernel = sysKernel;
	CPU_PERFORMANCE_METRICS.prevSysUser = sysUser;
	CPU_PERFORMANCE_METRICS.prevProcKernel = procKernel;
	CPU_PERFORMANCE_METRICS.prevProcUser = procUser;

	ULONGLONG sysTotal = sysKernelDiff + sysUserDiff;
	ULONGLONG procTotal = procKernelDiff + procUserDiff;

	if(sysTotal == 0)
		return 0.0;

	return (double)procTotal / (double)sysTotal;
}

void PerformanceMetricsUpdateNow() {
	LARGE_INTEGER ticksPerSecond, tickTimeNow;
	QueryPerformanceFrequency(&ticksPerSecond);
	QueryPerformanceCounter(&tickTimeNow);

	if(!CPU_PERFORMANCE_METRICS.isInitialized) {
		CPU_PERFORMANCE_METRICS.prevCounter = tickTimeNow;
		CPU_PERFORMANCE_METRICS.isInitialized = true;
		return;
	}

	// Frame times
	LONGLONG counterDiff = tickTimeNow.QuadPart - CPU_PERFORMANCE_METRICS.prevCounter.QuadPart;
	CPU_PERFORMANCE_METRICS.prevCounter = tickTimeNow;
	milliseconds deltaTime = (MILLISECONDS_PER_SECOND * (double)counterDiff) / (double)ticksPerSecond.QuadPart;
	CPU_PERFORMANCE_METRICS.deltaTime = deltaTime;

	// Smooth out jitter with a basic exponential moving average
	CPU_PERFORMANCE_METRICS.smoothedDeltaTime = CPU_PERFORMANCE_METRICS.smoothedDeltaTime * 0.9 + deltaTime * 0.1;

	CPU_PERFORMANCE_METRICS.frameRate = (deltaTime > 0.0) ? (MILLISECONDS_PER_SECOND / deltaTime) : 0.0;
	CPU_PERFORMANCE_METRICS.smoothedFrameRate = CPU_PERFORMANCE_METRICS.smoothedFrameRate * 0.9 + CPU_PERFORMANCE_METRICS.frameRate * 0.1;

	// CPU usage
	CPU_PERFORMANCE_METRICS.processorUsageAllCores = GetProcessorUsageAllCores();
	SYSTEM_INFO sysInfo;
	GetSystemInfo(&sysInfo);
	CPU_PERFORMANCE_METRICS.processorUsageSingleCore = CPU_PERFORMANCE_METRICS.processorUsageAllCores * sysInfo.dwNumberOfProcessors;

	// Sleep timings
	double desiredSleepTime = MILLISECONDS_PER_SECOND / TARGET_FRAME_RATE;
	LARGE_INTEGER beforeSleep, afterSleep;
	QueryPerformanceCounter(&beforeSleep);
	Sleep((DWORD)desiredSleepTime);
	QueryPerformanceCounter(&afterSleep);
	double observedSleepTime = (MILLISECONDS_PER_SECOND * (afterSleep.QuadPart - beforeSleep.QuadPart)) / (double)ticksPerSecond.QuadPart;

	CPU_PERFORMANCE_METRICS.desiredSleepTime = desiredSleepTime;
	CPU_PERFORMANCE_METRICS.observedSleepTime = observedSleepTime;

	CPU_PERFORMANCE_METRICS.hardwareSystemInfo = sysInfo;
}
