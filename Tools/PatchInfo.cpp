// ABOUT: This is a standalone downloader for fetching kRO patch manifests and archives, using basic sockets + HTTP only
// ABOUT: It is extremely brittle, unoptimized, and generally awful. Do NOT use for anything even remotely important (!)
// ABOUT: The primary goal of having this tool at all is to allow archiving RGZ/GPF files somewhat simply and "portably"

// TODO: Use the actual platform APIs (most of them aren't finished, revisit this after landing the WIP branches)
// TODO: Don't allocate huge buffers just because we can... Streaming or at least a global arena would be preferable
// TODO: If external dependencies end up being used, libcurl would be a way easier and better solution (deferred)
// TODO: Doesn't use HTTPS, but then the patch servers still run on HTTP anyway (they do also support HTTPS by now)
// TODO: Error handling is basically nonexistent. Working as intended, since this is a throwaway utility anyway (?)
// TODO: Not tested at all on real POSIX platforms, only on MSYS2 where it did work. Portability isn't very relevant yet
// TODO: Should probably remove libc and not allocate too much on the stack OR heap, if a better solution was to be made
// TODO: Technically, it would be possible to parallelize downloads, show some progress indicator, or retry on failure
// TODO: It would also make sense to use CLI arguments to configure the patch server/URL, download specific files, etc.
// TODO: Ideally, check the total file size and make sure there is enough free disk space available before starting, too

// TODO: Avoid relying on these if at all possible
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// TODO: Should use the existing feature detection mechanism as all other applications
#define GLOBAL static
#define INTERNAL static

#ifdef _WIN32
#define PLATFORM_WINDOWS 1
// NOTE: Do NOT reorder these as it'll break the build when using MSYS2 (sigh)
#include <winsock2.h>
#include <windows.h>

#include <ws2tcpip.h>

#else
#define PLATFORM_UNIX 1
#include <sys/stat.h>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>
#endif

// ABOUT: This belongs into the Core/base library (it probably exists already on some unfinished WIP branch... alas)
// TODO: Replace with standard (assertion-guarded) cast utilities
INTERNAL inline int SizeToInt(size_t u64) {
	return (int)u64;
}

// NOTE: This also belongs into the Core library; if URL parsing is something worth supporting properly, use libcurl (?)
INTERNAL int ParseURL(const char* url, char* host, char* path) {
	if(strncmp(url, "http://", 7) != 0)
		return 0;

	const char* p = url + 7;
	const char* slash = strchr(p, '/');

	if(!slash)
		return 0;

	strncpy(host, p, slash - p);
	host[slash - p] = 0;

	strcpy(path, slash);

	return 1;
}

// ABOUT: This is a placeholder/stubbed version that mimicks the actual platform layer, which hasn't been finished yet
// TODO: Replace with the standardized platform layer (this is a hacky version that wasn't designed to be robust at all)

// NOTE: Very much incomplete (minimal placeholder; can upgrade later if needed)
void PlatformCreateDirectory(const char* fileSystemPath) {
#ifdef PLATFORM_WINDOWS
	// TODO: Should use the widechar version in general, even if it doesn't matter here
	CreateDirectoryA(fileSystemPath, NULL);
#else
	mkdir(fileSystemPath, 0755);
#endif
}

INTERNAL int PlatformFileExists(const char* path) {
#ifdef PLATFORM_WINDOWS
	DWORD attrib = GetFileAttributesA(path);
	return attrib != INVALID_FILE_ATTRIBUTES;
#else
	struct stat st;
	return stat(path, &st) == 0;
#endif
}

// TODO: Doesn't actually use any platform APIs yet. Replace and/or delete since it's a crappy debug version anyway?
INTERNAL int PlatformReadTextFile(const char* path, char** outBuffer) {
	FILE* f = fopen(path, "rb");
	if(!f) return 0;

	fseek(f, 0, SEEK_END);
	long size = ftell(f);
	fseek(f, 0, SEEK_SET);

	char* buffer = (char*)malloc(size + 1);
	fread(buffer, 1, size, f);
	buffer[size] = 0;

	fclose(f);

	*outBuffer = buffer;
	return 1;
}

// TODO: Doesn't actually use any platform APIs yet. Replace and/or delete since it's a crappy debug version anyway?
INTERNAL int PlatformWriteFile(const char* path, void* data, size_t size) {
	FILE* f = fopen(path, "wb");
	if(!f) return 0;

	fwrite(data, 1, size, f);
	fclose(f);

	return 1;
}

// TODO: There's so much wrong with this, it's not even worth fixing - just delete and use a better approach eventually
INTERNAL int PlatformDownloadFileViaHTTP(const char* url, const char* outputFilePath) {
	char host[256];
	char path[512];

	if(!ParseURL(url, host, path))
		return 0;

#ifdef PLATFORM_WINDOWS
	static int initialized = 0;
	if(!initialized) {
		WSADATA wsa;
		WSAStartup(MAKEWORD(2, 2), &wsa);
		initialized = 1;
	}
#endif

	struct addrinfo hints = {};
	struct addrinfo* result;

	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;

	if(getaddrinfo(host, "80", &hints, &result) != 0)
		return 0;

	// TODO: Could cast from SOCKET but that seems to be a Win32 type (?) - maybe look into it later...
	auto sock = socket(result->ai_family, result->ai_socktype, result->ai_protocol);

	if(connect(sock, result->ai_addr, SizeToInt(result->ai_addrlen)) != 0)
		return 0;

	char request[1024];
	sprintf(request,
		"GET %s HTTP/1.0\r\n"
		"Host: %s\r\n"
		"\r\n",
		path, host);

#ifdef PLATFORM_WINDOWS
	send(sock, request, (int)strlen(request), 0);
#else
	send(sock, request, strlen(request), 0);
#endif

	char buffer[4096];
	int received;

	// TODO: Should use platform API here, not libc
	FILE* f = fopen(outputFilePath, "wb");
	if(!f) return 0;

	int headerEnded = 0;

	while((received = recv(sock, buffer, sizeof(buffer), 0))
		> 0) {
		if(!headerEnded) {
			char* body = strstr(buffer, "\r\n\r\n");
			if(body) {
				body += 4;
				fwrite(body, 1, received - (body - buffer), f);
				headerEnded = 1;
			}
		} else {
			fwrite(buffer, 1, received, f);
		}
	}

	fclose(f);

#ifdef PLATFORM_WINDOWS
	closesocket(sock);
#else
	close(sock);
#endif

	freeaddrinfo(result);

	return 1;
}

// NOTE: This is the actual PatchInfo code - everything above this line likely doesn't belong here (= replace or delete)
#define MAX_PATCH_FILES 4096
#define MAX_LINE 1024

typedef struct {
	int version;
	char filename[256];
} patch_file;

typedef struct {
	patch_file files[MAX_PATCH_FILES];
	int numEntries;
	int numInvalidEntries;
} patch_manifest;

INTERNAL void ParseManifestFile(char* text, patch_manifest* manifest) {
	char* line = strtok(text, "\n");

	while(line) {
		int version;
		char filename[256];

		if(sscanf(line, "%d %255s", &version, filename) == 2) {
			manifest->files[manifest->numEntries].version = version;
			strcpy(manifest->files[manifest->numEntries].filename, filename);
			manifest->numEntries++;
		} else {
			// TODO: Might want to save these and print as a space-separated list at the end, or something (?)
			manifest->numInvalidEntries++;
		}

		line = strtok(NULL, "\n");
	}
}

GLOBAL const char* DOWNLOADS_BASE_DIR = "Downloads";
GLOBAL const char* PATCHINFO_BASE_DIR = "PatchInfo";
// TODO: Use platform APIs to compute these automatically
#ifdef PLATFORM_WINDOWS
GLOBAL const char* PATCHINFO_DOWNLOADS_DIR = "Downloads\\PatchInfo";
#else
GLOBAL const char* PATCHINFO_DOWNLOADS_DIR = "Downloads/PatchInfo";
#endif

int main() {
	PlatformCreateDirectory(DOWNLOADS_BASE_DIR);
	PlatformCreateDirectory(PATCHINFO_DOWNLOADS_DIR);

	const char* manifestURL = "http://ropatch.gnjoy.com/PatchInfo/patch2.txt";
	const char* manifestPath = "Downloads/PatchInfo/patch2.txt";
	const char* patchBase = "http://ropatch.gnjoy.com/Patch";

	printf("Retrieving patch list: %s ", manifestURL);
	if(!PlatformDownloadFileViaHTTP(manifestURL, manifestPath)) {
		printf("(FAILED)\nUnable to save %s as %s (source or destination unavailable?)\n", manifestURL, manifestPath);
		return 1;
	}
	printf("(OK)\n");

	char* manifestText = 0;
	printf("Reading patch list: %s ", manifestPath);
	if(!PlatformReadTextFile(manifestPath, &manifestText)) {
		printf("(FAILED)\nUnable to read patch list from %s (file or directory may not exist?)\n", manifestPath);
		return 2;
	}
	printf("(OK)\n");

	// TODO: Probably better to heap-allocate everything here (use arenas)
	static patch_manifest manifest;
	memset(&manifest, 0, sizeof(manifest));
	ParseManifestFile(manifestText, &manifest);
	printf("Found %d valid file entries (%d invalid ones were skipped)\n", manifest.numEntries, manifest.numInvalidEntries);

	size_t downloadedFileCount = 0;
	size_t existingFileCount = 0;
	for(int i = 0; i < manifest.numEntries; i++) {
		patch_file* file = &manifest.files[i];

		char outputFilePath[512];
		sprintf(outputFilePath, "%s/%s/%s", DOWNLOADS_BASE_DIR, PATCHINFO_BASE_DIR, file->filename);

		if(PlatformFileExists(outputFilePath)) {
			existingFileCount++;
			continue;
		}

		char url[512];
		sprintf(url, "%s/%s", patchBase, file->filename);

		printf("Downloading patch file %d: %s ", file->version, file->filename);
		if(!PlatformDownloadFileViaHTTP(url, outputFilePath)) {
			printf("(FAILED)\nDownload unsuccessful: %s (network issue or storage location unavailable?)\n", url);
		}
		downloadedFileCount++;
		printf("(OK)\n");
		// TODO: Display size of each patch file downloaded/total downloaded size (?)
	}
	printf("Finished downloading %zd patch files (%zd existing ones were skipped)\n", downloadedFileCount, existingFileCount);

	// NOTE: Pointless to manually free here since the OS will clean up once the program exits
	// free(manifestText);

	return 0;
}