#pragma once

#ifndef RAGLITE_COMMIT_HASH
#define RAGLITE_COMMIT_HASH "N/A"
#endif

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

// NOTE: Should probably use feature detection macros, but for now assume the latest (tested) version will work
#if defined(__clang__)
#define RAGLITE_COMPILER_CLANG
#elif defined(_MSC_VER)
#define RAGLITE_COMPILER_MSVC
#elif defined(__GNUC__)
#define RAGLITE_COMPILER_GCC 1
#else
#define RAGLITE_UNSUPPORTED_COMPILER
#endif

#ifdef RAGLITE_UNSUPPORTED_COMPILER
#error "Unsupported Compiler: Toolchain-specific code paths have yet to be ported"
#endif

#ifdef NDEBUG
#define RAGLITE_DEFAULT_APP DummyTest
#else
#define RAGLITE_DEBUG_ANNOTATIONS
#define RAGLITE_DEBUG_ASSERTIONS
#define RAGLITE_DEFAULT_APP PatternTest
#define RAGLITE_PREDICTABLE_MEMORY
#endif

#define EXPAND_AS_STRING(x) #x
#define TOSTRING(x) EXPAND_AS_STRING(x)

constexpr int BITS_PER_BYTE = 8;
#define Bits(bits) ((bits) / BITS_PER_BYTE)

constexpr int PLATFORM_POINTER_SIZE = sizeof(void*);
static_assert(PLATFORM_POINTER_SIZE == Bits(64), "Only 64-bit platforms are currently supported");

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#error "Only Little-Endian platforms are currently supported"
#endif

#define GLOBAL static
#define INTERNAL static
#define LOCAL static

#include "Assertions.hpp"
#include "Intrinsics.hpp"
#include "Math.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

#include "Memory.hpp"

typedef struct offscreen_bitmap {
	int width;
	int height;
	int bytesPerPixel;
	int stride;
	void* pixelBuffer;
} offscreen_buffer_t;

typedef struct gamepad_controller_state {
	int16 stickX;
	int16 stickY;
} gamepad_state_t;

typedef struct volatile_simulation_state {
	int32 offsetX;
	int32 offsetY;
} simulation_state_t;

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.hpp"
#elifdef RAGLITE_PLATFORM_MACOS
#include "Platforms/MacOS.hpp"
#elifdef RAGLITE_PLATFORM_LINUX
#include "Platforms/Linux.hpp"
#endif
