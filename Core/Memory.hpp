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