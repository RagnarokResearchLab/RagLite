// ABOUT: This is a placeholder program that has nothing in common with the Win32 platform runtime (delete when porting)

#include <cpuid.h>
#include <stdio.h>
#include <stdlib.h>
#include <err.h>
#include <string.h>

void DebugPrintASCII(unsigned int value) {
	for(int i = 0; i < 4; i++) {
		char byte = (value >> (i * 8)) & 0xFF;
		printf("%c", byte);
	}
}

// See https://en.wikipedia.org/wiki/CPUID and https://github.com/gcc-mirror/gcc/blob/master/gcc/config/i386/cpuid.h
INTERNAL void DebugDumpCPUID() {
	unsigned int eax, ebx, ecx, edx;
	// EAX=0: Highest Function Parameter and Manufacturer ID
	uint EAX_input = 0;
	unsigned int ret = __get_cpuid(EAX_input, &eax, &ebx, &ecx, &edx);
	if(ret != 1) {
		errx(EXIT_FAILURE, "Failed to call CPUID with EAX=%d", EAX_input);
	}

	printf("CPU Manufacturer ID: ");
	DebugPrintASCII(ebx);
	DebugPrintASCII(edx);
	DebugPrintASCII(ecx);
	printf("\n");
}

INTERNAL void PlatformRuntimeMain() {
	printf("There is no platform runtime for Linux yet. Instead, behold this placeholder program :3\n");

	DebugDumpCPUID();
	// TODO: Maybe dump some of the other CPU details also? Not really useful right now...

	unsigned eax = 0;
	unsigned ebx = 0;
	unsigned ecx = 0;
	unsigned edx = 0;

	int r = __get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx);
	if(!r) {
		fprintf(stderr, "cpuid leaf 7 unsupported ...\n");
		return;
	}
	printf("cpuid.07h.0: eax=0x%x ebx=0x%x ecx=0x%x edx=0x%x\n",
		eax, ebx, ecx, edx);
}
