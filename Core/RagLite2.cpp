#include "RagLite2.hpp"

#define GLOBAL static
#define INTERNAL static

#include "Intrinsics.hpp"
#include "Numbers.hpp"
#include "Strings.hpp"

// #define NAMESPACE_BEGIN(label) namespace label {
// #define NAMESPACE_END(label) } // label
// #define NAMESPACE_BEGIN(label) namespace label {
// #define NAMESPACE_END }

#ifdef RAGLITE_PLATFORM_WINDOWS
#include "Platforms/Win32.cpp"
#endif


// search static, should be 0
// local macro
// hmh src how does it use the allocator
// gameupdateandrender move to new file, rafnarok/aecturus.cpp
// store offset in main mem, frame garbage in scoped

// rjf arenas talk/code

// pak.exe - pak.dll - api

// note that arena must be zeroized for all platforms

// 2x valloc vs add to base ptr, split to catch overwrite, surround with memprotect guards
// HMH history
