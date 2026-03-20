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
