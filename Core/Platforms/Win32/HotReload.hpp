#pragma once

#define SIMULATION_STEP_FUNCTION(name) void name(program_memory_t*, program_input_t*, program_output_t*)
typedef SIMULATION_STEP_FUNCTION(simulation_step_function_t);

typedef struct reloadable_program_module {
	// String moduleName;
	HMODULE handle;
	FILETIME lastWriteTime;
	simulation_step_function_t* SimulateNextFrame;
} program_code_t;