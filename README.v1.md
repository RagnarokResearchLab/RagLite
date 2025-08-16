# RagLite

Standalone client with built-in backend server that allows running a persistent world simulation on your computer.

> [!IMPORTANT]
> Standalone in this context means that all scripts should "just work" in the [Evo.lua](https://evo-lua.github.io/) runtime environment.

*Evo is a custom [Lua](https://www.lua.org/about.html) interpreter written in C++ (and C), which comes with a host of useful libraries to do the heavy lifting. You can see it as the "engine" for this and other programs, providing core features like graphics and networking. Despite being a separate project unrelated to this one, it's similarly created and maintained by me.*

Please note that RagLite is explicitly **NOT** a full game client or server implementation. If you want one, there are [many other projects](https://ragnarokresearchlab.github.io/community-projects/) aiming to accomplish this lofty goal. My focus is on research, and the tool reflects that.

## Overview

This project is built on a few core technologies:

* A [WebGPU](https://en.wikipedia.org/wiki/WebGPU)-based 3D rendering engine is included (uses [wgpu-native](https://github.com/gfx-rs/wgpu-native))
* Simple networking layer based on the [HTTP](https://en.wikipedia.org/wiki/HTTP) and [WebSocket](https://en.wikipedia.org/wiki/WebSocket) protocols
* Native [C++ runtime](https://github.com/evo-lua/evo-runtime) with a focus on Lua scripting (powered by [LuaJIT](https://luajit.org/))
* Asynchronous [libuv](https://github.com/libuv/libuv)-based [event loop](http://docs.libuv.org/en/v1.x/guide/basics.html) running in the host application
* Integrated tooling to analyze and work with various binary file formats

Lua is the primary language, augmented with C/C++ libraries and glue code.

## Why does it exist?

I've developed many different tools to help with my research over the years. This is just the latest iteration, but fully integrated to make my life easier. Some people have expressed interest in seeing the code, so here you go?

The previous iterations were written in JavaScript/TypeScript, with [BabylonJS](https://www.babylonjs.com/) as the rendering engine and [Electron](https://www.electronjs.org/) as the runtime. This version is powered by native technologies instead, mainly because I wanted more control.

## Status

Work in progress. Developed in public, to make use of GitHub Actions for automated testing. I haven't ported over most features from older versions and likely won't add things I no longer need - unless someone specifically asks.

> [!NOTE]
> This is a developer tool and not very advanced. Don't expect too much or you'll be disappointed.

If you want to follow the development more closely, check out the [roadmap](https://github.com/orgs/RagnarokResearchLab/projects/2) (includes both my documentation work and tools). To view the implementation status, [milestones](https://github.com/RagnarokResearchLab/RagLite/milestones) are your best bet - although they're necessarily incomplete.

## Roadmap & Features

Because this tool is an interactive aid that's part of my ongoing research efforts, you can expect the following:

* Complete, well-tested and documented decoders for all file formats that are of interest
* Data mining/analysis toolkit that allows importing, exporting, and converting their contents
* Approximate recreation of 3D scenes with key actors, interactions, animations, and effects
* CLI or UI-based control flow that's suitable for developers, though not necessarily "end users"
* Proof-of-concept or prototype implementations of gameplay mechanics and simulation steps (server)

Needless to say, it will take a lot more time and work until all of the above has been fully implemented.

## System Requirements

Not much to say here; hopefully the software will run on most systems:

* Recent versions of macOS, Linux, or Windows
* Any graphics backend supported by WebGPU (DirectX/Metal/Vulkan)
* CPU architecture must be supported by the LuaJIT engine

General rule of thumb: All platforms undergoing automated testing via [GitHub Actions](https://github.com/RagnarokResearchLab/RagLite/actions) are officially supported.

> [!TIP]
> For Linux users: To see what system dependencies may be required, check out the [build workflow](https://github.com/RagnarokResearchLab/RagLite/blob/main/.github/workflows/ci-linux.yml).

Mobile platforms aren't supported, and likely won't ever be (by me). It just doesn't make sense (again, to me).

## Usage

There isn't much to see yet, but if you want to give it a try:

1. Clone this repository (obviously requires [git](https://git-scm.com/))
1. Download a release of the Lua runtime for your platform
	* Run ``./download-runtime.sh``, or download from [GitHub Releases](https://github.com/evo-lua/evo-runtime/releases)
	* The required version is usually the latest, but check the above script
	* You can also build it from source (see [docs](https://evo-lua.github.io/docs/how-to-guides/building-from-source) here; for advanced users)
	* Linux users only: You may need to [install additional dependencies](https://evo-lua.github.io/docs/getting-started/installation#external-dependencies)
1. Copy (or better yet, [symlink](https://en.wikipedia.org/wiki/Symbolic_link)) in a suitable asset container, e.g., `data.grf`
1. Now you can start one of the core apps, e.g., via `./evo client.lua`
1. Datamining or debugging tools can be run via `./evo Tools/<script>.lua`

A window should pop up with a basic 3D scene being visible. Tools are CLI only.

### Loading Scenes

To load a specific map, you can pass the `mapID` (unique scene identifier) to the client via CLI args:

```sh
# Valid scene IDs are any map that's listed in the DB/Maps.lua table
# You can also directly load debug scenes (e.g., 'cube3d' or 'webgpu') this way
./evo client.lua aldebaran
```

If all you're seeing is the "hello world" fallback scene, then the map wasn't found in the database.

### Camera Controls

The following controls have been implemented so far:

* Hold right-click and drag: Adjust camera rotation (horizontal)
* SHIFT + mouse wheel (scrolling): Adjust camera rotation (vertical)
* Double-right-click: Instantly reset camera rotation (horizontal *and* vertical)
* Mouse wheel (scrolling): Adjust zoom level
* SHIFT + Arrow keys: Move the camera position (by a fixed amount) in the given direction

They're of course very rough, but should allow inspecting the rendered scene.

### Other Keybindings

You can take a screenshot by pressing the `SPACE` key. The result will be saved in the `Screenshots/` directory.

## Goals

I'm building this software with the following guidelines in mind:

* Usability: It should be easy to use and "just work" for local development and testing
* Independent: No external dependencies that require extensive orchestration to get started
* Evolutionary: Small improvements over time should eventually add up to something (hopefully) useful

This is an interactive resource intended to aid learning. It is provided for educational purposes only.

## Non-Goals

There's a number of things I explicitly don't care about, at least for the time being:

* Compatibility with existing software ecosystems and third-party projects
* Features that are moving targets, impossible to maintain, or infeasible to create
* Security, performance, and other "production quality" metrics ("spaghetti code" still isn't acceptable, though)

I'm just one person, so anything that I can't implement or that exceedingly annoys me likely won't make the cut.

## Contributing

Contributions of all kinds are welcome. There's no process, just [open an issue](https://github.com/RagnarokResearchLab/RagLite/issues/new) (or [pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)) if you like.
