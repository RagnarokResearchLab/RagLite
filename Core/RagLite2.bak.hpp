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

#define RAGLITE_COMPILER_GCC 0
#define RAGLITE_COMPILER_LLVM 0
#define RAGLITE_COMPILER_MSVC 0

#ifdef _MSC_VER
#undef RAGLITE_COMPILER_MSVC
#define RAGLITE_COMPILER_MSVC 1
#define EXPORT extern "C" __declspec(dllexport)
#else
#define RAGLITE_UNSUPPORTED_COMPILER
#endif

#ifdef RAGLITE_UNSUPPORTED_COMPILER
#error "Unsupported Compiler: Toolchain-specific code paths have yet to be ported"
#endif

#ifdef NDEBUG
#define RAGLITE_INCLUDE_PROGRAM "PatternTestGDI.cpp"
#else
#define RAGLITE_DEBUG_ASSERTIONS
#define RAGLITE_HOT_RELOAD
#define RAGLITE_PREDICTABLE_MEMORY
#endif

constexpr size_t BITS_PER_BYTE = 8ULL;
#define Bits(bits) ((bits) / BITS_PER_BYTE)

constexpr size_t PLATFORM_POINTER_SIZE = sizeof(void*);
static_assert(PLATFORM_POINTER_SIZE == Bits(64), "Only 64-bit platforms are currently supported");

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#error "Only Little-Endian platforms are currently supported"
#endif

#ifndef RAGLITE_PERSISTENT_MEMORY
#define RAGLITE_PERSISTENT_MEMORY Megabytes(85)
#endif

#ifndef RAGLITE_TRANSIENT_MEMORY
#define RAGLITE_TRANSIENT_MEMORY Megabytes(1596) + Kilobytes(896)
#endif

#define GLOBAL static
#define INTERNAL static
#define LOCAL static

#include "Assertions.hpp"
#include "Intrinsics.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

#include "GamePad.hpp"
#include "Memory.hpp"
#include "Modules.hpp"

// TODO move or remove
GLOBAL program_memory_t PLACEHOLDER_PROGRAM_MEMORY = {};
GLOBAL memory_config_t PLACEHOLDER_MEMORY_CONFIGURATION = {};

// TODO Eliminate this
#include <math.h>

typedef enum : uint8 {
	PATTERN_SHIFTING_GRADIENT,
	PATTERN_CIRCULAR_RIPPLE,
	PATTERN_CHECKERBOARD,
	PATTERN_AXIS_GRADIENTS,
	PATTERN_GRID_SCANLINE,
	PATTERN_COUNT
} gdi_debug_pattern_t;

typedef struct volatile_world_state {
	uint64 createdTimestamp;
	int32 offsetX;
	int32 offsetY;
	gdi_debug_pattern_t activeDebugDrawingPattern;
} world_state_t;