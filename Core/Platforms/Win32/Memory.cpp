constexpr size_t HIGHEST_VIRTUAL_ADDRESS = Terabytes(1);
constexpr size_t INVALID_VIRTUAL_ADDRESS = 0xDEADBEEFULL;

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
