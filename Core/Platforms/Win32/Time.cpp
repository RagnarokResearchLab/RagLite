double GetProcessorUsage() {
	static FILETIME prevSysKernel, prevSysUser;
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

	SYSTEM_INFO sysInfo;
	GetSystemInfo(&sysInfo);

	double cpuUsage = (100.0 * (double)procTotal / (double)sysTotal) * sysInfo.dwNumberOfProcessors;
	constexpr double EPSILON = 0.001;
	if(cpuUsage - 100.0 > EPSILON) return 100.0; // TODO clamp
	return cpuUsage;
}
