#pragma once

#ifdef _WIN32
	#define RAGLITE_PLATFORM_WINDOWS
#elifdef __APPLE__
	#define RAGLITE_PLATFORM_MACOS
#elifdef __linux__
	#define RAGLITE_PLATFORM_LINUX
#else
	#define RAGLITE_UNSUPPORTED_PLATFORM
#endif

#ifdef RAGLITE_UNSUPPORTED_PLATFORM
	#error "Unsupported Platform: OS-specific code paths have yet to be ported"
#endif

static_assert(sizeof(void*) == 8, "Only 64-bit platforms are currently supported");

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    #error "Only Little-Endian platforms are currently supported"
#endif