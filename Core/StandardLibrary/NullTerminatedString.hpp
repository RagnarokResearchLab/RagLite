#pragma once

constexpr char ASCII_NULL_TERMINATOR = '\0';
constexpr char ASCII_FORWARD_SLASH = '/';
constexpr char ASCII_BACKWARD_SLASH = '\\';

typedef const char* cstring_t;
INTERNAL size_t NullTerminatedStringLength(cstring_t nullTerminatedString) {
	size_t length = 0;
	while(nullTerminatedString[length] != ASCII_NULL_TERMINATOR)
		++length;
	return length;
}