// ABOUT: This is a basic command-line frontend to the file formats library, intended for testing purposes and scripting

// TODO: Use the standardized platform detection macros etc. here
#define GLOBAL static
#define INTERNAL static

#include "../Core/RagLite2.hpp"

// TODO: Compute this automatically (requires a bit of annoying boilerplate, but it's not too difficult)
GLOBAL const char* THIS_EXECUTABLE = "RagnarokTools.exe";

// TODO: Eliminate this
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef enum : uint8_t {
	FILE_FORMAT_NONE,

	FILE_FORMAT_ACT,
	FILE_FORMAT_ADP,
	FILE_FORMAT_BIK,
	FILE_FORMAT_BMP,
	FILE_FORMAT_EBM,
	FILE_FORMAT_EZV,
	FILE_FORMAT_GAT,
	FILE_FORMAT_GND,
	FILE_FORMAT_GR2,
	FILE_FORMAT_GRF,
	FILE_FORMAT_IMF,
	FILE_FORMAT_JPG,
	FILE_FORMAT_MP3,
	FILE_FORMAT_PAK,
	FILE_FORMAT_PAL,
	FILE_FORMAT_RGZ,
	FILE_FORMAT_RSM,
	FILE_FORMAT_RSW,
	FILE_FORMAT_SPR,
	FILE_FORMAT_STR,
	FILE_FORMAT_TGA,
	FILE_FORMAT_WAV,

	FILE_FORMAT_COUNT,
} roff_format_t;

typedef enum : uint8_t {
	OPCODE_DEFAULT_ACTION,
	OPCODE_DESCRIBE_FORMAT,
	OPCODE_LIST_CONTENTS,
} roff_opcode_t;

typedef struct {
	roff_format_t fileFormat;
	roff_opcode_t requestedOperation;
	const char* inputSource;
	const char* outputDestination;
} roff_request_t;

typedef struct {
	roff_opcode_t opCode;
	const char* fileExtension;
	const char* description;
} roff_command_t;

GLOBAL roff_command_t ROFF_COMMAND_LIST[FILE_FORMAT_COUNT] = {};

INTERNAL roff_format_t ParseFileFormat(const char* argument) {
	if(!argument) return FILE_FORMAT_NONE;

	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_ACT].fileExtension) == 0) return FILE_FORMAT_ACT;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_ADP].fileExtension) == 0) return FILE_FORMAT_ADP;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_BIK].fileExtension) == 0) return FILE_FORMAT_BIK;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_BMP].fileExtension) == 0) return FILE_FORMAT_BMP;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_EBM].fileExtension) == 0) return FILE_FORMAT_EBM;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_EZV].fileExtension) == 0) return FILE_FORMAT_EZV;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_GAT].fileExtension) == 0) return FILE_FORMAT_GAT;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_GND].fileExtension) == 0) return FILE_FORMAT_GND;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_GR2].fileExtension) == 0) return FILE_FORMAT_GR2;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_GRF].fileExtension) == 0) return FILE_FORMAT_GRF;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_GRF].fileExtension) == 0) return FILE_FORMAT_GRF;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_IMF].fileExtension) == 0) return FILE_FORMAT_IMF;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_JPG].fileExtension) == 0) return FILE_FORMAT_JPG;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_MP3].fileExtension) == 0) return FILE_FORMAT_MP3;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_PAK].fileExtension) == 0) return FILE_FORMAT_PAK;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_PAL].fileExtension) == 0) return FILE_FORMAT_PAL;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_RGZ].fileExtension) == 0) return FILE_FORMAT_RGZ;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_RSM].fileExtension) == 0) return FILE_FORMAT_RSM;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_RSW].fileExtension) == 0) return FILE_FORMAT_RSW;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_SPR].fileExtension) == 0) return FILE_FORMAT_SPR;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_STR].fileExtension) == 0) return FILE_FORMAT_STR;
	if(strcmp(argument, ROFF_COMMAND_LIST[FILE_FORMAT_WAV].fileExtension) == 0) return FILE_FORMAT_WAV;

	return FILE_FORMAT_NONE;
}

INTERNAL roff_opcode_t ParseFileOperation(const char* argument) {
	if(!argument) return OPCODE_DEFAULT_ACTION;
	if(strcmp(argument, "info") == 0) return OPCODE_DESCRIBE_FORMAT;
	if(strcmp(argument, "list") == 0) return OPCODE_LIST_CONTENTS;
	return OPCODE_DEFAULT_ACTION;
}

INTERNAL roff_request_t HandleCommandLineArguments(size_t argCount, const char** arguments) {
	roff_request_t requestDetails = {
		.fileFormat = FILE_FORMAT_NONE,
		.requestedOperation = OPCODE_DEFAULT_ACTION,
		.inputSource = NULL,
		.outputDestination = NULL,
	};

	if(argCount > 1) requestDetails.fileFormat = ParseFileFormat(arguments[1]);
	if(argCount > 2) requestDetails.requestedOperation = ParseFileOperation(arguments[2]);
	if(argCount > 3) requestDetails.inputSource = arguments[3];
	if(argCount > 4) requestDetails.outputDestination = arguments[4];

	return requestDetails;
}

INTERNAL void DisplayUsageInfo() {
	printf("Usage: %s [ command action input output]\n\n", THIS_EXECUTABLE);
	// TODO: Synchronize this with the available command list (define once, auto-generate everything else)
	printf("Available commands: %s adp bik bmp ebm ezv gat gnd gr2 grf imf jpg mp3 pak pal png rgz rsm rsw spr str tga wav OR help (default)\n", ROFF_COMMAND_LIST[FILE_FORMAT_ACT].fileExtension);
	printf("Available operations: list or info (default)\n");
	printf("Available inputs: stdin (default) OR <filePath>\n");
	printf("Available outputs: stdout (default) OR <filePath>\n");
}

typedef void (*dispatch_fn_t)(roff_request_t requestDetails, platform_handle_t input, platform_handle_t output);
typedef struct {
	dispatch_fn_t info;
	dispatch_fn_t list;
} opcode_list_t;

INTERNAL void PlaceholderNotYetImplemented(roff_request_t requestDetails, platform_handle_t inputFileHandle, platform_handle_t outputFileHandle) {
	printf("[DISPATCH] Using platform-specific input file handle: 0x%p\n", &inputFileHandle);
	printf("[DISPATCH] Using platform-specific output file handle: 0x%p\n", &outputFileHandle);

	printf("[NYI] Alas... It is with great sorrow that I must inform you: This feature has not been implemented yet\n");
	printf("[NYI] Some day, the missing functionality may indeed be available - but, clearly, today is not that day\n");
	printf("[NYI] In due time, the patient shall see this great work come to fruition (or implement it yourself maybe)\n");

	if(!PlatformNoFileErrors(inputFileHandle)) fprintf(stderr, "[DISPATCH] Request aborted: Cannot read from an invalid OS file handle\n");
	if(!PlatformNoFileErrors(outputFileHandle)) fprintf(stderr, "[DISPATCH] Request aborted: Cannot write to an invalid OS file handle\n");
}

INTERNAL void DisplayFormatInfo(roff_request_t requestDetails, platform_handle_t inputFileHandle, platform_handle_t outputFileHandle) {
	roff_format_t fileFormat = requestDetails.fileFormat;
	if(fileFormat >= FILE_FORMAT_COUNT) {
		fprintf(stderr, "Cannot describe format (invalid format identifier)\n");
		return;
	}

	const char* description = ROFF_COMMAND_LIST[fileFormat].description;
	printf("Format description: %s\n", description);

	// TODO: It would probably be better to display (only) the supported operations for this format here

	// TODO: Might be useful to print some file metadata here (size, hash, maybe even the header?)
	printf("[NYI] A more useful file description for OS handle 0x%p should eventually appear here\n", &inputFileHandle);
}

INTERNAL opcode_list_t GetSupportedFormatOperations(roff_format_t fileFormat) {
	opcode_list_t supportedOperations = {
		.info = DisplayFormatInfo
	};

	switch(fileFormat) {
		case FILE_FORMAT_NONE:
		case FILE_FORMAT_COUNT:
			fprintf(stderr, "Attempted to query supported operations without providing a recognized file format ID\n");
			break;
		case FILE_FORMAT_ACT:
		case FILE_FORMAT_ADP:
		case FILE_FORMAT_BMP:
		case FILE_FORMAT_EBM:
		case FILE_FORMAT_EZV:
		case FILE_FORMAT_GAT:
		case FILE_FORMAT_GND:
		case FILE_FORMAT_GR2:
		case FILE_FORMAT_GRF:
		case FILE_FORMAT_IMF:
		case FILE_FORMAT_JPG:
		case FILE_FORMAT_MP3:
		case FILE_FORMAT_PAK:
		case FILE_FORMAT_PAL:
		case FILE_FORMAT_RGZ:
		case FILE_FORMAT_RSM:
		case FILE_FORMAT_RSW:
		case FILE_FORMAT_SPR:
		case FILE_FORMAT_STR:
		case FILE_FORMAT_TGA:
		case FILE_FORMAT_WAV:
		default:
			supportedOperations.list = PlaceholderNotYetImplemented;
			break;
	}

	return supportedOperations;
}

INTERNAL void InitializeCommandRegistry() {
	// TODO: Find a better way of initializing the command registry without duplicating all the data (?)
	ROFF_COMMAND_LIST[FILE_FORMAT_ACT] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_ACT,
		.fileExtension = "act",
		.description = "Flipbook/Animation catalog (Arcturus + Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_ADP] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_ADP,
		.fileExtension = "adp",
		// NOTE: Some sources call this Sonnori VOX, but I haven't checked if it's actually used in other Sonnori games
		// NOTE: Either way, it seems to be based on the IMA spec and not Dialog/OKI, so that name may be misleading (?)
		// NOTE: How do I know this? I've implemented both codecs and only the IMA one yielded correct/viable results
		.description = "Compressed IMA/ADPCM audio stream (Arcturus)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_BIK] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_BIK,
		.fileExtension = "bik",
		.description = "RAD Game Tools/Bink video container (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_BMP] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_BMP,
		.fileExtension = "bmp",
		.description = "Indexed-color bitmap/raster graphics image (Arcturus + Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_EBM] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_EBM,
		.fileExtension = "ebm",
		.description = "zlib/DEFLATE-compressed guild emblem (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_EZV] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_EZV,
		.fileExtension = "ezv",
		.description = "AmuseWorld/EZ2DJ sprite effect animation (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_GAT] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_GAT,
		.fileExtension = "gat",
		.description = "Terrain altitude/collision map (Arcturus + Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_GND] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_GND,
		.fileExtension = "gnd",
		.description = "Terrain geometry/ground mesh (Arcturus + Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_GR2] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_GR2,
		.fileExtension = "gr2",
		.description = "Granny3D character model/skeleton/animation (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_GRF] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_GRF,
		.fileExtension = "grf",
		.description = "Asset pack/container file (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_IMF] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_IMF,
		.fileExtension = "imf",
		.description = "Interface layering information (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_JPG] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_JPG,
		.fileExtension = "jpg",
		.description = "JPEG-compressed raster image (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_MP3] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_MP3,
		.fileExtension = "mp3",
		.description = "MPEG-2 Audio Layer III music track (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_PAK] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_PAK,
		.fileExtension = "pak",
		// NOTE: Some sources call this "WestPak", but I'm not sure if that's really accurate - research later, maybe?
		.description = "Asset pack/container file (Arcturus + Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_PAL] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_PAL,
		.fileExtension = "pal",
		.description = "Microsoft indexed-color palette (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_RGZ] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_RGZ,
		.fileExtension = "rgz",
		.description = "Compressed patch/diff file (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_RSM] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_RSM,
		.fileExtension = "rsm",
		.description = "Animated props/3D model file (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_RSW] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_RSW,
		.fileExtension = "rsw",
		.description = "Scene/world definition (Arcturus + Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_SPR] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_SPR,
		.fileExtension = "spr",
		.description = "Character spritesheet/sprite atlas (Arcturus + Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_STR] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_STR,
		.fileExtension = "str",
		.description = "Compiled EZV effect file (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_TGA] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_TGA,
		.fileExtension = "tga",
		.description = "TARGA/Truecolor raster image (Ragnarok Online)"
	};
	ROFF_COMMAND_LIST[FILE_FORMAT_WAV] = {
		.opCode = (roff_opcode_t)FILE_FORMAT_WAV,
		.fileExtension = "wav",
		.description = "Microsoft WAVE audio/sound effect (Arcturus + Ragnarok Online)"
	};
}

int main(size_t argCount, const char** arguments) {
	InitializeCommandRegistry();

	roff_request_t requestDetails = HandleCommandLineArguments(argCount, arguments);
	if(requestDetails.fileFormat == FILE_FORMAT_NONE) return DisplayUsageInfo();

	arena_allocator_t tempArena = PlatformCreateBumpAllocator(Megabytes(16));
	if(!PlatformNoMemoryErrors(tempArena)) {
		fprintf(stderr, "Failed to allocate virtual memory region (platform reported error: %s)\n", PlatformGetMemoryError(tempArena));
		fprintf(stderr, "Retry after making sure there is enough memory available to run this program.\n");
		return 1;
	}

	platform_handle_t inputFileHandle = {};
	if(!requestDetails.inputSource) {
		printf("[NYI] Reading from STDIN isn't currently supported, but should be very soon (... famous last words?)\n");
		// TODO: Open platform handle to stdin
	} else {
		inputFileHandle = PlatformOpenFileHandle(requestDetails.inputSource, PlatformPolicyReadOnly());
		if(!PlatformNoFileErrors(inputFileHandle)) {
			fprintf(stderr, "Failed to open %s (platform reported error: %s)\n", requestDetails.inputSource, PlatformGetFileError(inputFileHandle));
			fprintf(stderr, "Make sure the file exists in the working directory and is readable by this process\n");
			return 1;
		}
		size_t fileSize = PlatformGetFileSize(inputFileHandle);
		string_view_t readableFileSize = StringFormatFileSize(tempArena, fileSize);
		printf("[NYI] Reading file contents from %s (%zd bytes)\n", requestDetails.inputSource, fileSize);
		PlatformCloseFileHandle(inputFileHandle);
	}

	// TODO: Open platform handle to output file or stream
	platform_handle_t outputFileHandle = {};
	if(!requestDetails.outputDestination) {
		printf("[NYI] Writing to STDOUT isn't currently supported, but should be very soon (... famous last words?)\n");
	} else {
		printf("[NYI] Writing files isn't currently supported, but should be very soon (... famous last words?)\n");
	}

	opcode_list_t supportedOperations = GetSupportedFormatOperations(requestDetails.fileFormat);
	dispatch_fn_t dispatchFunction = NULL;
	switch(requestDetails.requestedOperation) {
		case OPCODE_DEFAULT_ACTION:
		case OPCODE_DESCRIBE_FORMAT:
			dispatchFunction = supportedOperations.info;
			break;
		case OPCODE_LIST_CONTENTS:
			dispatchFunction = supportedOperations.list;
			break;
		default:
			fprintf(stderr, "The requested operation isn't currently available for this file type\n");
			return 1;
	}

	if(!dispatchFunction) {
		fprintf(stderr, "Unsupported file format or its dispatch handlers weren't correctly registered (whoops?)\n");
		return 2;
	}

	// TODO: Pass the actual platform handle to the dispatch handlers after they've successfully been opened
	dispatchFunction(requestDetails, inputFileHandle, outputFileHandle);

	return 0;
}
