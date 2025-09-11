#include "../Core/RagLite2.hpp"

#include "../Core/Assertions.hpp"
#include "../Core/Intrinsics.hpp"
#include "../Core/Numbers.hpp"

#include "../Core/Platforms/Win32.hpp"

// #define ASSERT_TRUE(cond) \
//     Assert((cond), "ASSERTION FAILURE: " #cond " was false")

// #define ASSERT_FALSE(cond) \
//     Assert(!(cond), "ASSERTION FAILURE: " #cond " was true")

// #define ASSERT_EQ(actual, expected) do { \
//     if ((actual) != (expected)) { \
//         char buf[256]; \
//         snprintf(buf, sizeof(buf), \
//             "ASSERTION FAILURE: %s == %s, but got %lld vs %lld", \
//             #actual, #expected, (long long)(actual), (long long)(expected)); \
//         Assert(false, buf); \
//     } \
// } while (0)

// #define ASSERT_NE(actual, expected) do { \
//     if ((actual) == (expected)) { \
//         char buf[256]; \
//         snprintf(buf, sizeof(buf), \
//             "ASSERTION FAILURE: %s != %s, but both are %lld", \
//             #actual, #expected, (long long)(actual)); \
//         Assert(false, buf); \
//     } \
// } while (0)

// #define ASSERT_NOT_NULL(ptr) \
//     Assert((ptr) != NULL, "ASSERTION FAILURE: " #ptr " was NULL")

// #define ASSERT_NULL(ptr) \
//     Assert((ptr) == NULL, "ASSERTION FAILURE: " #ptr " was not NULL")

// TODO counted strings...
char concatenationBuffer[1024];
INTERNAL char* Concat(const char* first, const char* second, const char* third, const char* fourth, const char* fifth, const char* sixth) {
	size_t offset = 0;
	while(*first != 0 && offset < 1024) {
		concatenationBuffer[offset] = *first;
		first++;
		offset++;
	}

	while(*second != 0 && offset < 1024) {
		concatenationBuffer[offset] = *second;
		second++;
		offset++;
	}

	while(*third != 0 && offset < 1024) {
		concatenationBuffer[offset] = *third;
		third++;
		offset++;
	}

	while(*fourth != 0 && offset < 1024) {
		concatenationBuffer[offset] = *fourth;
		fourth++;
		offset++;
	}

	while(*fifth != 0 && offset < 1024) {
		concatenationBuffer[offset] = *fifth;
		fifth++;
		offset++;
	}

	while(*sixth != 0 && offset < 1024) {
		concatenationBuffer[offset] = *sixth;
		sixth++;
		offset++;
	}

	// concatenationBuffer[offset] = '\0';
	return concatenationBuffer;
}

char conversionBuffer[256];
INTERNAL char* int_to_str(long long value, char* buf_end) {
	char* p = buf_end;
	bool neg = false;

	if(value == 0) {
		*--p = '0';
		return p;
	}

	if(value < 0) {
		neg = true;
		value = -value;
	}

	while(value > 0) {
		*--p = '0' + (value % 10);
		value /= 10;
	}

	if(neg) {
		*--p = '-';
	}

	return p;
}

#define EXPAND_AS_STRING(x) #x
#define TOSTRING(x) EXPAND_AS_STRING(x)

#define FROM_HERE __FILE__ ":" TOSTRING(__LINE__)

// TODO replace concat buffers with scratch space (arenas)
// Base: Arenas
// StandardLibrary/Assertions
// StandardLibrary/NullTerminatedStringOps
// StandardLibrary/CountedStringOps
void Assert(bool condition, cstring_t failureMessage) {
	if(!condition) {
		char* text = Concat(failureMessage, "\n\nSource Location:\n\n", FROM_HERE, "\n\n", "", "");
#ifdef RAGLITE_GRAPHICAL_INTERFACE
		PlatformAlertPopup(text, "ASSERTION FAILURE");
		// TODO too annoying if there are many assertions...
#endif
		PlatformStandardError(text); // TBD broken in debugger?
		// PlatformProcessExit(TEST_FAILURE);
		// PlatformStandardError(Concat("ASSERTION FAILURE: ", text, "", ""));
		// // TODO enable debug trap so you can run it from the debugger also
		// TODO use PathStringToBaseNameInPlace to strip the file path (MSVC doesn't support __FILE_NAME__)
	}
}

// NOTE: These have to be macros in order to not clobber source location
// TODO: With a proper backtrace API, this might be easier to debug (but not as simple)
#ifdef RAGLITE_GRAPHICAL_INTERFACE
#define FAILURE_MESSAGE(text) PlatformAlertPopup(text, "ASSERTION FAILURE");
#else
#define FAILURE_MESSAGE(text) PlatformStandardError(text);
#endif

#define TEST_CONDITION(condition, failureMessage)                                                   \
	{                                                                                               \
		char* text = Concat(failureMessage, "\n\nSource Location:\n\n", FROM_HERE, "\n\n", "", ""); \
		FAILURE_MESSAGE(text)                                                                       \
	}

#define ASSERT_EQUAL_NUMBERS(actual, expected) TEST_CONDITION(actual == expected, Concat("Expected ", int_to_str(actual, &conversionBuffer[1024]), " to be ", int_to_str(expected, &conversionBuffer[1024]), ", but the actual value is ", int_to_str(actual, &conversionBuffer[1024])));

// void AssertEqualNumbers(uint64 actual, uint64 expected) {
// Assert(actual == expected, Concat("ASSERTION FAILURE: " #actual " is ", int_to_str(actual, &conversionBuffer[1024]), ", but should be " #expected))
// TEST_EQUALITY(actual, expected)

// Assert(actual == expected, failureMessage);
// }
//

// TODO Platform-agnostic (main or use PlatformApplicationEntry)
// TODO use Win32 platform layer, but run tests instead of debug draw demos
int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int) {
	// TODO: Remove this (silence C4505 or restructure the code?)
	IntrinsicsReadCPUID();
	PlatformAttachDevice(PLATFORM_DEVICE_STDOUT, PLATFORM_ACTION_REUSE);
	PlatformAttachDevice(PLATFORM_DEVICE_STDERR, PLATFORM_ACTION_REUSE);

	ASSERT_EQUAL_NUMBERS(NullTerminatedStringLength(""), 0);
	ASSERT_EQUAL_NUMBERS(NullTerminatedStringLength("Hello"), 5);
	ASSERT_EQUAL_NUMBERS(NullTerminatedStringLength("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"), MAX_PATH);

	// It's a hack, but whatever...
	// TCHAR cwd[MAX_PATH];
	// GetCurrentDirectory(MAX_PATH, cwd);
	// PlatformStandardOutput("\r\n");
	// PlatformStandardOutput(cwd);
	// PlatformStandardOutput("\r\n");

	return 0;
}
