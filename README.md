# RagLite

Standalone client with built-in backend server that allows running a persistent world simulation on your computer.

## Roadmap & Features

This project is built on a few core technologies:

* A [WebGPU](https://github.com/gpuweb/gpuweb)-based 3D rendering engine is built in (uses [wgpu-native](https://github.com/gfx-rs/wgpu-native))
* Simple networking layer based on the HTTP and WebSockets protocols
* Native C++ runtime with a focus on Lua scripting (powered by [LuaJIT](https://luajit.org/))
* Asynchronous [libuv](https://github.com/libuv/libuv)-based event loop running in the host application
* Integrated tooling to analyze and work with various binary file formats

Lua is the primary language, augmented with C/C++ libraries and glue code.

## Why does it exist?

I've developed many different tools to help with my research over the years. This is just the latest iteration, but fully integrated to make my life easier. Some people have expressed interest in seeing the code, so here you go?

The previous iterations were written in JavaScript and TypeScript, with [BabylonJS](https://www.babylonjs.com/) as the rendering engine and [Electron](https://www.electronjs.org/) as the runtime. This version is powered by native technologies instead, mainly because I wanted more control.

## Status

Work in progress. It's mostly developed in public so that I can use GitHub Actions for automated testing. Note: This is a developer tool and not very advanced. Don't expect too much or you'll be disappointed. I haven't ported over most features from older versions, and likely won't add things I no longer need unless someone specifically asks.

If you want to follow the development more closely, check out the [roadmap](https://github.com/orgs/RagnarokResearchLab/projects/2) (includes both my documentation work and tools). To view the implementation status, [milestones](https://github.com/RagnarokResearchLab/RagLite/milestones) are your best bet - although they're necessarily incomplete.

## Usage

There isn't much to see yet, but if you want to give it a try:

1. Clone this repository (obviously requires [git](https://git-scm.com/))
1. Download a relase of the Lua runtime for your platform
	* Run ``./download-runtime.sh``, or download from [GitHub Releases](https://github.com/evo-lua/evo-runtime/releases)
	* The required version is usually the latest, but check the above script
	* You can also build it from source (see [docs](https://evo-lua.github.io/docs/how-to-guides/building-from-source) here; for advanced users)
1. Copy (or better yet, [symlink](https://en.wikipedia.org/wiki/Symbolic_link)) in a suitable asset container, e.g., `data.grf`
1. Now you can start one of the core apps, e.g., via `./evo start-client.lua`
1. Datamining or debugging tools can be run via `./evo Tools/<script>.lua`

A window should pop up with a basic 3D scene being visible. Tools are CLI only.

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

Contributions of all kinds are welcome. There's no process, just open an issue (or pull request) if you like.
