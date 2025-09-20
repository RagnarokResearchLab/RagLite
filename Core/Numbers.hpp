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
#define Min(firstNumber, secondNumber) (((firstNumber) < (secondNumber)) ? (firstNumber) : (secondNumber))
#define Max(firstNumber, secondNumber) (((firstNumber) > (secondNumber)) ? (firstNumber) : (secondNumber))
#define ClampToInterval(number, lowerBound, upperBound) (Min(Max(number, lowerBound), upperBound))
#define ClampToUnitRange(number) ClampToInterval(number, 0, 1)

typedef float percentage;
constexpr float EPSILON = 0.001f;

INTERNAL inline int Percent(percentage percent) {
	if(percent - 1.0 > EPSILON) return 100;
	if(percent < EPSILON) return 0;
	percent *= 100.0;
	return (int)percent;
}

typedef float seconds;
typedef float milliseconds;
typedef float FPS;
constexpr milliseconds MILLISECONDS_PER_SECOND = 1000.0f;

INTERNAL inline float DoubleToFloat(double number) {
	float narrowed = (float)number;
	ASSUME(number - narrowed <= EPSILON, "Detected narrowing conversion that drops too much precision");
	return narrowed;
}