# Repel Pointer

A macOS application that renders 10k Metal-powered particles which repel from the mouse and spring back into place.

![Demo of the app](Assets/demo.gif)

## Implementations

This repository contains two equivalent implementations of the same logic:

1. **Swift**: Located in `repel-pointer-swift`. Uses SwiftUI and Swift Package Manager.
2. **C++**: Located in `repel-pointer-cpp`. Uses Objective-C++ (AppKit) and a Makefile.

## Features

- Metal compute kernel updates particle physics each frame.
- Render pipeline draws particles as points.
- Interactive repulsion around the mouse with configurable radius and strength (shared shader logic).

## Building & Running

### Swift (repel-pointer-swift)
1. Navigate to `repel-pointer-swift`.
2. Run:
   ```bash
   swift run
   ```

### C++ (repel-pointer-cpp)
1. Navigate to `repel-pointer-cpp`.
2. Build and run:
   ```bash
   make
   ./build/RepelPointer
   ```
