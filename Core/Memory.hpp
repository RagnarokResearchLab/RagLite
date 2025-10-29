typedef struct virtual_memory_arena {
	// TBD: Store this header in the arena itself (required for free-lists/resizes - later)?
	uint8* basePointer;
	size_t reservedSize;
	size_t committedSize;
	size_t usedCapacity;
	size_t allocationCount;
} memory_arena_t;

INTERNAL void* ArenaAllocateMemoryRegion(memory_arena_t& arena, size_t allocationSize) {
	size_t totalBytesUsed = arena.usedCapacity + allocationSize;
	ASSUME(totalBytesUsed <= arena.reservedSize, "Attempting to allocate outside the reserved set");

	uint8* memoryRegionStartPointer = arena.basePointer + arena.usedCapacity;
	arena.usedCapacity = totalBytesUsed;
	arena.allocationCount++;

	return memoryRegionStartPointer;
}

INTERNAL bool ArenaCanAllocate(memory_arena_t& arena, size_t allocationSize) {
	if(arena.usedCapacity + allocationSize > arena.reservedSize) return false;
	return true;
}

void ArenaResetAllocations(memory_arena_t& arena) {
	arena.allocationCount = 0;
	arena.usedCapacity = 0;
}

INTERNAL inline void ArenaDebugTouchAddress(memory_arena_t& arena, uint8* address) {
	ASSUME(address >= arena.basePointer, "Attempted to access an invalid arena offset");
	size_t offset = address - arena.basePointer;
	// TODO: Update last accessed time
}