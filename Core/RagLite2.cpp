#include "RagLite2.hpp"

#define GLOBAL static
#define INTERNAL static
#define LOCAL static

#include "Assertions.hpp"
#include "Intrinsics.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

#include "Memory.hpp"
#include "Modules.hpp"

// TODO move or remove
GLOBAL program_memory_t PLACEHOLDER_PROGRAM_MEMORY = {};
GLOBAL memory_config_t PLACEHOLDER_MEMORY_CONFIGURATION = {};

#ifdef RAGLITE_PLATFORM_NONE

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

INTERNAL void DebugDrawUpdateBackgroundPattern(world_state_t* worldState, program_input_t* inputs) {
	milliseconds updateInterval = 5.0f * MILLISECONDS_PER_SECOND;
	gdi_debug_pattern_t newPattern = (gdi_debug_pattern_t)(inputs->uptime / updateInterval);
	worldState->activeDebugDrawingPattern = (gdi_debug_pattern_t)(newPattern % PATTERN_COUNT);
}

INTERNAL void DebugDrawUseMarchingGradientPattern(offscreen_buffer_t& bitmap,
	int offsetBlue,
	int offsetGreen) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;
	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			uint8 blue = (x + offsetBlue) & 0xFF;
			uint8 green = (y + offsetGreen) & 0xFF;

			*pixel++ = ((green << 8) | blue);
		}

		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseRipplingSpiralPattern(offscreen_buffer_t& bitmap, int time,
	int) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {

			int centerX = bitmap.width / 2;
			int centerY = bitmap.height / 2;
			float dx = (float)(x - centerX);
			float dy = (float)(y - centerY);
			float dist = sqrtf(dx * dx + dy * dy);
			float wave = 0.5f + 0.5f * sinf(dist / 5.0f - time * 0.1f);

			uint8 blue = (uint8)(wave * 255);
			uint8 green = (uint8)((1.0f - wave) * 255);
			uint8 red = (uint8)((0.5f + 0.5f * sinf(time * 0.05f)) * 255);

			*pixel++ = (red << 16) | (green << 8) | blue;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseCheckeredFloorPattern(offscreen_buffer_t& bitmap, program_input_t* inputs) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	milliseconds rotationInterval = 5.0f * MILLISECONDS_PER_SECOND;
	float angle = inputs->uptime / rotationInterval;
	float cosA = cosf(angle);
	float sinA = sinf(angle);

	int cx = bitmap.width / 2;
	int cy = bitmap.height / 2;

	int squareSize = 32;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			int rx = x - cx;
			int ry = y - cy;

			float rX = rx * cosA - ry * sinA;
			float rY = rx * sinA + ry * cosA;

			int checkerX = ((int)floorf(rX / squareSize)) & 1;
			int checkerY = ((int)floorf(rY / squareSize)) & 1;

			uint8 c = (checkerX ^ checkerY) ? UINT8_MAX : 80;
			*pixel++ = (c << 16) | (c << 8) | c;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseColorGradientPattern(offscreen_buffer_t& bitmap, int,
	int) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	int cx = bitmap.width / 2;
	int cy = bitmap.height / 2;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			uint8 red = (uint8)((x * 255) / bitmap.width);
			uint8 green = (uint8)((y * 255) / bitmap.height);
			uint8 blue = 0;

			if(x == cx || y == cy) {
				red = green = blue = 255;
			}

			*pixel++ = (red << 16) | (green << 8) | blue;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawUseMovingScanlinePattern(offscreen_buffer_t& bitmap, int time,
	int) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	int gridSpacing = 32;
	int scanY = (time / 2) % bitmap.height;

	for(int y = 0; y < bitmap.height; ++y) {
		uint32* pixel = (uint32*)row;
		for(int x = 0; x < bitmap.width; ++x) {
			uint8 c = 180;

			if(x % gridSpacing == 0 || y % gridSpacing == 0)
				c = 100;

			if(y == scanY)
				c = 255;

			*pixel++ = (c << 16) | (c << 8) | c;
		}
		row += bitmap.stride;
	}
}

INTERNAL void DebugDrawIntoFrameBuffer(world_state_t* worldState, program_input_t* inputs, program_output_t* outputs) {
	offscreen_buffer_t bitmap = outputs->canvas;
	int paramA = worldState->offsetX;
	int paramB = worldState->offsetY;
	switch(worldState->activeDebugDrawingPattern) {
		case PATTERN_SHIFTING_GRADIENT:
			DebugDrawUseMarchingGradientPattern(bitmap, paramA, paramB);
			break;
		case PATTERN_CIRCULAR_RIPPLE:
			DebugDrawUseRipplingSpiralPattern(bitmap, paramA, paramB);
			break;
		case PATTERN_CHECKERBOARD:
			DebugDrawUseCheckeredFloorPattern(bitmap, inputs);
			break;
		case PATTERN_AXIS_GRADIENTS:
			DebugDrawUseColorGradientPattern(bitmap, paramA, paramB);
			break;
		case PATTERN_GRID_SCANLINE:
			DebugDrawUseMovingScanlinePattern(bitmap, paramA, paramB);
			break;
	}
}

EXPORT void SimulateNextFrame(program_memory_t* memory, program_input_t* inputs, program_output_t* outputs) {
	world_state_t* worldState = (world_state_t*)memory->persistentMemory.baseAddress;
	if(!worldState->createdTimestamp) {
		worldState->createdTimestamp = inputs->clock;
		worldState->activeDebugDrawingPattern = PATTERN_SHIFTING_GRADIENT;
	}

	worldState->offsetX++;
	worldState->offsetX++;
	worldState->offsetY++;
	// TODO update/render time needs to be fixed in the profiler?
	DebugDrawUpdateBackgroundPattern(worldState, inputs);
	DebugDrawIntoFrameBuffer(worldState, inputs, outputs);

	// NOTE: Access to the memory arena APIs should be platform-agnostic (no OS interaction required, just pointer math)
	memory->persistentMemory.used += sizeof(worldState); // Avoid overwriting the actual program state (temporary hack)
	size_t allocationSize = Megabytes(2);
	if(!SystemMemoryCanAllocate(memory->persistentMemory, 2 * allocationSize)) {
		SystemMemoryReset(memory->persistentMemory);
	} else {
		uint8* address = (uint8*)SystemMemoryAllocate(memory->persistentMemory, 2 * allocationSize);
		*address = 0xAB;
		SystemMemoryDebugTouch(memory->persistentMemory, address);
	}

	// NYI: Push draw commands to the platform's render queue
}
#else

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif

#endif