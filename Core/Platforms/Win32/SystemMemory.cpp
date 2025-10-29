constexpr uint64 HIGHEST_VIRTUAL_ADDRESS = Terabytes(64);
constexpr uint64 PREDICTABLE_VIRTUAL_ADDRESS = Terabytes(2);
constexpr uint64 UNSPECIFIED_VIRTUAL_ADDRESS = NULL;

typedef struct memory_allocation_options {
	DWORD protectionConstraints;
	WORD allocationType;
	LPVOID baseAddress;
} memory_allocation_options_t;

INTERNAL inline memory_allocation_options_t SystemMemoryDefaultAllocationOptions() {
	memory_allocation_options_t options = {
		.protectionConstraints = PAGE_READWRITE,
		.allocationType = MEM_RESERVE | MEM_COMMIT,
		.baseAddress = (LPVOID)UNSPECIFIED_VIRTUAL_ADDRESS,
	};

#ifdef RAGLITE_PREDICTABLE_MEMORY
	options.baseAddress = (LPVOID)PREDICTABLE_VIRTUAL_ADDRESS;
#endif

	return options;
}

INTERNAL size_t SystemMemoryAlignToPageBoundary(size_t unalignedAllocationSize) {
	// TODO: Align allocationSize to OS page granularity (use CPU_PERFORMANCE_METRICS.allocationGranularity)
	size_t alignedAllocationSize = unalignedAllocationSize;
	// NOTE: Deliberately skipped since alignment-related performance metrics and other tooling should be added first
	return alignedAllocationSize;
}

INTERNAL uint8* SystemMemoryPreallocateBuffer(size_t allocationSize, memory_allocation_options_t options = SystemMemoryDefaultAllocationOptions()) {
	size_t alignedSize = SystemMemoryAlignToPageBoundary(allocationSize);

	LPVOID regionStartPointer = VirtualAlloc(options.baseAddress, alignedSize, options.allocationType, options.protectionConstraints);
	ASSUME(regionStartPointer != NULL, "Failed to allocate virtual memory region (check GetLastError for details?)");

#ifdef RAGLITE_PREDICTABLE_MEMORY
	ASSUME(regionStartPointer == options.baseAddress, "Platform allocator did not accept the provided base address");
#endif

	// TODO: Add guard pages before/after the memory region to catch OOB access faults

#ifdef RAGLITE_ZEROIZE_PAGES
	// NOTE: This is guaranteed by VirtualAlloc on Win32, but not necessarily on other platforms
	ZeroMemory(regionStartPointer, alignedSize);
#endif

	return (uint8*)regionStartPointer;
}
