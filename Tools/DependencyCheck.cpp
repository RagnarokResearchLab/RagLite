#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <imagehlp.h>
#include <stdio.h>

static const char* expectedDependencies[] = {
	"KERNEL32.DLL",
	"USER32.DLL",
	"GDI32.DLL",
	"SHLWAPI.DLL",
	"XINPUT1_4.DLL",
	"WINMM.DLL",
	"IMAGEHLP.DLL",
	NULL
};

inline bool StringEqualsCaseInsensitive(const char* first, const char* second) {
	return _stricmp(first, second) == 0;
}

static bool IsExpectedDependency(const char* dllName) {
	for(int i = 0; expectedDependencies[i]; ++i) {
		if(StringEqualsCaseInsensitive(expectedDependencies[i], dllName)) return true;
	}
	return false;
}

int main(int argc, char** argv) {
	if(argc != 2) {
		fprintf(stderr, "No input path provided (missing CLI arguments)\n");
		return 2;
	}

	const char* inputFilePath = argv[1];
	LOADED_IMAGE image;

	if(!MapAndLoad(inputFilePath, NULL, &image, TRUE, TRUE)) {
		fprintf(stderr, "Failed to load PE image: %s\n", inputFilePath);
		return 2;
	}

	IMAGE_IMPORT_DESCRIPTOR* descriptor = (IMAGE_IMPORT_DESCRIPTOR*)
		ImageRvaToVa(image.FileHeader, image.MappedAddress,
			image.FileHeader->OptionalHeader.DataDirectory
				[IMAGE_DIRECTORY_ENTRY_IMPORT]
					.VirtualAddress,
			NULL);

	if(!descriptor) {
		printf("No imports found in PE image: %s\n", inputFilePath);
		UnMapAndLoad(&image);
		return 0;
	}

	int numUnexpectedImports = 0;
	printf("Scanning PE image for runtime dependencies: %s\n", inputFilePath);
	for(; descriptor->Name; descriptor++) {
		const char* dllName = (const char*)ImageRvaToVa(image.FileHeader,
			image.MappedAddress,
			descriptor->Name, NULL);
		if(!dllName) continue;

		printf("  ✓  %s\n", dllName);
		if(!IsExpectedDependency(dllName)) {
			fprintf(stderr, "  ⚠  Unexpected runtime dependency: %s\n", dllName);
			numUnexpectedImports++;
		}
	}
	if(numUnexpectedImports == 0) printf("SUCCESS: No unexpected runtime dependencies found in %s\n", inputFilePath);
	else fprintf(stderr, "FAILED: %d unexpected runtime dependencies found in %s\n", numUnexpectedImports, inputFilePath);

	UnMapAndLoad(&image);
	return numUnexpectedImports;
}
