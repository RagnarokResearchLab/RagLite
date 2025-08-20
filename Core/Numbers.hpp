#include <stdint.h>

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

#define Kilobytes(bytes) ((bytes) * 1024LL)
#define Megabytes(bytes) (Kilobytes(bytes) * 1024LL)
#define Gigabytes(bytes) (Megabytes(bytes) * 1024LL)
#define Terabytes(bytes) (Gigabytes(bytes) * 1024LL)

typedef float percentage;
constexpr float EPSILON = 0.001f;

inline int Percent(percentage percent) {
	if(percent - 1.0 > EPSILON) return 100;
	if(percent < EPSILON) return 0;
	percent *= 100.0;
	return (int)percent;
}

typedef double milliseconds;
typedef double FPS;
constexpr milliseconds MILLISECONDS_PER_SECOND = 1000.0;

// TODO rename to Numerics (?)

// TODO buggy
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define MIN(a, b) ((a) < (b) ? (a) : (b))
