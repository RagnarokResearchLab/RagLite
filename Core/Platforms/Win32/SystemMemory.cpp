constexpr LPVOID PREDICTABLE_VIRTUAL_ADDRESS = Terabytes(1);
constexpr LPVOID UNSPECIFIED_VIRTUAL_ADDRESS = NULL;

typedef struct memory_allocation_options {
	DWORD protectionConstraints;
	WORD allocationType;
	LPVOID baseAddress;
} memory_allocation_options_t;

INTERNAL inline memory_allocation_options_t DefaultAllocationOptions() {
	memory_allocation_options_t options = {
		.protectionConstraints = PAGE_READWRITE,
		.allocationType = MEM_RESERVE | MEM_COMMIT,
		.baseAddress = UNSPECIFIED_VIRTUAL_ADDRESS,
	};

	#ifdef RAGLITE_PREDICTABLE_MEMORY
		options.baseAddress = PREDICTABLE_VIRTUAL_ADDRESS;
	#endif

	return options;
}

typedef pointer_t uintptr_t;
typedef index_t pointer_t;
typedef offset_t pointer_t;
typedef length_t pointer_t;
typedef pointer_diff_t intptr_t;

typedef struct virtual_memory_region {
	pointer_t startingAddress;
	size_t allocationSize;
} memory_t;
typedef memory_t slice_t;

INTERNAL memory_t SystemMemoryPreallocateBuffer(size_t allocationSize, memory_allocation_options_t options = DefaultAllocationOptions()) {
	LPVOID memory = VirtualAlloc(options.baseAddress, allocationSize, options.allocationType, options.protectionConstraints);
	ASSUME(memory != NULL, "Failed to allocate virtual memory region (check GetLastError for details?)");

	#ifdef RAGLITE_PREDICTABLE_MEMORY
		ASSUME(memory == PREDICTABLE_VIRTUAL_ADDRESS, "Platform allocator did not accept the provided base address");
	#endif
}

INTERNAL void SystemMemoryInitializeArenas(size_t mainMemorySize, size_t transientMemorySize) {


	MAIN_MEMORY = {
		.displayName = StringLiteral("Main Memory"),
		.lifetime = KEEP_FOREVER_MANUAL_RESET,
		.baseAddress = VirtualAlloc(options.baseAddress, allocationSize, options.allocationType, options.protectionConstraints),
		.reservedSize = mainMemorySize,
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0
	};

	TRANSIENT_MEMORY = {
		.displayName = StringLiteral("Transient Memory"),
		.lifetime = KEEP_FOREVER_MANUAL_RESET,
		.baseAddress = (uint8*)MAIN_MEMORY.baseAddress + mainMemorySize,
		.reservedSize = transientMemorySize,
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0
	};

	MAIN_MEMORY.committedSize = mainMemorySize;
	TRANSIENT_MEMORY.committedSize = transientMemorySize;
}
