# #319 · Runners rebuild the tested DLL without saying so

| | |
|---|---|
| Status | ✅ fixed and checked locally (2026-11-11) · 🟡 a full build with the new hash lines not run (see Verification) |
| Issue | [#319](https://github.com/andersoxie/xpact/issues/319) |
| Files | `scripts/build_native_eiffel.ps1`, `README.md`, `student/VERSIONING.md` |

## 1. Problem

CLAUDE.md: "build once, test many … never let a runner rebuild". A scan of all 53 scripts outside `docs/` (2026-11-11) found these call `scripts\build_native_eiffel.ps1` **by default** and so replace `build\native-eiffel\xpact.dll` / `xpact_assertions.dll`:

| Script | Skip flag |
|---|---|
| `scripts/run_benchmarks.ps1` | `-UseExistingNativeDll` (or `-SkipBuild`) |
| `scripts/run_large_xml_benchmarks.ps1` | `-SkipBuild` |
| `scripts/run_chunked_crc_harness.ps1` | `-SkipBuild` |
| `scripts/run_incremental_shim_audit.ps1` | `-SkipBuild` |
| `scripts/run_libexpat_adapter.ps1` | `-SkipNativeBuild` |
| `scripts/package_windows_release.ps1` | `-SkipBuild` |
| `website/scripts/build-dll.ps1` | none (its job) |
| `student/baseline/run_baseline.ps1` | none (builds the assertions DLL on purpose) |

Other default side effects found in the same scan (unchanged, now listed in `README.md`):

- `run_benchmarks.ps1` rewrites `docs\benchmarks.md` unless `-NoDocsUpdate` (#302).
- `run_large_xml_benchmarks.ps1` rewrites `docs\large-xml-benchmarks.md` unless `-NoPublishDocs`.
- `run_w3c_conformance.py` downloads the pinned W3C suite zip into its cache when it is not there yet (checked on every reuse too); no download when a suite directory is given.
- `website/scripts/dev.ps1` runs `npm install` when `node_modules` is missing.

- **Environment:** student PC, Windows 11, PowerShell 5.1, `incremental-test` @ `79c1843`.
- **Cause:** ✅ confirmed by reading the scripts: each runner was written to be self-contained.

## 2. Fix

Defaults of the runners are not changed (that would break the documented commands). Instead, in the one script all of them call:

- `build_native_eiffel.ps1` prints `replaces <dll>; SHA-256 before: …` at the start and `before: …, after: …` at the end.
- With `XPACT_FROZEN_DLL` set (not `0`) it stops at once with an error that names the skip flags. Runners start it as a child process, which inherits the variable, so a forgotten skip flag fails fast instead of replacing the DLL.

## Verification

| Check | Command | Result |
|---|---|---|
| Syntax | `[Parser]::ParseFile("scripts\build_native_eiffel.ps1", …)` | ✅ 0 errors |
| Guard, direct | `$env:XPACT_FROZEN_DLL='1'; powershell -File scripts\build_native_eiffel.ps1` | ✅ exit 1, "XPACT_FROZEN_DLL is set: refusing to rebuild …" |
| Guard, through a runner | same variable, `powershell -File scripts\run_incremental_shim_audit.ps1 -OutputDir build\tmp-319-audit` | ✅ exit 1 after 6 s, the message is in the build log |
| DLL untouched | `Get-FileHash build\native-eiffel\xpact.dll` before and after | ✅ `ADAE03D27775…` both times |

Not run: a full build to see the new hash lines (it would replace the tested DLL `ADAE03D2…`). They are plain `Write-Host` lines using the same `Get-DllHash` function the guard used above.
