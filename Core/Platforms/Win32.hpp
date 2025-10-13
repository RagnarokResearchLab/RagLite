#pragma once

#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#include <shlwapi.h>
#include <strsafe.h>
#include <timeapi.h>

struct GameCode {
	HMODULE dll;
	FILETIME last_write_time;
	void (*SimulateNextFrame)(program_memory_t* memory, program_input_t* inputs, program_output_t* outputs);
};

FILETIME GetLastWriteTime(const char* filename) {
	WIN32_FILE_ATTRIBUTE_DATA data;
	if(GetFileAttributesExA(filename, GetFileExInfoStandard, &data))
		return data.ftLastWriteTime;
	FILETIME empty = {};
	return empty;
}

GameCode LoadGameCode(const char* dll_path, const char* pdb_path) {
	GameCode result = {};
	result.last_write_time = GetLastWriteTime(dll_path);

	// char temp_dll[MAX_PATH];
	// sprintf_s(temp_dll, "", dll_path);

	// Copy to temp to allow rebuilds
	// TBD: Also copy debug info to avoid having to add custom path mappings in the debugger...
	CopyFileA(pdb_path, "RagLite2Dbg.loaded.pdb", FALSE);
	CopyFileA(dll_path, "RagLite2Dbg.loaded.dll", FALSE);
	result.dll = LoadLibraryA("RagLite2Dbg.loaded.dll");
	// TBD: Should probably delete this on exit?
	// result.dll = LoadLibraryA(dll_path);
	if(result.dll)
		result.SimulateNextFrame = (void (*)(program_memory_t*, program_input_t*, program_output_t*))GetProcAddress(result.dll, "SimulateNextFrame");

	return result;
}

void UnloadGameCode(GameCode* code) {
	if(code->dll) {
		FreeLibrary(code->dll);
		code->dll = 0;
		code->SimulateNextFrame = 0;
	}
}