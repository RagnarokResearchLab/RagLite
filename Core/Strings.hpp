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
			*buffer++ = '0' + digit;
			fractionalPart -= digit;
		}
	}

	*buffer = '\0';
	return (int)(buffer - scratch);
}