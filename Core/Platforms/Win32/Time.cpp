typedef struct cpu_performance_metrics {
	bool isInitialized; // TODO count samples?
	FILETIME previousSystemTimesIdle;
	FILETIME previousSystemTimesKernel;
	FILETIME previousSystemTimesUser;
	FILETIME processCreationTime;
	FILETIME processExitTime; // TBD err, what?
	FILETIME processKernelTime;
	FILETIME processUserTime;
	double cpuUsageLastFrame; // TODO update once, query afterwards
} performance_metrics_t;

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
	double cpuUsage = (100.0 * (double)procTotal / (double)sysTotal);
	constexpr double EPSILON = 0.001;
	if(cpuUsage - 100.0 > EPSILON) return 100.0; // TODO clamp
	return cpuUsage;
}

double GetProcessorUsageSingleCore() {
	// TODO Calling this twice in the same frame needs to recompute (revisit later)
	// It's not exactly an accurate interpolation, but alas...
SYSTEM_INFO sysInfo;
	GetSystemInfo(&sysInfo);
 return GetProcessorUsageAllCores() * sysInfo.dwNumberOfProcessors;
}