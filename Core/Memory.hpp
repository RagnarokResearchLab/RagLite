typedef struct virtual_memory_arena {
	// TBD: Store this header in the arena itself (required for free-lists/resizes - later)?
	void* baseAddress;
	size_t reservedSize;
	size_t committedSize;
	size_t used;
	size_t allocationCount;
} memory_arena_t;

typedef struct program_memory_state {
	memory_arena_t persistentMemory;
	memory_arena_t transientMemory;
} program_memory_t;

typedef struct memory_allocation_options {
	uint32 allocationType;
	uint32 protectionConstraints;
	size_t reservedSize;
	void* startingAddress;
} allocation_options_t;

typedef struct program_memory_requirements {
	allocation_options_t persistentMemoryOptions;
	allocation_options_t transientMemoryOptions;
} memory_config_t;

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