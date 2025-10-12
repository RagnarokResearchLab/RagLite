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
#else
#define RAGLITE_UNSUPPORTED_COMPILER
#endif

#ifdef RAGLITE_UNSUPPORTED_COMPILER
#error "Unsupported Compiler: Toolchain-specific code paths have yet to be ported"
#endif

#ifdef NDEBUG
// TODO: Add feature flags for release builds here
#else
#define RAGLITE_DEBUG_ASSERTIONS
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