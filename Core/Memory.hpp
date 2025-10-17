#ifdef RAGLITE_DEBUG_ARENAS
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
	void* baseAddress;
	size_t reservedSize;
	size_t committedSize;
	size_t used;
	size_t allocationCount;
#ifdef RAGLITE_DEBUG_ARENAS
	arena_metadata_t debugInfo;
#endif
} memory_arena_t;

#ifdef RAGLITE_DEBUG_ARENAS

INTERNAL String ArenaLifetimeToString(memory_arena_t& arena) {
	switch(arena.debugInfo.lifetime) {
		case KEEP_FOREVER_MANUAL_RESET:
			return StringLiteral("Forever (Global Arena)");
		case RESET_AFTER_EACH_FRAME:
			return StringLiteral("Frame (Scoped Arena)");
		case RESET_AFTER_TASK_COMPLETION:
			return StringLiteral("Task Completion (Transfer Arena)");
		case RESET_AUTOMATICALLY_TIMED_EXPIRY:
			return StringLiteral("Auto-Expires (Caching Arena)");
		default:
			return StringLiteral("N/A");
	}
}

#endif

INTERNAL void* ArenaAllocateMemoryRegion(memory_arena_t& arena, size_t allocationSize) {
	size_t totalUsed = arena.used + allocationSize;
	ASSUME(totalUsed <= arena.reservedSize, "Attempting to allocate outside the reserved set");

	void* memoryRegionStartPointer = (uint8*)arena.baseAddress + arena.used;
	arena.used = totalUsed;
	arena.allocationCount++;

	return memoryRegionStartPointer;
}

INTERNAL bool ArenaCanAllocate(memory_arena_t& arena, size_t allocationSize) {
	if(arena.used + allocationSize > arena.reservedSize) return false;
	return true;
}

void ArenaResetAllocations(memory_arena_t& arena) {
	arena.allocationCount = 0;
	arena.used = 0;
}

INTERNAL inline void ArenaDebugTouchAddress(memory_arena_t& arena, uint8* address) {
	ASSUME(address >= arena.baseAddress, "Attempted to access an invalid arena offset");
	size_t offset = address - (uint8*)arena.baseAddress;
	// TODO: Update last accessed time
}