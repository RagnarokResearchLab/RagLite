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


static_assert(sizeof(void*) == 8, "Only 64-bit platforms are currently supported");

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#error "Only Little-Endian platforms are currently supported"
#endif