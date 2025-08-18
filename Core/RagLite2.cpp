#include "RagLite2.hpp"

#define GLOBAL static
#define INTERNAL static

// TODO eliminate this include?
#include <cassert>

// Silence [-Wunused-value] compiler warnings by adding (void)
#ifdef NDEBUG
#define ASSUME(condition, message) ((void)0)
#else
#define ASSUME(condition, failureMessage) assert((void(failureMessage), condition))
#endif

#include "Intrinsics.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif