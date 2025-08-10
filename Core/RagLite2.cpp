#include "RagLite2.hpp"

#include <stdint.h>
typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif