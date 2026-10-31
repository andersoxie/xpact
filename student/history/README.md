# Work before this repository (weeks 1–2)

This work was done in `Desktop\xpact-student-test`, a checkout without git, from
September to 2026-10-15. It is copied here so nothing is lost.

| File | What it is |
|---|---|
| [`xpact-error-report.md`](xpact-error-report.md) | Consolidated error report: 21 issues, from build environment problems to conformance, with status |
| [`xpact-error-report-shorter.md`](xpact-error-report-shorter.md) | A shorter version of the same report |
| [`BUILD_FIX_NOTES.txt`](BUILD_FIX_NOTES.txt) | How the native DLL build was fixed (msc_vc140 backend, precompile, `ec.lock`, stderr guards) |
| `firstReport.odt` | The first version of the error report (2026-10-13) |
| [`xpact-investigation-report-2026-10-13.md`](xpact-investigation-report-2026-10-13.md) | Investigation and progress report of 2026-10-13 (architecture, environment, errors, first test results), with a note on where each problem stands now |
| [`patches/01-week1-build-fixes.patch`](patches/01-week1-build-fixes.patch) | Commit `b930600` (2026-10-14): `msc_vc140` backend and stderr guards in `build_native_eiffel.ps1`, `import_msvc_environment.ps1` and `run_native_runtime_smoke.ps1`; mingw-only precompile removed from two ECFs; adds `run_xmlconf_conformance.ps1` |
| [`patches/02-week2-runner-changes.patch`](patches/02-week2-runner-changes.patch) | Uncommitted week 2 changes: `run_xmlconf_conformance.ps1` downloads the pinned W3C ZIP and runs `finish_freezing`; stderr guard in `run_eiffel_test_matrix.ps1` |

The branches that held `b930600` (`student-test`, `Mass-test-workbench`) were
deleted from GitHub, so these patches are now the only copy outside the Desktop folder.

## Status of the patches (2026-10-20)

The patches are kept as the record of the week 1–2 fixes. Do **not** `git apply`
them on `student-Mass`: most of patch 01 is already there, so it would conflict.

| Patch part | Status |
|---|---|
| 01: include fallback, `msc_vc140` backend, stderr guards, no precompile in `build_native_eiffel.ps1` / `xpact_native_library.ecf` | On `student-Mass`: #2 (`9eb18bd`), #7 (`eb6fc5d`) |
| 01: the same in `run_native_runtime_smoke.ps1` / `xpact_native_runtime.ecf` | On `student-Mass`: #10 (`20e6bc3`) |
| 01: stderr guard in `import_msvc_environment.ps1` | Not applied; the import's stderr message is printed but no longer stops a run. #4 (`3b8a205`) changed the same file to stop PATH growth |
| 01: new `run_xmlconf_conformance.ps1` | **Not in git yet** |
| 02: pinned W3C download, `finish_freezing`, test-matrix stderr guard | **Not in git yet** |

*Update 2026-10-21:* the W3C suite no longer needs `run_xmlconf_conformance.ps1`
or the pinned download from patch 02: `scripts/run_w3c_conformance.py` (already
on `student-Mass`) downloads and checks the ZIP itself. See
[`results/w3c-conformance-2026-10-21/`](../results/w3c-conformance-2026-10-21/README.md) (#29).
The test-matrix stderr guard from patch 02 is still missing.

Bring each missing part in through its own issue with
[`VERSIONING.md`](../VERSIONING.md), in the clone
`C:\xpact\xpact-student-Mass`. The fix reports are indexed in
[`reports/README.md`](../../reports/README.md).
