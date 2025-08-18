#include <psapi.h>

// TODO Check how much of a difference this makes
constexpr bool SYSTEM_MEMORY_DELAYED_COMMITS = true;

typedef struct virtual_memory_arena {
	const char* name;
	const char* lifetime;
	void* baseAddress;
	size_t reservedSize;
	size_t committedSize;
	size_t used;
	size_t allocationCount;
} memory_arena_t;

// TODO Actually create the arena (via VirtualAlloc)
GLOBAL memory_arena_t MAIN_MEMORY = {
	.name = "Preallocated (Main Memory)",
	.lifetime = "Forever (Global Arena)",
	.baseAddress = (void*)0xDEADBEEFull,
	.reservedSize = 0,
	.committedSize = 0,
	.used = 0,
	.allocationCount = 0
};

GLOBAL memory_arena_t TRANSIENT_MEMORY = {
	.name = "Preallocated (Transient Memory)",
	.lifetime = "Frame (Scoped Arena)",
	.baseAddress = (void*)0xDEADBEEFull,
	.reservedSize = 0,
	.committedSize = 0,
	.used = 0,
	.allocationCount = 0
};

void SystemMemoryInitializeArenas(size_t mainMemorySize, size_t transientMemorySize) {
// TODO Pin base address only in debug mode
#if 0
    	LPVOID baseAddress = (LPVOID)Terabytes(1);
#else
	LPVOID baseAddress = 0;
#endif

	DWORD allocationTypeFlags = MEM_RESERVE;
	if(!SYSTEM_MEMORY_DELAYED_COMMITS) allocationTypeFlags |= MEM_COMMIT;

	// TODO assert aligned with page size (4k)

	// TODO assert larger than 4096 page size
	// TODO Assert page size matches allocation granularity
	// TODO lock via flag so it actually crashes when exhausted
	MAIN_MEMORY = {
		.name = "Main Memory (Preallocated))",
		.lifetime = "Forever (Global Arena)",
		// TODO Commit separately, not ahead of time
		.baseAddress = VirtualAlloc(baseAddress, mainMemorySize + transientMemorySize, allocationTypeFlags, PAGE_READWRITE),
		.reservedSize = mainMemorySize,
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0
	};

	// TODO assert base addr is not zero (VirtualAlloc failed)

	TRANSIENT_MEMORY = {
		.name = "Transient Memory (Preallocated)",
		.lifetime = "Frame (Scoped Arena)",
		.baseAddress = (uint8*)MAIN_MEMORY.baseAddress + mainMemorySize,
		.reservedSize = transientMemorySize,
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0

	};

	// TODO Technically would need to round up here?
	if(!SYSTEM_MEMORY_DELAYED_COMMITS) MAIN_MEMORY.committedSize = mainMemorySize;
	if(!SYSTEM_MEMORY_DELAYED_COMMITS) TRANSIENT_MEMORY.committedSize = transientMemorySize;
}

void* SystemMemoryAllocate(memory_arena_t& arena, size_t allocationSize) {
	size_t totalUsed = arena.used + allocationSize;
	// TODO assert arena.reservedSize - arena.used > size else fail loudly?
	// ASSUME(totalUsed <= arena.reservedSize, "Attempting to allocate outside the reserved set")
	if(SYSTEM_MEMORY_DELAYED_COMMITS) {
		// Commit only if the working set needs to extend past a page boundary
		// TODO allocate in 64KB blocks as needed?
		// TODO use metrics -> allocation granularity
		size_t chunkSize = Kilobytes(64);
		if(totalUsed > arena.committedSize) {
			// TODO AUse LIGN macro for clarity?
			size_t alignedPageEnd = (totalUsed + chunkSize - 1) & ~(chunkSize - 1);
			size_t alignedCommitSize = alignedPageEnd - arena.committedSize;

			void* commitResult = VirtualAlloc(
				(uint8*)arena.baseAddress + arena.committedSize,
				alignedCommitSize,
				MEM_COMMIT,
				PAGE_READWRITE);
			// TODO ASSUME(commitResult != NULL, "Failed to commit aligned chunk (RAM/page file pressure?)")
			arena.committedSize += alignedCommitSize;
		}
	} else {
		// It's already committed
		// arena.committedSize += allocationSize;
	}

	void* memoryRegionStartPointer = (uint8*)arena.baseAddress + arena.used;
	arena.used = totalUsed;
	arena.allocationCount++;

	return memoryRegionStartPointer;
}

bool SystemMemoryCanAllocate(memory_arena_t& arena, size_t allocationSize) {
	if(arena.used + allocationSize > arena.reservedSize) return false;
	return true;
}

void SystemMemoryReset(memory_arena_t& arena) {
	// TBD Don't want to ever free the committed range, presumably?
	arena.allocationCount = 0;
	arena.used = 0;
}