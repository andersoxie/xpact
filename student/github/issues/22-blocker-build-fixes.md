---
title: "Blocker: Windows build fixes (msc_vc140 backend, stderr guards) are not in main"
labels: group:A-orientation, D2-guided, P0, type:blocker
milestone: Week 2 - Baseline
---
> **Update 2026-10-20:** the build fixes are now on `student-Mass` as #2 (`9eb18bd`), #7 (`eb6fc5d`) and #10 (`20e6bc3`), and the build works there. Still open: they are not in `main`, and `run_xmlconf_conformance.ps1` plus patch 02 are not in git. Ask the supervisor whether to open a pull request into `main`.

## Steps to reproduce
1. Fresh clone of `main` on a Windows PC where EiffelStudio's default C backend is mingw (`ISE_C_COMPILER` empty).
2. `.\scripts\build_native_eiffel.ps1`, or `.\scripts\run_native_runtime_smoke.ps1`

## Expected
The native DLL and the runtime smoke test build.

## Actual
Weeks 1–2: "Expected Eiffel link response file not found … xpact_native_library.lnk", "Cannot find Eiffel runtime include directory", and gcc `ld` failing on `__security_check_cookie` / `__GSHandlerCheck`. These were fixed in commit `b930600` (2026-10-14) on the former `student-test` / `Mass-test-workbench` branches. **Both branches have since been deleted from GitHub**, so `main` still has the problems.

## Logs
- Fix description: `student/history/BUILD_FIX_NOTES.txt`, `student/history/xpact-error-report.md` (sections 3–4)
- Patches: `student/history/patches/01-week1-build-fixes.patch` (from `b930600`) and `02-week2-runner-changes.patch`. Both apply cleanly to `main` @ `fee611a`.

## Proposed next step
Ask the supervisor whether these fixes should go to `main` through a pull request, or stay local to this PC. Until then, apply the patches locally (`git apply`) before building. Also: derive the EiffelStudio path from `ISE_EIFFEL` instead of a hard-coded fallback (`C:\El2502E\...`).
