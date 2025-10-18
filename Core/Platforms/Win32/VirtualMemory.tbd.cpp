
	// TODO ASSUME baseAddress is aligned to alloc granularity
	// TODO ASSUME allocSize is page-aligned
	// The size of the region, in bytes. If the lpAddress parameter is NULL, this value is rounded up to the next page boundary. Otherwise, the allocated pages include all pages containing one or more bytes in the range from lpAddress to lpAddress+dwSize. This means that a 2-byte range straddling a page boundary causes both pages to be included in the allocated region.
	void* memory = VirtualAlloc(baseAddress, mainMemorySize + transientMemorySize, allocationTypeFlags, memoryProtectionFlags)

	// Modes:
	// MEM_COMMIT
	// MEM_RESERVE
	// MEM_COMMIT | MEM_RESERVE
	// MEM_RESET
	// MEM_RESET_UNDO

	// MEM_LARGE_PAGES
	// MEM_WRITE_WATCH | MEM_RESERVE -> GetWriteWatch/ResetWriteWatch

	// MEMORY_ZEROIZE_BUFFER
	//

	// PAGE_EXECUTE
	// PAGE_EXECUTE_READ

	// TBD: Perf impact if accessing directly? If option is set, assert it's all zeroized (ASSUME) AND read/write once to test it works/OS does work immediately instead of later? -  only if MEM_COMMIT
	// Actual physical pages are not allocated unless/until the virtual addresses are actually accessed.