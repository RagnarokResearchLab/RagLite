constexpr size_t HIGHEST_VIRTUAL_ADDRESS = Terabytes(1);
constexpr size_t UNSPECIFIED_VIRTUAL_ADDRESS = NULL; // NOTE: OS will determine where to allocate the region

INTERNAL inline allocation_options_t PlatformDefaultAllocationOptions() {
	memory_allocation_options options = {
		.allocationType = MEM_RESERVE | MEM_COMMIT,
		.protectionConstraints = PAGE_READWRITE,
		.startingAddress = (LPVOID)UNSPECIFIED_VIRTUAL_ADDRESS,
	};
	// TODO: Zeroize on push
	// TODO: Align on push
	// TODO: Append guard pages (in debug mode)
	// TODO: Add source location (in debug mode)
	return options;
}

INTERNAL void PlatformInitializeMemoryArena(memory_arena_t& arena, allocation_options_t& options) {
	ZeroMemory(&arena, sizeof(arena));
	arena.baseAddress = VirtualAlloc(options.startingAddress, options.reservedSize, options.allocationType, options.protectionConstraints);

	arena.reservedSize = options.reservedSize;
	if(options.allocationType & MEM_COMMIT) arena.committedSize = options.reservedSize;
}

INTERNAL inline void PlatformInitializeProgramMemory(program_memory_t& programMemory, memory_config_t& configOptions) {
	PlatformInitializeMemoryArena(programMemory.persistentMemory, configOptions.persistentMemoryOptions);
	PlatformInitializeMemoryArena(programMemory.transientMemory, configOptions.transientMemoryOptions);
}