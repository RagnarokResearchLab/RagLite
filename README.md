# RagLite

Standalone client with built-in backend server that allows running a persistent world simulation on your computer.

## Roadmap

* Integrated tooling to analyze and work with various binary file formats
* A web-based 3D rendering engine is built in (uses TypeScript/Babylon.js)
* Simple networking layer based on the HTTP and WebSockets protocols
* Native C++ runtime with a focus on Lua scripting (powered by LuaJIT)
* Asynchronous libuv-based event loop running in the host application

## Status

Work in progress. It's mostly developed in public so that I can use GitHub Actions for automated testing.

Note: This is a developer tool and not very advanced. Don't expect too much or you'll be disappointed.

## Why does it exist?

I've developed many different tools to help with my research over the years. This is just the latest iteration, but fully integrated to make my life easier. Some people have expressed interest in seeing the code, so here you go?

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
