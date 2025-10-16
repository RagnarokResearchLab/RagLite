#include "RagLite2.hpp"

typedef enum : uint8 {
	PATTERN_SHIFTING_GRADIENT,
	PATTERN_CIRCULAR_RIPPLE,
	PATTERN_CHECKERBOARD,
	PATTERN_AXIS_GRADIENTS,
	PATTERN_GRID_SCANLINE,
	PATTERN_COUNT
} animated_debug_pattern_t;

GLOBAL animated_debug_pattern_t ANIMATED_DEBUG_PATTERN = PATTERN_SHIFTING_GRADIENT;

INTERNAL void DebugDrawUpdateBackgroundPattern(milliseconds uptime) {
	seconds updateInterval = 5.0f;
	seconds elapsed = uptime / MILLISECONDS_PER_SECOND;
	animated_debug_pattern_t newPattern = (animated_debug_pattern_t)(elapsed / updateInterval);
	ANIMATED_DEBUG_PATTERN = (animated_debug_pattern_t)(newPattern % PATTERN_COUNT);
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

INTERNAL void DebugDrawUseCheckeredFloorPattern(offscreen_buffer_t& bitmap, int time,
	int) {
	if(!bitmap.pixelBuffer)
		return;

	uint8* row = (uint8*)bitmap.pixelBuffer;

	float angle = time * 0.02f;
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

			uint8 c = (checkerX ^ checkerY) ? (UINT8_MAX - 1) : 80;
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

INTERNAL void DebugDrawIntoFrameBuffer(offscreen_buffer_t& bitmap, int paramA,
	int paramB) {
	switch(ANIMATED_DEBUG_PATTERN) {
		case PATTERN_SHIFTING_GRADIENT:
			DebugDrawUseMarchingGradientPattern(bitmap, paramA, paramB);
			break;
		case PATTERN_CIRCULAR_RIPPLE:
			DebugDrawUseRipplingSpiralPattern(bitmap, paramA, paramB);
			break;
		case PATTERN_CHECKERBOARD:
			DebugDrawUseCheckeredFloorPattern(bitmap, paramA, paramB);
			break;
		case PATTERN_AXIS_GRADIENTS:
			DebugDrawUseColorGradientPattern(bitmap, paramA, paramB);
			break;
		case PATTERN_GRID_SCANLINE:
			DebugDrawUseMovingScanlinePattern(bitmap, paramA, paramB);
			break;
	}
}

EXPORT void AdvanceSimulation(simulation_state_t& simulation, gamepad_state_t& controllerInputs, offscreen_buffer_t& bitmap) {
	simulation.offsetX += controllerInputs.stickX >> 12;
	simulation.offsetY += controllerInputs.stickY >> 12;

	// NOTE: Application/game state updates should go here (later)
	simulation.offsetX++;
	simulation.offsetY++;
	simulation.offsetY++;

	DebugDrawIntoFrameBuffer(bitmap, simulation.offsetX, simulation.offsetY);
}