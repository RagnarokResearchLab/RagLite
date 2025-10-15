#include "RagLite2.hpp"

#define GLOBAL static
#define INTERNAL static
#define LOCAL static

#include "Assertions.hpp"
#include "Intrinsics.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

typedef struct offscreen_bitmap {
	int width;
	int height;
	int bytesPerPixel;
	int stride;
	void* pixelBuffer;
} offscreen_buffer_t;

#ifdef RAGLITE_DEFAULT_APP
#include TOSTRING(RAGLITE_DEFAULT_APP.cpp)
#endif

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif