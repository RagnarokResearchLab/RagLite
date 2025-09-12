@echo off

:: TODO /SUBSYSTEM:WINDOWS

set DEFAULT_BUILD_DIR=BuildArtifacts
if not exist %DEFAULT_BUILD_DIR% mkdir %DEFAULT_BUILD_DIR%

:: RagLite2 apps
set CPP_MAIN=Core\RagLite2.cpp
set TEST_MAIN=Tests\RagLiteTestApp.cpp
set DEBUG_EXE=%DEFAULT_BUILD_DIR%\RagLite2Dbg.exe
set RELEASE_EXE=%DEFAULT_BUILD_DIR%\RagLite2.exe
set TEST_EXE=%DEFAULT_BUILD_DIR%\RagLiteTestApp.exe

:: Platform dependencies
set RUNTIME_LIBS=gdi32.lib user32.lib xinput.lib winmm.lib

:: External dependencies (third-party code)
:: NOTE: A more portable solution would be welcome - maybe one day it'll happen
set CTIME_MAIN=Externals\ctime.c
set CTIME_EXE=%DEFAULT_BUILD_DIR%\ctime.exe
cl %DEBUG_COMPILE_FLAGS% %CTIME_MAIN% %RUNTIME_LIBS% /link %DEBUG_LINK_FLAGS% /out:%CTIME_EXE% || exit /b

set ICON_RC=Assets/RagLite2.rc
set ICON_RES=%DEFAULT_BUILD_DIR%\RagLite2.res

:: Generate app icon
rc /nologo /fo %ICON_RES% %ICON_RC% || exit /b

set SHARED_COMPILE_FLAGS=
set SHARED_LINK_FLAGS=
set DEBUG_LINK_FLAGS=
set RELEASE_LINK_FLAGS=

set CPP_STANDARD=/std:c++23preview

:: /diagnostics:caret 	Reports errors and warnings with line/column/caret
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /diagnostics:caret
:: /EHsc-    			Disable C++ exceptions (and Structured Exception Handling translation)
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /EHsc-
:: /GR-					Disables run-time type information (RTTI)
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /GR-
:: /MP					Use multiple effective processors to speed up compilation
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /MP
:: /nologo 				Suppresses the display of the copyright banner
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /nologo
:: /options:strict		Error when passing unrecognized compiler flags
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /options:strict
:: /W4					Enable informational warnings (levels 0 through 4)
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /W4
:: 						...except useless ones
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /wd4189
:: /WX					Treat all warnings as errors
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /WX
:: /Zc:strictStrings	Require const qualifier for pointers initialized via string literals
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /Zc:strictStrings
:: /Zf					Faster PDB generation in parallel builds (minimize RPC calls to mspdbsrv.exe)
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% /Zf
set SHARED_COMPILE_FLAGS=%SHARED_COMPILE_FLAGS% %CPP_STANDARD%

:: /INCREMENTAL:NO		Disable incremental linkage
set SHARED_LINK_FLAGS=%SHARED_LINK_FLAGS% /INCREMENTAL:NO
:: /MANIFEST:EMBED		Embed assembly manifest in the executable
set SHARED_LINK_FLAGS=%SHARED_LINK_FLAGS% /MANIFEST:EMBED
:: /noexp 				Suppresses the display of the copyright banner
set SHARED_LINK_FLAGS=%SHARED_LINK_FLAGS% /noexp
:: /NOLOGO				Prevents display of the copyright message and version number
set SHARED_LINK_FLAGS=%SHARED_LINK_FLAGS% /NOLOGO

:::::: Build debug binary
set DEBUG_COMPILE_FLAGS=
:: /FC					Displays the full path of source code files in diagnostic text
set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% /FC
:: /GS					Enable buffer security checks
set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% /GS
:: /MTd					Use the debug multithread, static version of the runtime library (LIBCMTD.lib)
set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% /MTd
:: /Od					Disables optimization
set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% /Od
:: /RTCcsu				Enables run-time checks (stack frame, uninitialized variables, etc.)
set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% /RTCcsu
:: /sdl					Enables recommended Security Development Lifecycle (SDL) checks
set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% /sdl
:: /Z7					Generate complete debugging information (embedded PDB)
set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% /Z7

:: /DEBUG				Creates debugging information (PDB file)
set DEBUG_LINK_FLAGS=%DEBUG_LINK_FLAGS% /DEBUG

set DEBUG_COMPILE_FLAGS=%DEBUG_COMPILE_FLAGS% %SHARED_COMPILE_FLAGS%
set DEBUG_LINK_FLAGS=%DEBUG_LINK_FLAGS% %SHARED_LINK_FLAGS%

:: NOTE: A portable solution for this would be welcome - maybe one day it'll happen

call %CTIME_EXE% -begin %DEFAULT_BUILD_DIR%\RagLite2.ctm || exit /b

call %CTIME_EXE% -begin %DEBUG_EXE%.ctm || exit /b
cl %DEBUG_COMPILE_FLAGS% %CPP_MAIN% %RUNTIME_LIBS% /link %DEBUG_LINK_FLAGS% %ICON_RES% /out:%DEBUG_EXE% || exit /b
call %CTIME_EXE%  -end %DEBUG_EXE%.ctm || exit /b

:::::: Build release binary
set RELEASE_COMPILE_FLAGS=
:: /DNDEBUG				Disable runtime assertions (#define NDEBUG)
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /DNDEBUG
:: /GL					Enables whole program optimization
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /GL
:: /GS-					Disables buffer security checks (faster, but less safe)
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /GS-
:: /Gy					Enable Function-Level Linking via packaged functions (COMDATs)
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /Gy
:: /Gw					Package global data in COMDAT sections for optimization
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /Gw
:: /MT					Use the multithread, static version of the runtime library (LIBCMT.lib)
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /MT
:: /Oi					Generates intrinsic functions
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /Oi
:: /O2					Creates fast code
set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% /O2

:: /LTCG			Enables link-time code generation
set RELEASE_LINK_FLAGS=%RELEASE_LINK_FLAGS% /LTCG
:: /NXCOMPAT			Indicates compatibility with Windows Data Execution Prevention feature
set RELEASE_LINK_FLAGS=%RELEASE_LINK_FLAGS% /NXCOMPAT
:: /OPT:REF				Eliminates functions and data that are never referenced
set RELEASE_LINK_FLAGS=%RELEASE_LINK_FLAGS% /OPT:REF
:: /OPT:ICF				Merge identical COMDAT packages
set RELEASE_LINK_FLAGS=%RELEASE_LINK_FLAGS% /OPT:ICF

set RELEASE_COMPILE_FLAGS=%RELEASE_COMPILE_FLAGS% %SHARED_COMPILE_FLAGS%
set RELEASE_LINK_FLAGS=%RELEASE_LINK_FLAGS% %SHARED_LINK_FLAGS%

call %CTIME_EXE%  -begin %RELEASE_EXE%.ctm || exit /b
cl %RELEASE_COMPILE_FLAGS% %CPP_MAIN% %RUNTIME_LIBS% /link %RELEASE_LINK_FLAGS% %ICON_RES% /out:%RELEASE_EXE% || exit /b
call %CTIME_EXE%  -end %RELEASE_EXE%.ctm || exit /b

call %CTIME_EXE%  -begin %TEST_EXE%.ctm || exit /b
cl %DEBUG_COMPILE_FLAGS% %TEST_MAIN% %RUNTIME_LIBS% /link %RELEASE_LINK_FLAGS% %ICON_RES% /out:%TEST_EXE%
call %CTIME_EXE%  -end %TEST_EXE%.ctm || exit /b

call %CTIME_EXE%  -end %DEFAULT_BUILD_DIR%\RagLite2.ctm || exit /b
call %CTIME_EXE% -stats %DEFAULT_BUILD_DIR%\RagLite2.ctm || exit /b