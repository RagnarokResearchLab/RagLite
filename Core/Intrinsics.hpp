// TODO Eliminate this
#include <memory.h>

GLOBAL int CPU_INFO_MASK[4] = {};
GLOBAL char CPU_BRAND_STRING[0x40] = { "N/A (__cpuid intrinsic not yet supported)" };

#ifdef RAGLITE_COMPILER_MSVC

#include <intrin.h>

// TODO: Should look into whether (and how much) dllimport improves performance?
#define EXPORT extern "C" __declspec(dllexport)

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
}

#define DebugTrap() __debugbreak();

#else

#include <cpuid.h>

// TODO: Only relevant if the build script (that doesn't currently exist) uses -fvisibility=hidden
#define EXPORT extern "C" __attribute__((visibility("default")))

INTERNAL void IntrinsicsReadCPUID() {
	// NYI: Probably need to rewrite this anyway, so for now just leave it as a placeholder
}

#define DebugTrap() __builtin_trap();

#endif

// TODO: typeof(x) could simplify this - look into toolchain support/extensions?
#define Swap(first, second, type) \
	do {                          \
		type temp = first;        \
		first = second;           \
		second = temp;            \
	} while(0)
