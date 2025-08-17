#include <psapi.h>

typedef struct virtual_memory_arena {
	void* base; // Base of VirtualAlloc region TODO baseAddress
	size_t reservedSize; // Total reserved with VirtualAlloc TODO inBytes
	size_t committedSize; // Pages committed so far TBD or bytes?
	size_t used; // Bytes handed out to allocations TBD or count?
	size_t allocationCount; // Number of allocations (if tracked) TODO freed also? avg size etc.?
} memory_arena_t;

// TODO Actually create via VirtualAlloc
GLOBAL memory_arena_t MAIN_MEMORY = {
	.base = (void*)0xDEADBEEFull,
	.reservedSize = 64u * 1024 * 42 * 1024,
	.committedSize = 64u * 1024 * 42 * 512,
	.used = 64 * 1024 * 42 * 256,
	.allocationCount = 42
};