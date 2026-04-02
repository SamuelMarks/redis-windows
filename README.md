# Redis for Windows

This repository provides an automated pipeline and the necessary patches/CMake overlays to compile native Windows builds of Redis using MSVC.

Because upstream Redis does not officially accept PRs for native Windows compatibility, this repository tracks upstream releases and applies a thin MSVC compat layer (auto-win-msvc) and custom CMake build scripts to generate .exe, .zip, and .msi installers.

## Automated Releases

Every time upstream releases a new stable version (or triggered manually via GitHub Actions), this repo's CI:
1. Fetches the upstream tag.
2. Overlays the build files located in overlay/.
3. Applies source code patches from patches/.
4. Builds using MSVC 2022 and CMake.
5. Packages a native .msi using the WiX toolset.
6. Packages a Windows Service wrapper (WinSW).

## Local Development

To build this locally:
1. Clone the upstream Redis repository.
2. Copy the contents of the overlay/ directory over the root of the Redis source tree.
3. Apply the patches located in patches/:
   git apply /path/to/redis-windows/patches/*.patch
4. Build using CMake:
   cmake -B build -S .
   cmake --build build --config Release
