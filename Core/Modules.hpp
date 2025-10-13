#pragma once

typedef struct simulation_frame_inputs {
	uint64 clock;
	milliseconds uptime;
	// TODO: Controller/keyboard/mouse inputs
} program_input_t;

// TODO sync with GDI struct (single source of truth)
typedef struct {
	int32 width; // TBD: uint32?
	int32 height;
	int32 bytesPerPixel;
	int32 stride;
	void* pixelBuffer;
} offscreen_buffer_t;

typedef struct simulation_frame_outputs {
	// TODO: Should push render commands and not actually draw into a buffer
	offscreen_buffer_t canvas;

	// TODO: Audio buffer/outputs
	uint32 bitrateSamplesPerSecond;
	uint32 samplesArraySize;
	int16 samples;
} program_output_t;

// TBD: AdvanceSimulation
EXPORT void SimulateNextFrame(program_memory_t* memory, program_input_t* inputs, program_output_t* outputs);
