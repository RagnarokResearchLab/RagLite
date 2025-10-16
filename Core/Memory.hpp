// NOTE: These are mutually exclusive - do not combine them ever (unhappiness will find you)
enum arena_lifetime_flag {
	KEEP_FOREVER_MANUAL_RESET = 0, // Default choice (make sure the arena is small)
	RESET_AFTER_EACH_FRAME, // Transient memory likely wants to use this mode
	RESET_AFTER_TASK_COMPLETION, // Async workloads/resource loading (NYI)
	RESET_AUTOMATICALLY_TIMED_EXPIRY, // For persistent resources/prefetcher/memory pressure mode (NYI)
};

// TBD: Not sure if these are useful for anything other than debug annotations (revisit later)
enum arena_usage_flag {
	UNUSED_PLACEHOLDER = 0,
	PREALLOCATED_ON_LOAD, // Sane default (choose whenever possible)
	DYNAMIC_RESIZE_FREELIST, // NYI: Can remove this ideally? (not sure yet, keep as a reminder for now)
	CAN_HOT_RELOAD, // NOTE: Must not change structures with this flag or things will go horribly wrong
};

typedef struct virtual_memory_arena {
	// TBD: Gate debug-time features via flags? Unlikely to matter for the time being (revisit later)
	String displayName;
	arena_lifetime_flag lifetime;
	arena_usage_flag usage;
	// TBD: Store this header in the arena itself (required for free-lists/resizes - later)?
	void* baseAddress;
	size_t reservedSize;
	size_t committedSize;
	size_t used;
	size_t allocationCount;
} memory_arena_t;

// TBD Guard with feature flag (check if compiler removes when unused - assumption: yes)
INTERNAL String ArenaUsageToString(memory_arena_t& arena) {
	switch(arena.lifetime) {
		case UNUSED_PLACEHOLDER:
			return StringLiteral("Unused (Placeholder)");
		case PREALLOCATED_ON_LOAD:
			return StringLiteral("Preallocated (Default)");
		case DYNAMIC_RESIZE_FREELIST:
			return StringLiteral("Dynamic (Resizeable)");
		case CAN_HOT_RELOAD:
			return StringLiteral("Reloadable (Pinned)");
		default:
			return StringLiteral("N/A");
	}
}

INTERNAL String ArenaLifetimeToString(memory_arena_t& arena) {
	switch(arena.lifetime) {
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