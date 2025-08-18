#include "RagLite2.hpp"

#define GLOBAL static
#define INTERNAL static

#include "Intrinsics.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif