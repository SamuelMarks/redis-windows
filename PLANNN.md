# Release Plan: Redis 8.8-rc1 for Windows (MSVC)

This document outlines the systematic process to bring the recent local fixes from `..\auto-win-msvc` and `..\redis` into this repository (`redis-windows`), verify that all tests pass natively on Windows MSVC, and cut a new tagged release (8.8-rc1) with the resulting executables and packages.

## Phase 1: Publish Upstream POSIX Compatibility Updates
Our MSVC build relies heavily on the `auto-win-msvc` POSIX compatibility layer. Recent fixes (such as C89 compliance, `posix-core.h` updates, and IO behavior fixes) are currently only in the local clone of `auto-win-msvc`.

1. **Commit Local Changes in `auto-win-msvc`:**
   Ensure all working files in `..\auto-win-msvc` are committed.
2. **Push to Origin:**
   Push the changes to `origin/master`. The `redis-windows` build system pulls `auto-win-msvc` dynamically via CMake's `FetchContent` during the build process, so pushing these changes is a strict prerequisite.

## Phase 2: Extract Patches from Local `redis`
The local `..\redis` repository has all tests passing natively on Windows, achieved via source code adjustments and Tcl test workarounds (e.g., swapping `taskkill` for `win_kill`). We need to extract these differences as patches.

1. **Generate the Unified Diff:**
   In `..\redis`, generate a clean patch comparing the local branch against the standard `8.8-rc1` tag. 
   *(Note: Exclude changes to the `cmake/` folder as those are managed via overlays).*
2. **Update the Patches Directory:**
   Copy the generated patch(es) into `redis-windows\patches\`. This will likely involve updating or replacing existing patches like `server.patch` or `tcl_hang.patch`.

## Phase 3: Sync the CMake Overlays
The `redis-windows` repository manages the build system by overlaying its own `cmake/` folder on top of the upstream source.

1. **Copy CMake Files:**
   Copy the `cmake/` folder from the working `..\redis` repository and replace the contents of `redis-windows\overlay\cmake\`.
2. [x] **Copy Tcl Overlays (If Applicable):**
   If `exec_override.tcl` or other scripts were modified in `..\redis`, ensure they are updated in `redis-windows\overlay\`.

## Phase 4: Clean Local Verification
Before pushing, we must verify that the patches and overlays apply cleanly to a fresh copy of Redis 8.8-rc1 and that all tests pass.

1. **Run the Build Script:**
   Execute the local build script to pull `8.8-rc1` upstream, apply overlays and patches, build, and run tests.
   ```cmd
   .\build-and-release.bat 8.8-rc1 redis --local-only
   ```
2. **Validate Test Output:**
   Ensure CMake configures successfully, MSVC compiles without fatal errors, and `ctest` reports 100% test success. If tests hang or fail, debug locally, adjust the patches in `redis-windows\patches\`, and repeat.

## Phase 5: CI Configuration and Tagging
Once the local build is green, it's time to push to GitHub and trigger the CI release pipeline.

1. **Commit to `redis-windows`:**
   Stage all updated files in `patches\`, `overlay\`, and this `PLANNN.md`. Commit these changes.
2. **Push to Master:**
   Push the commit to the `master` or main branch of `redis-windows`.
3. **Tag the Release:**
   Create a Git tag matching the upstream RC version:
   ```cmd
   git tag 8.8-rc1
   git push origin 8.8-rc1
   ```

## Phase 6: Release and Packaging Validation
The Git tag push will automatically trigger the `.github/workflows/release.yml` GitHub Actions pipeline.

1. **Monitor the Pipeline:**
   Watch the GitHub Actions run to ensure the Windows build runner correctly checks out `8.8-rc1`, applies the new patches, fetches the updated `auto-win-msvc`, builds, and runs the tests.
2. **Verify the Release Artifacts:**
   Once CI completes, navigate to the GitHub Releases page for `redis-windows`. Verify that a new release for `8.8-rc1` exists and contains the expected artifacts:
   - `redis-server.exe` / `redis-cli.exe`
   - Windows Installer (`.msi`)
   - Release archive (`.zip`)

By following these steps, we ensure a reproducible, automated process for bringing upstream Redis native Windows compatibility directly to end users.
