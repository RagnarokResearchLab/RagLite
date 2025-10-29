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

INTERNAL inline size_t SystemMemoryAlignToPageBoundary(size_t unalignedAllocationSize) {
	// TODO: Align to OS page granularity (use CPU_PERFORMANCE_METRICS.allocationGranularity)
	size_t alignedAllocationSize = unalignedAllocationSize;
	// NOTE: Deliberately skipped since alignment-related metrics and tooling should be added first
	return alignedAllocationSize;
}

INTERNAL size_t SystemMemoryDebugScanAvailableRange(void* basePointer) {
	MEMORY_BASIC_INFORMATION memoryInfo;
	void* scanCursor = basePointer;
	VirtualQuery(scanCursor, &memoryInfo, sizeof(memoryInfo));
	while(memoryInfo.AllocationBase == basePointer) {
		scanCursor = (uint8*)scanCursor + memoryInfo.RegionSize;
		VirtualQuery(scanCursor, &memoryInfo, sizeof(memoryInfo));
	}
	uintptr_t advancedBytes = PointerToAddress(scanCursor) - PointerToAddress(basePointer);
	return advancedBytes;
}

INTERNAL uint8* SystemMemoryPreallocateBuffer(size_t allocationSize, memory_allocation_options_t options = SystemMemoryDefaultAllocationOptions()) {
	size_t alignedSize = SystemMemoryAlignToPageBoundary(allocationSize);

	LPVOID regionStartPointer = VirtualAlloc(options.baseAddress, alignedSize, options.allocationType, options.protectionConstraints);
	ASSUME(regionStartPointer != NULL, "Failed to allocate virtual memory region (check GetLastError for details?)");
	ASSUME(regionStartPointer == options.baseAddress, "Platform allocator did not accept the provided base address");

#ifdef RAGLITE_ZEROIZED_PAGES
	size_t totalAllocatedSize = SystemMemoryDebugScanAvailableRange(regionStartPointer);
	ASSUME(totalAllocatedSize >= allocationSize, "Platform allocated less memory than requested (??)");
	ASSUME(totalAllocatedSize == alignedSize, "Platform allocated with different alignment than expected");
	// NOTE: This is guaranteed by VirtualAlloc on Win32, but that's not necessarily true on other platforms
	ZeroMemory(regionStartPointer, totalAllocatedSize); // TODO: Move to test program since it's extremely slow
#endif

	return (uint8*)regionStartPointer;
}

}