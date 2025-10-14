#pragma once

INTERNAL inline FILETIME PlatformGetLastWriteTime(String& fileSystemPath) {
	WIN32_FILE_ATTRIBUTE_DATA fileAttributes;
	bool success = GetFileAttributesExA(fileSystemPath.buffer, GetFileExInfoStandard, &fileAttributes);
	ASSUME(success, "Failed to get file attributes (check last platform error or try again later?)");

	return fileAttributes.ftLastWriteTime;
}
