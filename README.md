# MetalParticles

A SwiftUI macOS demo that renders 10k Metal-powered particles which repel from the mouse and spring back into place.

![Demo of the app](Assets/demo.gif)

## Features

- Metal compute kernel updates particle physics each frame; render pipeline draws particles as points.
- Interactive repulsion around the mouse with configurable radius and strength in the shader uniforms.
- SwiftUI host with an NSViewRepresentable wrapper around `MTKView`, including mouse tracking for pixel-accurate input.

## Project Structure

- `Package.swift` – SwiftPM executable target for macOS 14+; bundles the Metal shader sources.
- `Sources/MetalParticles/App.swift` – App entry point and window setup.
- `Sources/MetalParticles/ContentView.swift` – SwiftUI view embedding the Metal view.
- `Sources/MetalParticles/MetalView.swift` – `NSViewRepresentable` wrapping an `MTKView` that forwards mouse input to the renderer.
- `Sources/MetalParticles/Renderer.swift` – Metal pipelines, particle buffer initialization, and per-frame compute/render passes.
- `Sources/MetalParticles/Shaders.metal` & `ShaderDefinitions.h` – Compute kernel plus vertex/fragment shaders and shared structs.

## Building & Running

1. Ensure Xcode 15+ (Swift 5.9, macOS 14 SDK) is installed.
2. Open the package in Xcode (`Package.swift`) or build from the command line:
   ```bash
   swift run
   ```
3. A window opens with animated particles; move the mouse to push particles away.

## Notes

- The renderer tries to load a bundled `default.metallib`; if unavailable it compiles `Shaders.metal` at runtime.
- Particle positions reset on view-size changes to keep the grid distribution aligned with the viewport.
