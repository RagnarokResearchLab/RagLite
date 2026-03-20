// ABOUT:
// TODO

#include "../Core/RagLite2.hpp"
// #include "../Core/Numbers.hpp"

// TODO: Eliminate this
#include <stdio.h>
#include <string.h>

typedef enum : uint8_t {
	FILE_FORMAT_NONE,
	FILE_FORMAT_PAK,
	FILE_FORMAT_GRF,
} roff_format_t;

typedef enum : uint8_t {
	OPCODE_DEFAULT_ACTION,
	OPCODE_LIST_CONTENTS,
} roff_opcode_t;

typedef struct {
	roff_format_t fileFormat;
	roff_opcode_t requestedOperation;
	const char* inputSource;
	const char* outputDestination;
} roff_request_t;

INTERNAL roff_format_t ParseFileFormat(const char* argument) {
	if(!argument) return FILE_FORMAT_NONE;
	if(strcmp(argument, "pak") == 0) return FILE_FORMAT_PAK;
	if(strcmp(argument, "grf") == 0) return FILE_FORMAT_GRF;
	return FILE_FORMAT_NONE;
}

INTERNAL roff_opcode_t ParseFileOperation(const char* argument) {
	if(!argument) return OPCODE_DEFAULT_ACTION;
	if(strcmp(argument, "list") == 0) return OPCODE_LIST_CONTENTS;
	return OPCODE_DEFAULT_ACTION;
}

INTERNAL roff_request_t HandleCommandLineArguments(size_t argCount, const char** arguments) {
	roff_request_t requestDetails = {
		.fileFormat = FILE_FORMAT_NONE,
		.requestedOperation = OPCODE_DEFAULT_ACTION
	};

	if(argCount > 1) requestDetails.fileFormat = ParseFileFormat(arguments[1]);
	if(argCount > 2) requestDetails.requestedOperation = ParseFileOperation(arguments[2]);
	if(argCount > 3) requestDetails.inputSource = arguments[3];
	if(argCount > 4) requestDetails.outputDestination = arguments[4];

	return requestDetails;
}

// TODO: Compute this automatically (requires a bit of annoying boilerplate, but it's not too difficult)
GLOBAL const char* THIS_EXECUTABLE = "RagnarokTools.exe";

INTERNAL void DisplayUsageInfo() {
	printf("Usage: %s [ command action input output]\n\n", THIS_EXECUTABLE);
	printf("Available commands: grf OR help (default) OR pak\n");
	printf("Available operations: list (default)\n");
	printf("Available inputs: stdin (default) OR <filePath>\n");
	printf("Available outputs: stdout (default) OR <filePath>\n");
}

// TODO: Use the actual platform handle type here (may be in another branch, don't recall... alas, it must wait)
typedef void* platform_handle_t;

typedef void (*dispatch_fn_t)(platform_handle_t input, platform_handle_t output);
typedef struct {
	dispatch_fn_t list;
} opcode_list_t;

// TODO: Move to ArcturusPAK

INTERNAL void ListFileContentsPAK(platform_handle_t input, platform_handle_t output) {
	// TODO: Use the existing C++ decoder prototype (better than nothing, I guess)
	printf("NYI :(\n");
}

// TODO Move to RagnarokGRF

// TODO make sure API is compatible with C (no handles/references, just buffers? Or at least wrap it/expose C API also)
// INTERNAL void DecodeFileContentsRagnarokGRF(roff_context_t& self, platform_handle_t& fileHandle) {
// 	// TBD: Probably faster to read both (save one round trip to the kernel...) - benchmark later?
// 	size_t headerSize = sizeof(grf_header_t);
// 	void* writeBuffer = arena_push(self.tempArena, headerSize, false, false);
// 	PlatformReadFileContents(fileHandle, 0, headerSize, writeBuffer);

// 	grf_header_t* header = (grf_header_t*)writeBuffer;
// 	size_t fileTableStartOffset = headerSize + header->file_table_offset;

// 	size_t tableHeaderSize = sizeof(grf_file_table_t);
// 	writeBuffer = arena_push(self.tempArena, tableHeaderSize, false, false);
// 	PlatformReadFileContents(fileHandle, fileTableStartOffset, tableHeaderSize, writeBuffer); // TBD Get/Put
// 	grf_file_table_t* tableHeader = (grf_file_table_t*)writeBuffer;
// 	// grf_header_t* compressedFileTable = (grf_file_table_t*)writeBuffer;

// 	if(!PlatformNoFileErrors(fileHandle)) { // TBD PlatformCheckFileErrors
// 		printf("Failed to decode file contents\n");
// 		return;
// 	}

// 	// TBD size_t
// 	uint32_t compressedSize = tableHeader->compressed_size;
// 	uint32_t decompressedSize = tableHeader->decompressed_size;

// 	uint8_t* compressedTable = (uint8_t*)arena_push(self.tempArena, compressedSize, false, false);

// 	PlatformReadFileContents(
// 		fileHandle,
// 		fileTableStartOffset + tableHeaderSize, // skip the two uint32s
// 		compressedSize,
// 		compressedTable);
// 	printf("Compressed size: %u\nDecompressed size: %u\n", compressedSize, decompressedSize);
// 	printf("first bytes: %02X %02X %02X %02X %02X %02X\n",
// 		compressedTable[0],
// 		compressedTable[1],
// 		compressedTable[2],
// 		compressedTable[3],
// 		compressedTable[4],
// 		compressedTable[5]);

// 	platform_handle_t debugDumpFile = PlatformOpenFileHandle("compressed-toc.bin");
// 	if(!PlatformNoFileErrors(debugDumpFile)) {
// 		printf("Failed to open compressed-toc.bin (platform-specific error)\n");
// 		printf("Make sure the file exists in the current working directory and is readable by this process\n");
// 		return;
// 	}
// 	// TODO close handles, or let OS handle it (heh)?
// 	PlatformWriteFileContents(debugDumpFile, 0, compressedSize, compressedTable);
// 	uint8_t* decompressedTable = (uint8_t*)arena_push(self.tempArena, decompressedSize, false, false);

// 	size_t outSize = decompressedSize;

// 	if(!DecompressZlibBuffer(
// 		   compressedTable,
// 		   compressedSize,
// 		   decompressedTable,
// 		   outSize)) {
// 		printf("Failed to decompress GRF table\n");
// 		// return;
// 	}

// 	platform_handle_t debugDumpFileDEC = PlatformOpenFileHandle("decompressed-toc.bin");
// 	PlatformWriteFileContents(debugDumpFileDEC, 0, decompressedSize, decompressedTable);

// 	uint8_t* cursor = decompressedTable;
// 	for(uint8_t index = 0; index < header->file_count; index++) {
// 		size_t pathSize = 0;
// 		utf8_string_t filePath = {
// 			.size = 0,
// 			.bytes = cursor,
// 		};
// 		while(*(cursor++) != '\0') {
// 			pathSize++;
// 			// TODO path normalization, possibly PlatformNormalizeFileName here, too (needs unit tests/special cases...)
// 		}
// 		// TBD StringEnsureNullTermination -> not needed here, as long as TOC is kept in memory... readonly view
// 		// pathSize++;

// 		filePath.size = pathSize;
// 		// TODO add timers to all of these steps so that it can be compared to the LuaJIT version
// 		utf8_string_t normalizedFilePath = euc_kr_to_utf8(filePath.buffer, self.tempArena); // push string, size param...

// 		// TODO path separators -- also handled by Platform layer?
// 		utf8_string_t localizedPathName = LocalizePath(self.tempArena, normalizedFilePath);
// 		printf("Decoded %zd bytes: %s (EUC-KR) -> %s (UTF-8) - Translated: ", pathSize, filePath.characters, normalizedFilePath.characters, localizedPathName.characters);
// 		printf("\n");

// 		grf_file_entry_t* entry = (grf_file_entry_t*)cursor;
// 		cursor += sizeof(grf_file_entry_t);
// 	}
// }

INTERNAL void ListFileContentsGRF(platform_handle_t input, platform_handle_t output) {
	// TODO: Plug in the C++ prototype (requires miniz or stb for DEFLATE, Hangul decoding POC - finish that one first?)
	printf("NYI :(\n");

	// TODO use input parameter
	// TODO use output parameter (stdout/file)
	// platform_handle_t fileHandle = PlatformOpenFileHandle("data.grf");
	// if(!PlatformNoFileErrors(fileHandle)) {
	// 	printf("Failed to open data.grf (platform-specific error)\n");
	// 	printf("Make sure the file exists in the current working directory and is readable by this process\n");
	// 	return;
	// }

	// size_t fileSize = PlatformGetFileSizeInBytes(fileHandle);
	// utf8_string_t readableFileSize = StringFormatFileSize(self.tempArena, fileSize);
	// const char* readableHash = "TODO";
	// printf("Reading table of contents from data.grf (size: %s - MD5: %s)\n", readableFileSize.characters, readableHash);

	// DecodeFileContentsRagnarokGRF(self, fileHandle);

	// PlatformCloseFileHandle(fileHandle);
}

INTERNAL opcode_list_t GetSupportedFormatOperations(roff_format_t fileFormat) {
	opcode_list_t supportedOperations = {};

	switch(fileFormat) {
		case FILE_FORMAT_PAK:
			supportedOperations.list = ListFileContentsPAK;
			break;
		case FILE_FORMAT_GRF:
			supportedOperations.list = ListFileContentsGRF;
		default:
			break;
	}

	return supportedOperations;
}

int main(size_t argCount, const char** arguments) {
	roff_request_t requestDetails = HandleCommandLineArguments(argCount, arguments);
	if(requestDetails.fileFormat == FILE_FORMAT_NONE) return DisplayUsageInfo();

	// memory_arena_t tempArena = {};
	// PlatformBumpAllocate(tempArena, MB(64)); // PlatformCreateMemoryArena (utility lib)
	// if(!PlatformNoMemoryErrors(tempArena)) {
	// 	fprintf(stderr, "Failed to allocate virtual memory regions (a platform-specific error was reported)\n");
	// 	printf(stderr, "Retry after making sure there is enough memory available to run this program.\n");
	// 	return 3;
	// }

	// TODO: Open platform handle to input file or stream
	// TODO: Open platform handle to output file or stream

	opcode_list_t supportedOperations = GetSupportedFormatOperations(requestDetails.fileFormat);
	dispatch_fn_t dispatchFunction = NULL;
	switch(requestDetails.requestedOperation) {
		case OPCODE_DEFAULT_ACTION:
		case OPCODE_LIST_CONTENTS:
			dispatchFunction = supportedOperations.list;
			break;
		default:
			fprintf(stderr, "The requested operation is not currently supported for this file type :/\n");
			return 1;
	}

	if(!dispatchFunction) {
		fprintf(stderr, "Unsupported file format or no dispatch handlers registered yet (?)\n");
		return 2;
	}

	// TODO: Pass the actual platform handle (default: try to open data.grf / data.pak?)
	dispatchFunction(NULL, NULL);

	return 0;
}
