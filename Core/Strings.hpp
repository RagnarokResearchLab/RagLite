INTERNAL int FloatToString(char* buffer, float numberToFormat, int precisionInDecimals) {
	if(numberToFormat < 0) {
		*buffer++ = '-';
		numberToFormat = -numberToFormat;
	}

	uint32 integralPart
		= (uint32)numberToFormat;
	float fractionalPart = numberToFormat - (float)integralPart;

	char scratch[32];
	int length = 0;
	do {
		scratch[length++] = '0' + (int)(integralPart % 10);
		integralPart
			/= 10;
	} while(integralPart
		> 0);

	for(int index = length - 1; index >= 0; --index) {
		*buffer++ = scratch[index];
	}

	if(precisionInDecimals > 0) {
		*buffer++ = '.';
		for(int d = 0; d < precisionInDecimals; d++) {
			fractionalPart *= 10.0;
			int digit = (int)fractionalPart;
			*buffer++ = '0' + (char)digit;
			fractionalPart -= digit;
		}
	}

	*buffer = '\0';
	return (int)(buffer - scratch);
}

constexpr char ASCII_NULL_TERMINATOR = '\0';
constexpr char ASCII_FORWARD_SLASH = '/';
constexpr char ASCII_BACKWARD_SLASH = '\\';
constexpr char ASCII_PERIOD_DOT = '.';

typedef struct counted_string {
	size_t length;
	union {
		char* buffer;
		uint8* bytes;
	};
} counted_string_t;

typedef counted_string_t String;

INTERNAL size_t StringLength(const char* nullTerminatedString) {
	size_t length = 0;
	while(nullTerminatedString[length] != ASCII_NULL_TERMINATOR)
		++length;
	return length;
}

inline void StringEnsureNullTermination(String& countedString) {
	countedString.bytes[countedString.length] = ASCII_NULL_TERMINATOR;
	// NOTE: Embedded NULL bytes make interop with C APIs more difficult - avoid them for now
	ASSUME(StringLength(countedString.buffer) == countedString.length, "Detected unexpected NULL byte before the end");
};

String StringCreateFromNullTerminatedBuffer(char* nullTerminatedStringLiteral) {
	String countedString = {
		.length = StringLength(nullTerminatedStringLiteral),
		.buffer = nullTerminatedStringLiteral,
	};
	StringEnsureNullTermination(countedString);
	return countedString;
}

String StringCreateFromSlice(uint8* byteArray, size_t length) {
	String countedString = {
		.length = length,
		.bytes = byteArray,
	};
	return countedString;
}

#define CountedString(nullTerminatedStringLiteral) StringCreateFromNullTerminatedBuffer(nullTerminatedStringLiteral)
#define StringBuffer(nullTerminatedStringLiteral) StringCreateFromRawByteArray(nullTerminatedStringLiteral)
#define StringLiteral(nullTerminatedStringLiteral) {                     \
	sizeof(nullTerminatedStringLiteral) - sizeof(ASCII_NULL_TERMINATOR), \
	(char*)(nullTerminatedStringLiteral),                                \
}

INTERNAL void PathStringToBaseNameInPlace(String& fileSystemPath) {
	if(fileSystemPath.length == 0 || fileSystemPath.buffer == NULL) return;

	for(size_t baseNameStartIndex = fileSystemPath.length; baseNameStartIndex > 0; --baseNameStartIndex) {
		char charAt = fileSystemPath.buffer[baseNameStartIndex - 1];
		if(charAt == ASCII_FORWARD_SLASH || charAt == ASCII_BACKWARD_SLASH) {
			fileSystemPath.buffer += baseNameStartIndex;
			fileSystemPath.length -= baseNameStartIndex;
			StringEnsureNullTermination(fileSystemPath);
			return;
		}
	}
}

INTERNAL void PathStringStripFileExtensionInPlace(String& fileSystemPath) {
	size_t length = fileSystemPath.length;
	for(size_t offset = 0; offset < length; ++offset) {
		size_t lastScannedCharIndex = length - offset - 1;
		char charAt = fileSystemPath.bytes[lastScannedCharIndex];
		if(charAt == ASCII_PERIOD_DOT) {
			fileSystemPath.length = lastScannedCharIndex;
			StringEnsureNullTermination(fileSystemPath);
			return;
		}
	}
}
