# Redis for Windows

This repository provides an automated pipeline and the necessary patches/CMake overlays to compile native Windows builds of Redis using MSVC.

Because upstream Redis does not officially accept PRs for native Windows compatibility (as evidenced by the rejection of [PR #14971](https://github.com/redis/redis/pull/14971)), this repository tracks upstream releases and applies a thin MSVC compat layer ([auto-win-msvc](https://github.com/SamuelMarks/auto-win-msvc)) and custom CMake build scripts to generate `.exe`, `.zip`, and `.msi` installers.

## Our Mission

Our mission is to ensure that the Windows ecosystem remains a first-class citizen for high-performance data stores like Redis (and its forks, such as Valkey). By minimizing the patch footprint and utilizing modular POSIX compatibility, we aim to maintain a clean, maintainable, and highly automated build process that stays up-to-date with upstream without burdening the core projects with Windows-specific `#ifdef`s.

## How It Works: `auto-win-msvc`

To achieve native compilation without rewriting the Redis codebase, this project makes heavy use of **[auto-win-msvc](https://github.com/SamuelMarks/auto-win-msvc)**. 

`auto-win-msvc` is a comprehensive, modular POSIX compatibility layer designed specifically to port POSIX, BSD, Solaris, and Linux software to the native Microsoft Visual Studio (MSVC) toolchain. Instead of using MinGW or Cygwin, `auto-win-msvc` enables a true native build by mapping POSIX APIs directly to Windows equivalents at compile time.

### CMake Integration

We integrate `auto-win-msvc` directly into our build pipeline using CMake's `FetchContent`. This allows us to pull the latest compatibility headers and libraries seamlessly during the build process:

```cmake
include(FetchContent)
FetchContent_Declare(
    auto_win_msvc
    GIT_REPOSITORY https://github.com/SamuelMarks/auto-win-msvc.git
    GIT_TAG        master
)
FetchContent_MakeAvailable(auto_win_msvc)
if(MSVC)
    link_libraries(auto-win-msvc)
endif()
```

By leveraging `auto-win-msvc`, we avoid polluting the upstream Redis codebase with Windows-specific headers like `<windows.h>` and significantly reduce the number of patches required to keep Redis running smoothly on Windows.

## Automated Releases

Every time upstream releases a new stable version (or triggered manually via GitHub Actions), this repo's CI:
1. Fetches the upstream tag.
2. Overlays the build files located in `overlay/`.
3. Applies source code patches from `patches/`.
4. Fetches and links the `auto-win-msvc` POSIX compatibility layer.
5. Builds using MSVC 2026 and CMake.
6. Packages a native `.msi` using the WiX toolset.
7. Packages a Windows Service wrapper (WinSW).

## Local Development

### Automated Script

For a streamlined local development and build experience, you can use the included `build-and-release.bat` script. This script automatically handles fetching the source, applying overlays and patches, building with CMake, packaging, and running end-to-end tests. 

To build, test, and skip publishing to GitHub (recommended for local testing):
```cmd
.\build-and-release.bat unstable --local-only
```

To build a specific fork like Valkey:
```cmd
.\build-and-release.bat 8.0.0 valkey --local-only
```

If you wish to do a full automated build, tag, and GitHub Release push (requires GitHub CLI configured):
```cmd
.\build-and-release.bat unstable
```

### Manual Build Process

If you prefer to build manually:
1. Clone the upstream Redis repository.
2. Copy the contents of the `overlay/` directory over the root of the Redis source tree.
3. Apply the patches located in `patches/`:
   ```bash
   git apply /path/to/redis-windows/patches/*.patch
   ```
4. Build using CMake:
   ```bash
   cmake -G "Visual Studio 18 2026" -A x64 -B build -S .
   cmake --build build --config Release
   ```
