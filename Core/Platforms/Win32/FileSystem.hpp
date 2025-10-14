// #pragma once

// INTERNAL inline FILETIME GetLastWriteTime(const char* fileSystemPath) {
// 	WIN32_FILE_ATTRIBUTE_DATA fileAttributes;
// 	if(GetFileAttributesExA(fileSystemPath, GetFileExInfoStandard, &fileAttributes))
// 		return fileAttributes.ftLastWriteTime;

// 	FILETIME empty = {};
// 	return empty;
// }

// typedef struct reloadable_program_module {
// 	HMODULE handle;
// 	FILETIME lastWriteTime;
// 	void (*SimulateNextFrame)(program_memory_t* memory, program_input_t* inputs, program_output_t* outputs);
// } program_code_t;

// // TODO: PDB not needed
// INTERNAL bool PlatformLoadProgramCode(program_code_t& program) {
// 	program_code_t result = {};
// 	result.lastWriteTime = GetLastWriteTime(fileSystemPath);
// 	// TBD: Also copy debug info to avoid having to add custom path mappings in the debugger...
// 	// CopyFileA(pdb_path, "RagLite2Dbg.loaded.pdb", FALSE);
// 	// if PlatformFileSystemPathExists(pdb) rename it also...?
// 	CopyFileA(program.fileSystemPath, "RagLite2Dbg.loaded.dll", FALSE);
// 	result.handle = LoadLibraryA("RagLite2Dbg.loaded.dll");
// 	// TBD: Should probably delete this on exit?
// 	// result.handle = LoadLibraryA(fileSystemPath);
// 	if(result.handle)
// 		result.SimulateNextFrame = (void (*)(program_memory_t*, program_input_t*, program_output_t*))GetProcAddress(result.handle, "SimulateNextFrame");

// 	return result;
// }

// void PlatformUnloadProgramCode(program_code_t& module) {
// 	if(!module.handle) return;
// 	// TODO: Ensure there's no dangling pointers (redirect to guard module/blocks -> Fail immediately in debug mode)
// 	FreeLibrary(module.handle);
// 	module.handle = NULL;
// 	module.SimulateNextFrame = NULL;
// }

// INTERNAL bool PlatformShouldReloadProgramCode(program_code_t& module) {
// 	// TODO: Move fileSystemPath to program struct
// 	FILETIME writeTime = GetLastWriteTime("RagLite2Dbg.dll"); // TBD: Save this in the struct also?
// 	// TBD: Check for errors (file may have become unavailable since it was last accessed)?
// 	if(!CompareFileTime(&writeTime, &module.lastWriteTime)) return false;

// 	return true;
// }

// INTERNAL void PlatformReloadProgramCode(program_code_t& module) {
// 	PlatformUnloadProgramCode(module);
// 	PlatformLoadProgramCode(module);
// }