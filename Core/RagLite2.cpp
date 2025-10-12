#include "RagLite2.hpp"

#define GLOBAL static
#define INTERNAL static
#define LOCAL static

#include "Assertions.hpp"
#include "Intrinsics.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

#include "Memory.hpp"

GLOBAL program_memory_t PLACEHOLDER_PROGRAM_MEMORY = {};
GLOBAL memory_config_t PLACEHOLDER_MEMORY_CONFIGURATION = {};

typedef struct volatile_world_state {
	int32 offsetX;
	int32 offsetY;
} world_state_t;

GLOBAL world_state_t PLACEHOLDER_WORLD_STATE = {};

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif