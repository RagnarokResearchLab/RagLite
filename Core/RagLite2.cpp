#include "RagLite2.hpp"

GLOBAL simulation_state_t PLACEHOLDER_DEMO_APP = {};

GLOBAL memory_arena_t MAIN_MEMORY = {};
GLOBAL memory_arena_t TRANSIENT_MEMORY = {};

#ifdef RAGLITE_DEFAULT_APP
#include TOSTRING(RAGLITE_DEFAULT_APP.cpp)
#endif

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif