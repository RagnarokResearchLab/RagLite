#pragma once

#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#include <shlwapi.h>
#include <strsafe.h>
#include <timeapi.h>

typedef struct {
	DWORD accessPermissions;
	DWORD creationDisposition;
	DWORD sharingMode;
	DWORD extraFlags;
} platform_policy_t;

typedef struct {
	const char* message;
	const char* source;
	uint32_t code;
} platform_error_t;

typedef struct {
	platform_error_t errorDetails;
	// NOTE: For portability, could store void* descriptor but then need to assert that sizeof(void*) == sizeof(HANDLE)
	// NOTE: Since the platform runtime will already know OS-specific types and each platform should have its own, meh
	HANDLE handle;

#ifdef RAGLITE_DEBUG_ANNOTATIONS
	platform_policy_t creationPolicy;
#endif
} platform_handle_t;

GLOBAL platform_error_t PLATFORM_ERROR_NONE = {
	.message = "OK",
	.source = FROM_HERE,
	.code = ERROR_SUCCESS,
};

INTERNAL inline void PlatformSetFileError(platform_handle_t& fileHandle, const char* message, const char* sourceLocation) {
	// TODO: Get platform error message via FormatErrorString (needs a new API that pushes the error string to an arena)
	fileHandle.errorDetails = {
		.message = message,
		.source = sourceLocation,
		.code = GetLastError()
	};
}

INTERNAL inline const char* PlatformGetFileError(platform_handle_t& fileHandle) {
	// TODO: Should support arena parameter that the error string can be pushed onto (then move to utility layer?)
	// NOTE: For now, just returns the hardcoded error message so that there is at least some information - if not ideal
	return fileHandle.errorDetails.message; // Cannot concatenate without string building/arenas - fix this up later
}

INTERNAL inline bool PlatformNoFileErrors(platform_handle_t& fileHandle) {
	// NOTE: It's unlikely this code would change, but relying on zeroized structs to always match it still seems wrong
	return fileHandle.errorDetails.code == PLATFORM_ERROR_NONE.code;
}

INTERNAL inline bool PlatformIsValidFileHandle(platform_handle_t& fileHandle) {
	return fileHandle.handle != INVALID_HANDLE_VALUE && fileHandle.handle != NULL;
}

INTERNAL inline platform_policy_t PlatformPolicyReadOnly() {
	platform_policy_t policy = {
		.accessPermissions = GENERIC_READ,
		.creationDisposition = OPEN_EXISTING,
		.sharingMode = FILE_SHARE_READ,
		.extraFlags = FILE_ATTRIBUTE_NORMAL,
	};
	return policy;
}

// NOTE: These probably aren't quite right - will have to revisit later when writing/deleting files is actually needed
INTERNAL inline platform_policy_t PlatformPolicyReadWrite() {
	platform_policy_t policy = {
		.accessPermissions = GENERIC_READ | GENERIC_WRITE,
		.creationDisposition = OPEN_ALWAYS,
		.sharingMode = FILE_SHARE_READ | FILE_SHARE_DELETE,
		.extraFlags = FILE_ATTRIBUTE_NORMAL,
	};
	return policy;
}

INTERNAL platform_handle_t PlatformOpenFileHandle(const char* fileSystemPath, platform_policy_t modePreset) {
	platform_handle_t fileHandle = {};

	DWORD accessPermissions = modePreset.accessPermissions;
	DWORD creationDisposition = modePreset.creationDisposition;
	DWORD sharingMode = modePreset.sharingMode;
	DWORD attributeFlags = modePreset.extraFlags;
	HANDLE templateFile = NULL;

#ifdef RAGLITE_DEBUG_ANNOTATIONS
	fileHandle.creationPolicy = modePreset;
#endif

	LPSECURITY_ATTRIBUTES securityAttributes = NULL; // Don't care (for now)
	// TODO: Should use CreateFileW and convert from UTF8 to UTF16, but that requires scratch space and testing -> later
	fileHandle.handle = CreateFileA(fileSystemPath, accessPermissions, sharingMode, securityAttributes, creationDisposition, attributeFlags, templateFile);

	if(PlatformIsValidFileHandle(fileHandle)) fileHandle.errorDetails = PLATFORM_ERROR_NONE;
	else PlatformSetFileError(fileHandle, "CreateFile returned INVALID_HANDLE_VALUE", FROM_HERE);

	return fileHandle;
}

INTERNAL void PlatformCloseFileHandle(platform_handle_t& fileHandle) {
	if(!PlatformIsValidFileHandle(fileHandle)) return;

	HANDLE handle = fileHandle.handle;
	CloseHandle(handle);
	fileHandle.handle = INVALID_HANDLE_VALUE;
}

INTERNAL size_t PlatformGetFileSize(platform_handle_t& fileHandle) {
	if(!PlatformIsValidFileHandle(fileHandle)) return 0;

	LARGE_INTEGER fileSize;
	BOOL success = GetFileSizeEx(fileHandle.handle, &fileSize);
	if(!success) {
		PlatformSetFileError(fileHandle, "GetFileSizeEx returned FALSE", FROM_HERE);
		return 0;
	}

	return (size_t)fileSize.QuadPart;
}