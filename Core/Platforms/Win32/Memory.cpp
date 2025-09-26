constexpr size_t HIGHEST_VIRTUAL_ADDRESS = Terabytes(1);
constexpr size_t INVALID_VIRTUAL_ADDRESS = 0xDEADBEEFULL;

GLOBAL memory_arena_t MAIN_MEMORY = {
	.displayName = StringLiteral("Main Memory"),
	.lifetime = KEEP_FOREVER_MANUAL_RESET,
	.usage = UNUSED_PLACEHOLDER,
	.baseAddress = (void*)INVALID_VIRTUAL_ADDRESS,
	.reservedSize = 0,
	.committedSize = 0,
	.used = 0,
	.allocationCount = 0
};

GLOBAL memory_arena_t TRANSIENT_MEMORY = {
	.displayName = StringLiteral("Transient Memory"),
	.lifetime = RESET_AFTER_EACH_FRAME,
	.usage = UNUSED_PLACEHOLDER,
	.baseAddress = (void*)INVALID_VIRTUAL_ADDRESS,
	.reservedSize = 0,
	.committedSize = 0,
	.used = 0,
	.allocationCount = 0
};

// TBD Guard with feature flag (check if compiler removes when unused - assumption: yes)
INTERNAL String SystemMemoryDebugUsage(memory_arena_t& arena) {
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

INTERNAL String SystemMemoryDebugLifetime(memory_arena_t& arena) {
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

INTERNAL void SystemMemoryInitializeArenas(size_t mainMemorySize, size_t transientMemorySize) {

#ifdef RAGLITE_PREDICTABLE_MEMORY
	LPVOID baseAddress = 0;
#else
	LPVOID baseAddress = (LPVOID)HIGHEST_VIRTUAL_ADDRESS;
#endif

	DWORD allocationTypeFlags = MEM_RESERVE | MEM_COMMIT;
	DWORD memoryProtectionFlags = PAGE_READWRITE;
	MAIN_MEMORY = {
		.displayName = StringLiteral("Main Memory"),
		.lifetime = KEEP_FOREVER_MANUAL_RESET,
		.usage = PREALLOCATED_ON_LOAD,
		.baseAddress = VirtualAlloc(baseAddress, mainMemorySize + transientMemorySize, allocationTypeFlags, memoryProtectionFlags),
		.reservedSize = mainMemorySize,
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0
	};

	TRANSIENT_MEMORY = {
		.displayName = StringLiteral("Transient Memory"),
		.lifetime = KEEP_FOREVER_MANUAL_RESET,
		.usage = PREALLOCATED_ON_LOAD,
		.baseAddress = (uint8*)MAIN_MEMORY.baseAddress + mainMemorySize,
		.reservedSize = transientMemorySize,
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0
	};

	MAIN_MEMORY.committedSize = mainMemorySize;
	TRANSIENT_MEMORY.committedSize = transientMemorySize;
}
