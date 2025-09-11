// constexpr char ASCII_NULL_TERMINATOR = '\0';
// constexpr char ASCII_FORWARD_SLASH = '/';
// constexpr char ASCII_BACKWARD_SLASH = '\\';

// INTERNAL size_t StringFindFirstNullTerminator(const char* s) { // StringLength
//     size_t n = 0;
//     while (s[n] != ASCII_NULL_TERMINATOR) ++n;
//     return n;
// }

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

// INTERNAL void PathStringToBaseNameInPlace(char* fileSystemPath) {
// 	size_t length = StringFindFirstNullTerminator(fileSystemPath);
// 	size_t lastIndex = length - 1;
// 	size_t lastPathSeparatorOffset = length;
// 	for(size_t offset = 0; offset < length; ++offset) {
// 		size_t lastScannedCharIndex = length - offset;
// 		char charAt = fileSystemPath[lastScannedCharIndex];
// 		if(charAt == ASCII_FORWARD_SLASH || charAt == ASCII_BACKWARD_SLASH) {
// 			lastPathSeparatorOffset = lastScannedCharIndex;

// 			// TODO StringCopyBackwards
// 			size_t numBytesToReverseCopy = length - lastPathSeparatorOffset;
// 			for(size_t numCharactersCopied = 0; numCharactersCopied < numBytesToReverseCopy; ++numCharactersCopied) {
// 				size_t sourceIndex = lastScannedCharIndex + numCharactersCopied + 1;
// 				char characterToCopy = fileSystemPath[sourceIndex];
// 				size_t destinationIndex = numCharactersCopied;
// 				fileSystemPath[destinationIndex] = fileSystemPath[sourceIndex];
// 			}
// 			fileSystemPath[numBytesToReverseCopy] = ASCII_NULL_TERMINATOR;
// 			return;
// 		}
// 	}
// }

// constexpr char ASCII_PERIOD_DOT = '.';
// INTERNAL void PathStringStripFileExtensionInPlace(char* fileSystemPath) {
// 	size_t length = StringFindFirstNullTerminator(fileSystemPath);
// 	for(size_t offset = 0; offset < length; ++offset) {
// 		size_t lastScannedCharIndex = length - offset;
// 		char charAt = fileSystemPath[lastScannedCharIndex];
// 		if(charAt == ASCII_PERIOD_DOT) {
// 			fileSystemPath[lastScannedCharIndex] = ASCII_NULL_TERMINATOR;
// 			return;
// 		}
// 	}
// }
