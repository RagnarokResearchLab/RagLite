#ifdef RAGLITE_DEBUG_ANNOTATIONS
// NOTE: These are purely cosmetic right now - later they should be used to automatically reset arenas (?)
enum arena_lifetime_flag : uint8 {
	KEEP_FOREVER_MANUAL_RESET = 0,
	RESET_AFTER_EACH_FRAME,
	RESET_AFTER_TASK_COMPLETION,
	RESET_AUTOMATICALLY_TIMED_EXPIRY,
};

typedef struct arena_debug_info {
	String displayName;
	arena_lifetime_flag lifetime;
} arena_metadata_t;
#endif

typedef struct virtual_memory_arena {
	// TBD: Store this header in the arena itself (required for free-lists/resizes - later)?
	uint8* basePointer;
	size_t reservedSize;
	size_t committedSize;
	size_t usedCapacity;
	size_t allocationCount;
#ifdef RAGLITE_DEBUG_ANNOTATIONS
	arena_metadata_t debugInfo;
#endif
} memory_arena_t;

INTERNAL inline String ArenaToDebugString(memory_arena_t& arena) {
	String displayName = StringLiteral("N/A");

#ifdef RAGLITE_DEBUG_ANNOTATIONS
	displayName = arena.debugInfo.displayName;
#endif

	return displayName;
}

INTERNAL String ArenaLifetimeToString(memory_arena_t& arena) {

#ifdef RAGLITE_DEBUG_ANNOTATIONS

	switch(arena.debugInfo.lifetime) {
		case KEEP_FOREVER_MANUAL_RESET:
			return StringLiteral("Forever (Global Arena)");
		case RESET_AFTER_EACH_FRAME:
			return StringLiteral("Frame (Scoped Arena)");
		case RESET_AFTER_TASK_COMPLETION:
			return StringLiteral("Task Completion (Transfer Arena)");
		case RESET_AUTOMATICALLY_TIMED_EXPIRY:
			return StringLiteral("Auto-Expires (Caching Arena)");
	}

#endif

	return StringLiteral("N/A");
}

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
	pointer_diff_t offset = PointerToAddress(address) - PointerToAddress(arena.basePointer);
	// TODO: Update last accessed time
}