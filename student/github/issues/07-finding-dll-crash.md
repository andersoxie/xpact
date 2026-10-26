---
title: "Finding: assertions-tier DLL smoke test crashes (0xC0000028, earlier 0xC0000008)"
labels: group:B-reliable-results, D3-advanced, P1, type:finding
milestone: Week 2 - Baseline
---
## Steps to reproduce
1. `.\scripts\build_native_eiffel.ps1 -BuildTier Assertions` (smoke test on, **without** `-SkipSmoke`)

## Expected
The DLL builds and the smoke test passes.

## Actual
In the baseline from 2026-10-14, the DLL built, but the smoke test crashed with exit code `-1073741784` = `0xC0000028` STATUS_BAD_STACK. Earlier notes recorded `0xC0000008` STATUS_INVALID_HANDLE, so the crash code is not stable. CI hides this with `-SkipSmoke`.

## Logs
Original log: `student/baseline/logs/assertions-dll.log` (0xC0000028). The earlier 0xC0000008 is in `student/history/BUILD_FIX_NOTES.txt` and in the error report, section 4.8.
Attach `assertions-dll.log` from a rerun in this checkout, and record the exit code of several runs.

## Update 2026-10-22
Rebuilt in a separate worktree with only the B03 change (#3): the DLL builds, and the smoke test **still** crashes with `-1073741784` (`0xC0000028`) ([build log](../../results/dll-tests-2026-10-22/assertions-b03fix/build.log)). So B03 is not the only cause. Other contract failures that reach the DLL are #28 (CR, no callbacks) and #40 (chunk ends with `<`); which one the smoke test hits is **unknown**. Through the C API, a contract failure ends the process with `0xC0000409` after an Eiffel runtime panic ("main entry point vanished").

## Resolved 2026-10-26

Fixed in PR [#80](https://github.com/andersoxie/xpact/pull/80) (issue [#79](https://github.com/andersoxie/xpact/issues/79), K3). Verified in [#104](https://github.com/andersoxie/xpact/issues/104) on `student-Mass` @ `41731c8`, student PC, EiffelStudio 25.12, MSVC (`msc_vc140`): `.\scriptsuild_native_eiffel.ps1 -BuildTier Assertions` builds `xpact_assertions.dll` and prints `xpact Eiffel DLL smoke: ok`, exit 0 ([log](../../../reports/issue-0104/logs/03-dll-assertions.txt)). The C# DLL tests on the same DLL: 3,360/3,360, 0 crashes. Not filed as a separate issue; tracked through #79.
