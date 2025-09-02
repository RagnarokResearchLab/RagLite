#include <intrin.h>

// TODO Eliminate this
#include <memory.h>

GLOBAL int CPU_INFO_MASK[4] = {};
GLOBAL char CPU_BRAND_STRING[0x40] = { "N/A (__cpuid intrinsic not yet supported)" };

#ifdef RAGLITE_COMPILER_MSVC

// TODO Eliminate WinAPI references here
#include "Platforms/Win32.hpp"

INTERNAL void IntrinsicsReadCPUID() {

	__cpuid(CPU_INFO_MASK, 0x80000000);
	unsigned int nExIds = CPU_INFO_MASK[0];

	if(nExIds >= 0x80000004) {
		__cpuid((int*)CPU_INFO_MASK, 0x80000002);
		memcpy(CPU_BRAND_STRING, CPU_INFO_MASK, sizeof(CPU_INFO_MASK));

		__cpuid((int*)CPU_INFO_MASK, 0x80000003);
		memcpy(CPU_BRAND_STRING + 16, CPU_INFO_MASK, sizeof(CPU_INFO_MASK));

		__cpuid((int*)CPU_INFO_MASK, 0x80000004);
		memcpy(CPU_BRAND_STRING + 32, CPU_INFO_MASK, sizeof(CPU_INFO_MASK));
	}

#define DebugMessage(message) OutputDebugStringA(message);
#define DebugTrap() __debugbreak();

#else
// TODO Support for the other toolchains
#endif
}