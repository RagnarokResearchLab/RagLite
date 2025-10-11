constexpr size_t HIGHEST_VIRTUAL_ADDRESS = Terabytes(1);
constexpr size_t UNSPECIFIED_VIRTUAL_ADDRESS = NULL; // NOTE: OS will determine where to allocate the region

GLOBAL program_memory_t PLACEHOLDER_PROGRAM_MEMORY = {};
GLOBAL memory_config_t PLACEHOLDER_MEMORY_CONFIGURATION = {};

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

INTERNAL void SystemMemoryInitializeArena(memory_arena_t& arena, allocation_options_t& options) {
	ZeroMemory(&arena, sizeof(arena));
	arena.baseAddress = VirtualAlloc(options.startingAddress, options.reservedSize, options.allocationType, options.protectionConstraints);

	arena.reservedSize = options.reservedSize;
	if(options.allocationType & MEM_COMMIT) arena.committedSize = options.reservedSize;
}

INTERNAL void* SystemMemoryAllocate(memory_arena_t& arena, size_t allocationSize) {
	size_t totalUsed = arena.used + allocationSize;
	ASSUME(totalUsed <= arena.reservedSize, "Attempting to allocate outside the reserved set");

	void* memoryRegionStartPointer = (uint8*)arena.baseAddress + arena.used;
	arena.used = totalUsed;
	arena.allocationCount++;

	return memoryRegionStartPointer;
}

INTERNAL bool SystemMemoryCanAllocate(memory_arena_t& arena, size_t allocationSize) {
	if(arena.used + allocationSize > arena.reservedSize) return false;
	return true;
}

void SystemMemoryReset(memory_arena_t& arena) {
	arena.allocationCount = 0;
	arena.used = 0;
}

INTERNAL inline void SystemMemoryDebugTouch(memory_arena_t& arena, uint8* address) {
	ASSUME(address >= arena.baseAddress, "Attempted to access an invalid arena offset");
	size_t offset = address - (uint8*)arena.baseAddress;
	// TODO: Update last accessed time
}

INTERNAL inline void PlatformInitializeProgramMemory(program_memory_t& programMemory, memory_config_t& configOptions) {
	SystemMemoryInitializeArena(programMemory.persistentMemory, configOptions.persistentMemoryOptions);
	SystemMemoryInitializeArena(programMemory.transientMemory, configOptions.transientMemoryOptions);
}