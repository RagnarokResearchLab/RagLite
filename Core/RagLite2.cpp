#include "RagLite2.hpp"

// Numerics (TODO Move elsewhere later)
#include <stdint.h>
typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

inline uint32 Kilobytes(uint32 bytes) {
	return bytes / 1024;
}

inline uint32 Megabytes(uint32 bytes) {
	return Kilobytes(bytes) / 1024;
}

inline uint32 Gigabytes(uint32 bytes) {
	return Megabytes(bytes) / 1024;
}

inline uint32 Terabytes(uint32 bytes) {
	return Gigabytes(bytes) / 1024;
}

typedef float percentage;
constexpr float EPSILON = 0.001;

inline int Percent(double percentage) {
	if(percentage - 1.0 > EPSILON) return 100;
	if(percentage < EPSILON) return 0;
	percentage *= 100.0;
	return (int)percentage;
}

// Macros (TODO Add assertions/ASSUME etc.)

#define GLOBAL static
#define INTERNAL static

GLOBAL float TARGET_FPS = 120;

// Intrinsicts (TODO Move elsewhere later)
#include <intrin.h>
#include <memory.h>

// TODO Does that work on GCC? Move to platform defines.
// TODO intrinsics -> not here
GLOBAL int CPU_INFO_MASK[4] = {};
GLOBAL char CPU_BRAND_STRING[0x40] = { "N/A: Intrinsic __cpuid not emitted)" };

#ifdef RAGLITE_COMPILER_MSVC
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
#else

#endif
}

// String utilities (TODO Move elsewhere later)
INTERNAL int FloatToString(char* buffer, float value, int decimals) {
	if(value < 0) {
		*buffer++ = '-';
		value = -value;
	}

	uint32 intPart = (uint32)value;
	float frac = value - (float)intPart;

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

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif