typedef struct virtual_memory_arena {
	// TBD: Store this header in the arena itself (required for free-lists/resizes - later)?
	uint8* basePointer;
	size_t reservedSize;
	size_t committedSize;
	size_t usedCapacity;
	size_t allocationCount;
} memory_arena_t;

INTERNAL inline void ArenaInitializeFromMemory(memory_arena_t& arena, uint8* startingAddress, size_t allocatedBufferSize) {
	arena.basePointer = startingAddress;

	arena.reservedSize = allocatedBufferSize;
	arena.committedSize = allocatedBufferSize;

	arena.allocationCount = 0;
	arena.usedCapacity = 0;
}

INTERNAL inline uint8* ArenaAllocateMemoryRegion(memory_arena_t& arena, size_t allocationSize) {
	size_t totalUsed = arena.usedCapacity + allocationSize;
	ASSUME(totalUsed <= arena.reservedSize, "Attempting to allocate outside of the reserved region");

	uint8* memoryRegionStartPointer = arena.basePointer + arena.usedCapacity;
	arena.usedCapacity = totalUsed;
	arena.allocationCount++;

	return memoryRegionStartPointer;
}

INTERNAL inline bool ArenaCanAllocate(memory_arena_t& arena, size_t allocationSize) {
	if(arena.usedCapacity + allocationSize > arena.reservedSize) return false;
	return true;
}

INTERNAL inline void ArenaResetAllocations(memory_arena_t& arena) {
	arena.allocationCount = 0;
	arena.usedCapacity = 0;
}

INTERNAL inline void ArenaDebugTouchAddress(memory_arena_t& arena, uint8* address) {
	ASSUME(address >= arena.basePointer, "Attempted to access an invalid memory offset");
	intptr_t offset = PointerToAddress(address) - PointerToAddress(arena.basePointer);
	// TODO: Update last accessed time
}