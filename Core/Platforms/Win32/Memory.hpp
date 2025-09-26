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