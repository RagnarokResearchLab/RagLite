#include "RagLite2.hpp"

#define GLOBAL static
#define INTERNAL static
#define LOCAL static

#include "Assertions.hpp"
#include "Intrinsics.hpp"
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

GLOBAL simulation_state_t PLACEHOLDER_DEMO_APP = {};

GLOBAL memory_arena_t MAIN_MEMORY = {};
GLOBAL memory_arena_t TRANSIENT_MEMORY = {};

#ifdef RAGLITE_DEFAULT_APP
#include TOSTRING(RAGLITE_DEFAULT_APP.cpp)
#endif

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif