# Release Plan: Redis 8.10.1 for Windows (MSVC)

This document outlines the systematic process to bring the recent local fixes from `..\auto-win-msvc` and `..\redis` into this repository (`redis-windows`), verify that all tests pass natively on Microsoft Windows running MSVC for the `8.10.1` tag, and cut a new tagged release with the resulting executables and packages.

## [x] Phase 1: Publish `auto-win-msvc` Updates
Our native MSVC build relies on the `auto-win-msvc` POSIX compatibility layer. Recent fixes in the local clone need to be published so the `redis-windows` build system can pull them dynamically during the build process.

- [x] **Commit & Push Local Changes:**
   Ensure all working files in `..\auto-win-msvc` are committed and pushed to `origin/master`. This ensures the automated build has the latest compatibility fixes required for 8.10.1.

## [x] Phase 2: Extract 8.10.1 Patches from Local `redis`
The local `..\redis` repository has all tests successfully passing natively on Windows for Redis 8.10.1. We need to extract these code adjustments and test workarounds as reusable patches.

- [x] **Generate Unified Diffs:**
   In `..\redis`, generate clean patches comparing the local working branch against the standard `8.10.1` tag. 
   *(Note: Exclude changes to the `cmake/` folder as those are managed via our overlays).*
- [x] **Update the Patches Directory:**
   Copy the generated patch(es) into `redis-windows\patches\`. This replaces any old patches and ensures clean application over vanilla Redis 8.10.1.

## [x] Phase 3: Sync the CMake Overlays
The `redis-windows` repository injects its own `cmake/` folder on top of the upstream source. 

- [x] **Sync CMake Files:**
   Copy the updated `cmake/` directory from the working `..\redis` repository into `redis-windows\overlay\cmake\`.
- [x] **Sync Test Overlays:**
   If there were modifications to Tcl scripts (like `exec_override.tcl`) in `..\redis` to get the tests passing, ensure those are copied to the appropriate location under `redis-windows\overlay\`.

## [x] Phase 4: Clean Local Verification
Before publishing, we must verify that our extracted patches and overlays apply cleanly to a fresh checkout of Redis 8.10.1 and pass all tests.

- [x] **Test the Build Flow:**
   Check out `8.10.1` upstream in a temporary location, apply the contents of `overlay\`, apply the scripts in `patches\`, and configure with CMake.
- [x] **Validate Tests:**
   Compile with MSVC and run the test suite (`ctest` or Tcl tests) locally to confirm 100% test success on Windows, ensuring no regressions.

## [x] Phase 5: CI/CD Pipeline and Tagging
Once the local build and tests are verified, we update the main repository and trigger the release pipeline.

- [x] **Commit to `redis-windows`:**
   Stage all updated files in `patches\`, `overlay\`, and `PLANNN.md`. Commit these changes.
- [x] **Tag the Release:**
   Tag the repository to match the upstream version:
   ```cmd
   git tag 8.10.1
   git push origin 8.10.1
   ```

## Phase 6: Release and Packaging Validation
Pushing the `8.10.1` tag will automatically trigger the `.github/workflows/release.yml` GitHub Actions pipeline.

1. **Monitor the CI Pipeline:**
   Watch the GitHub Actions run to ensure it correctly checks out `8.10.1`, applies the updated patches/overlays, builds with MSVC, and packages the results.
2. **Verify Release Artifacts:**
   Once the pipeline completes, navigate to the GitHub Releases page for `redis-windows`. Verify that the `8.10.1` release contains:
   - `redis-server.exe` / `redis-cli.exe`
   - Windows Installer (`.msi`)
   - Release archive (`.zip`)
