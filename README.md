# RagLite2

RagLite is a collection of various tools intended to help others understand and work with the file formats used in [Ragnarok Online](https://en.wikipedia.org/wiki/Ragnarok_Online). RO is a MMORPG created by Gravity Co, which shares many file formats with its predecessor [Arcturus](https://en.namu.wiki/w/%EC%95%85%ED%8A%9C%EB%9F%AC%EC%8A%A4). The source code mainly aims to serve as a reference implementation for other developers, as well as validate all information published on the [Ragnarok Research Lab](https://ragnarokresearchlab.github.io/) website.

Please note that RagLite is explicitly **NOT** a full game client or server implementation. If you want one, there are [many other projects](https://ragnarokresearchlab.github.io/community-projects/) aiming to accomplish this lofty goal. My focus is on research, and the tool reflects that. Even though this necessitates that some of the core concepts and gameplay mechanics need to be implemented, the program is not intended as a replacement for the original game client and/or server, per se.

## Installation

You can download (very early) "nightly" builds of the `RagLite2` executables from GitHub Actions:

<img width="1550" height="347" alt="image" src="https://github.com/user-attachments/assets/24752443-c7f5-4e2f-b623-73e75dfbdff8" />

You'll find both release and debug binaries for the supported Desktop platforms here:

* [Windows build workflow](https://github.com/RagnarokResearchLab/RagLite/actions/workflows/ci-windows.yml) (for the latest committed changes, filter the list to only show [main](https://github.com/RagnarokResearchLab/RagLite/actions/workflows/ci-windows.yml?query=branch%3Amain))

Select any workflow run or commit you're interested in testing, but do note that these artifacts will expire.

## Status

RagLite2 is the second (published) version of my RO-specific toolkit. This repository also contains the source code of the first *RagLite* toolkit. Both versions will coexist until the second reaches feature parity, or the first one breaks in a way that's too painful for me to fix. You can still use the "old" RagLite tools and read all of the source code. Indeed, they might see further development as they're better suited to prototyping.

This latest iteration is based largely on the previous version, which had too many dependencies that have now been eliminated. I believe that a minimalist approach will make it easier to use for non-developers and people without the willingness, time, or ability to set up and use tools written in multiple programming languages. As a bonus, the program is now significantly faster to run and it consumes far fewer resources.

Since I've only just started working on RagLite2, you'll have to see for yourself (read issues, commits, etc.). As for the first version: There's plenty of context for the initially-released version in this repository already. Older versions cover some of the areas not included here, such as sprite animations, GR2 model rendering, and various niche Renewal/Alpha/Beta/Arcturus features. It's largely spaghetti code and I don't have time to rewrite it, but I might be able to dig up individual notes or code snippets if prompted. Maybe the code will end up being archived separately.

## Features

RagLite (original version):

* Support for most of the RO and Arcturus file formats:
	* `ACT`: Decoding all known versions, exporting, analysis
	* `ADP`: Decoding all known versions, exporting, analysis, rendering (WIP)
	* `BIK`: Decoding, analysis (WIP)
	* `GAT`: Decoding all known versions, exporting, analysis, rendering
	* `GND`: Decoding all known versions, exporting, analysis, rendering
	* `GR2`: Decoding uncompressed versions, analysis
	* `GRF`: Decoding unencrypted versions, exporting, analysis
	* `IMF`: Decoding, analysis
	* `PAL`: Decoding all known versions, exporting, analysis
	* `PAK`: Decoding all known versions, exporting (WIP)
	* `RGZ`: Decoding all known versions
	* `RSM`: Decoding all known versions, exporting, analysis
	* `RSM2`: Decoding all known versions, exporting, analysis
	* `RSW`: Decoding all known versions, exporting, analysis, rendering
	* `SPR`: Decoding all known versions, exporting, analysis
* Visualization via the built-in WebGPU/3D renderer:
	* Terrain: Complete rendition of the game world (without props) - highly accurate (?)
	* Water: Complete GPU-accelerated rendition of all water surfaces, including waves - highest accuracy (TMK)
	* Lighting: Complete GPU-accelerated implementation of the original lighting model - highest accuracy (TMK)
	* Camera controls: Basic implementation without smoothing, interpolation, or screen shake - high accuracy (?)
	* Keybindings: Some hardcoded bindings and controls - the input system is somewhat lackluster, however
	* Screenshots: Saved automatically and in PNG format (the entire thing isn't very configurable though)
	* Keyframe Animations: Delta-time based animations are functional, but probably not 100% accurate
* Miscellaneous: Debug drawing utilities, blending, materials, metrics, cursors, resource caching, UI layer, ... (meh)
* Tests and documentation: Kind of goes without saying, although there's certainly room for improvements
* Low memory footprint and performance is "OK"-ish thanks to FFI and JIT, for whatever that's worth

RagLite2 (this version):

* Win32 platform layer
	* GDI "software" rendering for Windows: Works, but it's slow
	* Windowing and input handling: Works, but needs refinement further down the line
	* Memory management facilities: WIP
	* Audio processing and playback: WIP
	* Debug tools and visualization: Works, but very limited
* Support for most of the RO and Arcturus file formats
	* Will port the LuaJIT version once an initial version of the platform layer is done
	* Data mining tools will gradually be ported after the graphics engine is capable enough
* 3D rendering and other visualization features
	* Will integrate a crossplatform solution (likely WebGPU), with software-rendering as fallback

This list is merely intended as a quick overview and by no means authoritative.

## Limitations

RagLite (original version):

* Requires custom Lua runtime and libraries to use effectively - reading the code should be easy, though
* CLI frontend for the development tools only; 3D visualization exists but has placeholder UI elements
* The dedicated WebGPU renderer isn't production ready (crashes/resource hogging/glitches/you name it)
* Not all file formats/versions are fully supported, although most are covered well enough by now
* Kind of slow when it comes to large data processing tasks, due to poor optimization/Lua scripting

RagLite2 (current version):

* The platform layers for macOS and Linux are NYI, so you'll have to wait (or plug the holes with external libraries)
* Because the focus is on self-reliance and dropping as many dependencies as possible, features are still lacking
* There's no Lua scripting engine built in right now, so you can't use the Lua scripts written for the first version
* I know a lot less about programming in C++ than Lua, so apologies in advance to anyone reading the code
* Only a few toolchains and architectures may be supported out of the box (listed separately)

Both versions: This is a hobbyist project and progress might halt for extended periods of time. (I'll be back!)

## System requirements

**To build the applications**:

* You will need a reasonably modern C++ compiler, paired with a non-obscure and well-supported, up-to-date operating system

**To merely use the applications**:

* You can download prebuilt binaries from GitHub releases (*once I've bothered to set that up, I mean...*), then simply run them

### Third-party libraries

On Windows and macOS:

* No external libraries should be required, at least for features I'd consider mandatory
* If that ever changes, anything not provided by the OS shall be bundled with the applications

On Linux:

* There's probably no way around installing *something*, using your distribution's package manager
* I don't know how much will be required, yet - this documentation will be updated once that changes
* Both X11 and Wayland must obviously be supported; in the event that Wayland causes problems, use X11

### Support tiers

The following table shows all supported system configurations:

| Platform | Operating System | Compiler Toolchain | Support Level |
| :---: | :---: | :---: | :---: |
| x64 (AMD64) | Windows 10 | MSVC v19 (Visual Studio 2022)| `S` |
| x64 (AMD64) | Windows 11 | MSVC v19 (Visual Studio 2022)| `A` |
| x64 (AMD64) | Linux (Ubuntu) | GCC v15 | `A` |
| x64 (AMD64) | Linux (Ubuntu) | CLANG v20 | `A` |
| x64 (AMD64) | Windows 10 | CLANG v20| `A` |
| x64 (AMD64) | Windows 11 | CLANG v20| `A` |
| ARM (M1) | macOS (OSX) | CLANG v?? (XCODE ??) | `A` |
| ARM (M2) | macOS (OSX) | CLANG v?? (XCODE ??) | `A` |
| x64 (AMD64) | Windows 10 | GCC v15 (MSYS2/MINGW64) | `B` |
| x64 (AMD64) | Windows 11 | GCC v15 (MSYS2/MINGW64) | `B` |
| x64 (AMD64) | Windows 10 | GCC v15 (MSYS2/UCRT64) | `B` |
| x64 (AMD64) | Windows 11 | GCC v15 (MSYS2/UCRT64) | `B` |
| x64 (AMD64) | macOS (OSX) | CLANG v?? (XCODE ??) | `B` |
| ARM (M3) | macOS (OSX) | CLANG v?? (XCODE ??) | `C` |

Support levels:

* `S`: Primary target for local development, automated testing, and performance optimization
* `A`: Secondary target for local development, with testing largely covered by automated CI workflows
* `B`: Testing may be performed less frequently, if at all - although troubleshooting issues could be feasible
* `C`: There's no way of testing currently, so you're on your own - good luck, and godspeed!
* `D`: There's no way of testing whatsoever, and it probably won't work without major adjustments

Note that the above applies only to platform layers that have been implemented at all (the rest will follow in due time).

Platforms that are explicitly NOT supported (corresponding to `D` tier, at best):

* Web Browsers (WebAssembly/Emscripten)
* Proprietary video game consoles of any kind
* Mobile phones and other handheld devices (Android/iOS)
* Legacy versions of popular operating systems (Windows XP, Windows 7, macOS 9, ...)

If you're feeling lucky, you might nevertheless be able to port the toolkit to some of those platforms.

Even though I've no idea why anyone would want to do this, you're welcome to look into what it would take.

## Building from source

### Windows

Building on Windows requires Microsoft's Visual C++ compiler toolchain, commonly referred to as [MSVC](https://en.wikipedia.org/wiki/Microsoft_Visual_C%2B%2B):

```bat
cl
Microsoft (R) C/C++ Optimizing Compiler Version 19.44.35214 for x64
Copyright (C) Microsoft Corporation.  All rights reserved.

usage: cl [ option... ] filename... [ /link linkoption... ]
```

You could use Visual Studio itself, open a `x64 Native Tools Command Prompt for VS 2022`, or manually run `vcvars64.bat`.

#### Installing the MSVC toolchain

To get a copy of Visual Studio, go to the [Microsoft website](https://visualstudio.microsoft.com/vs/features/cplusplus/). The latest "free" (Community) version should work.

While running the `Visual Studio Installer`, make sure to select at at least the following workloads:

* `C++ core features` - mandatory (?)
* `C++ core desktop features` - mandatory
* `Windows Universal C Runtime` - mandatory (?)
* `MSVC vXXX - VS 2022 C++ x64/x86 build tools (Latest)` - mandatory
* `C++ ATL for latest vXXX build tools (x86 & x64)` - mandatory
* `Windows 11 SDK (10.0.XXXXX.X)` - just pick the latest, even on Windows 10
* Optional: `C++ AdressSanitizer` - highly recommended
* Optional: `C++ profiling tools` - situationally recommended

Alternatively, you can download the build tools only ([here](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)). You must be able to invoke `cl.exe` and `rc.exe` in your terminal to proceed:

```sh
where cl
C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe
--------------------------------------------------------------------------------------------------------
where rc
C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\rc.exe
--------------------------------------------------------------------------------------------------------
cl
Microsoft (R) C/C++ Optimizing Compiler Version 19.44.35214 for x64
Copyright (C) Microsoft Corporation.  All rights reserved.

usage: cl [ option... ] filename... [ /link linkoption... ]
```

#### Compilation with Visual Studio (MSVC)

To create all build artifacts in their default configuration, simply run `build.bat` in the same environment:

```bat
build.bat
--------------------------------------------------------------------------------------------------------
RagLite2.cpp
RagLite2.cpp
Generating code
100%
Finished generating code
```

This should generate both the release and debug binaries located in the `BuildArtifacts` folder:

```
dir BuildArtifacts
--------------------------------------------------------------------------------------------------------
XX/XX/XXXX  00:00    <DIR>          .
XX/XX/XXXX  00:00    <DIR>          ..
XX/XX/XXXX  00:00           183.808 RagLite2.exe
XX/XX/XXXX  00:00           180.667 RagLite2.obj
XX/XX/XXXX  00:00            50.776 RagLite2.res
XX/XX/XXXX  00:00         1.024.512 RagLite2Dbg.exe
XX/XX/XXXX  00:00         5.984.256 RagLite2Dbg.pdb
```

During local development, you can then run `RagLite2Dbg.exe` in a debugger of your choice.

> [!TIP]
> If you're not already familiar, the [RAD Debugger](https://github.com/EpicGamesExt/raddebugger/) is definitely worth checking out!

Some other resources that might be useful:

* [MSDN: Compiling a C/C++ project from the command line](https://learn.microsoft.com/en-us/cpp/build/reference/compiling-a-c-cpp-program#from-the-command-line)
	* This reference can help you understand the compiler and linker switches used in `build.bat`
* [MSDN: Use the Microsoft C++ toolset from the command line](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line)
	* A practical tutorial if you're less experienced with C++ development on Windows (or a bit rusty)
* [MSDN: Devenv command-line switches](https://learn.microsoft.com/en-us/visualstudio/ide/reference/devenv-command-line-switches)
	* If you prefer to use the Visual Studio debugger, `devenv` might save you quite some time

## Licensing information

You may of course integrate parts of the code into your own projects, subject to the permissive [license terms](LICENSE).

### Multi-licensing approach

This project's source code and documentation is made available under any one of the following licenses:

* Public Domain (for those ~~silly~~ non-EU countries who do recognize the construct)
* Apache 2.0 License
* GPL2 License
* GPL3 License

You can pick whichever option suits you best. If you need the code to be distributed under a different license, please get in touch.

> [!NOTE]
> Attribution isn't required, but of course it is good etiquette to acknowledge the work of others if you find it useful.

### Legal notice

This repository contains no ingame assets whatsoever. The source code was written entirely from scratch, based on freely-available information, educated guesses, trial & error, black-box testing, or technical documentation derived in a [clean-room environment](https://en.wikipedia.org/wiki/Clean-room_design) (if necessary). The approach chosen should allow just about anyone to make use of the resulting software - without having to worry about non-technical concerns.

All trademarks referenced herein are the properties of their respective owners.

## Contributing

Contributions of all kinds are welcome. There's no process, just [open an issue](https://github.com/RagnarokResearchLab/RagLite/issues/new) (or [pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)) if you like.

> [!IMPORTANT]
> Needless to say, all contributions must be offered under the same multi-licensing scheme as the existing files.
