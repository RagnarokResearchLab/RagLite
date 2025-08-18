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
	.reservedSize = 64u * 1024 * 42 * 1024,
	.committedSize = 64u * 1024 * 42 * 512,
	.used = 64 * 1024 * 42 * 256,
	.allocationCount = 42
};

GLOBAL memory_arena_t TRANSIENT_MEMORY = {
	.name = "Preallocated (Transient Memory)",
	.lifetime = "Frame (Scoped Arena)",
	.baseAddress = (void*)0xDEADBEEFull,
	.reservedSize = 64u * 1024 * 42 * 1024,
	.committedSize = 64u * 1024 * 42 * 512,
	.used = 64 * 1024 * 42 * 256,
	.allocationCount = 42
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

	// TODO Assert page size matches allocation granularity

	MAIN_MEMORY = {
		// .name = "Preallocated (Main Memory)",
		.name = "SMOLL",
		.lifetime = "Forever (Global Arena)",
		// .baseAddress = (void*)0xDEADBEEFull,
		.baseAddress = VirtualAlloc(mainMemoryBaseAddress, Gigabytes(1) + Megabytes(32), MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE),
		.reservedSize = Gigabytes(1) + Megabytes(32),
		// .reservedSize = 64u * 1024 * 42 * 1024,
		// .commitedSize = 0,
		.committedSize = 64u * 1024 * 42 * 512,
		.used = 0,
		// .used = 64 * 1024 * 42 * 256,
		.allocationCount = 0
		// .allocationCount = 42
	};

	TRANSIENT_MEMORY = {
		.name = "HUGE",
		// .name = "Preallocated (Transient Memory)",
		.lifetime = "Frame (Scoped Arena)",
		// .baseAddress = (void*)0xDEADBEEFull,
		.baseAddress = (uint8*)MAIN_MEMORY.baseAddress + MAIN_MEMORY.reservedSize,
		// .reservedSize = 64u * 1024 * 42 * 1024,
		.reservedSize = Gigabytes(1),
		// .committedSize = 64u * 1024 * 42 * 512,
		.committedSize = 0,
		// .used = 64 * 1024 * 42 * 256,
		.used = 0,
		// .allocationCount = 42
		.allocationCount = 0

	};
}