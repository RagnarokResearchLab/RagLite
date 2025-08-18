#include <psapi.h>

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

void SystemMemoryInitializeArenas() {
// TODO Pin base address only in debug mode
#if 0
    	LPVOID mainMemoryBaseAddress = (LPVOID)Terabytes(2);
    	LPVOID transientMemoryBaseAddress = (LPVOID)Terabytes(2) + (LPVOID)Terabytes(2);
#else
	LPVOID mainMemoryBaseAddress = 0;
	LPVOID transientMemoryBaseAddress = (LPVOID)Terabytes(2);
#endif

	// TODO assert aligned with page size (4k)

	// TODO assert larger than 4096 page size
	// TODO Assert page size matches allocation granularity
	// TODO lock via flag so it actually crashes when exhausted
	MAIN_MEMORY = {
		.name = "Main Memory (Preallocated))",
		.lifetime = "Forever (Global Arena)",
		// TODO Commit separately, not ahead of time
		.baseAddress = VirtualAlloc(mainMemoryBaseAddress, Gigabytes(1) + Megabytes(32), MEM_RESERVE, PAGE_READWRITE),
		.reservedSize = Gigabytes(1) + Megabytes(32),
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0
	};

	TRANSIENT_MEMORY = {
		.name = "Transient Memory (Preallocated)",
		.lifetime = "Frame (Scoped Arena)",
		.baseAddress = (uint8*)MAIN_MEMORY.baseAddress + Gigabytes(1),
		.reservedSize = Gigabytes(1),
		.committedSize = 0,
		.used = 0,
		.allocationCount = 0

	};
}

void* SystemMemoryAllocate(memory_arena_t& arena, size_t allocationSize) {
	// TODO assert arena.reservedSize - arena.used > size else fail loudly?
	arena.allocationCount++;
	arena.committedSize += allocationSize;

	void* startAddress = VirtualAlloc((uint8*)arena.baseAddress + arena.used, allocationSize, MEM_COMMIT, PAGE_READWRITE);
	// TODO assert it didn't fail?
	// TBD What to do with this start address?
	void* memoryRegionStartPointer = (uint8*)arena.baseAddress + arena.used;
	arena.used += allocationSize;

	return memoryRegionStartPointer;
}

bool SystemMemoryCanAllocate(memory_arena_t& arena, size_t allocationSize) {
	if(arena.used + allocationSize > arena.reservedSize) return false;
	return true;
}

void SystemMemoryReset(memory_arena_t& arena) {
	// TBD Don't want to ever free the committed range, presumably?
	arena.used = 0;
	arena.allocationCount = 0;
}