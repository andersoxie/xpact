# Fix report: issue #7, "Expected Eiffel link response file not found"

Issue: [#7](https://github.com/andersoxie/xpact/issues/7)   Branch: `fix/7-msvc-c-backend`   Base: `student-Mass` @ `cada501`   Date: 2026-10-20

## Summary

| Item | Value |
|---|---|
| Script | `scripts\build_native_eiffel.ps1`, `tests\xpact_native_library.ecf` |
| Cause | EiffelStudio's configured C backend on this PC is **mingw** (gcc). It writes no `.lnk` link response file, but the script links with MSVC `link.exe` and needs one. |
| Fix | Build the Eiffel target with the **`msc_vc140`** backend, remove the mingw-only precompiled library, and stop harmless stderr messages from aborting native commands. This is the week 1 fix from `student/history/patches/01-week1-build-fixes.patch` (commit `b930600`), for these two files only. |
| Result | `xpact.dll` and `xpact_assertions.dll` build; the Production smoke test passes; exit 0 |

## Expected results (written before testing)

| # | Command | Expected |
|---|---|---|
| 1 | `.\scripts\build_native_eiffel.ps1` (Production tier), fresh process, default PATH | `ec` uses the `msc_vc140` backend, `F_code\xpact_native_library.lnk` exists, `build\native-eiffel\xpact.dll` is built, smoke test prints ok, exit 0 |
| 2 | `.\scripts\build_native_eiffel.ps1 -BuildTier Assertions -SkipSmoke` | `xpact_assertions.dll` is built, exit 0. (The assertions smoke test is skipped because of the known crash at load, week 1 report §4.8.) |
| 3 | `$env:ISE_C_COMPILER` in the calling process after run 2 | Unchanged (empty) |

## Cause

Confirmed by the rerun in #7 (log: [fix-issue-7-before-vswhere-on-path.txt](fix-issue-7-before-vswhere-on-path.txt)):

- `ec` printed "Preparing C compilation using already configured **mingw** C compiler" and compiled every C file with `gcc`.
- `F_code` then held `xpact_native_library.exe` and **no `.lnk`**, so `Get-LinkResponseFile` threw.
- `ISE_C_COMPILER` is not set on this PC (user, machine, process), so EiffelStudio uses its default, mingw.

Two more problems sit on the same path:

- `tests\xpact_native_library.ecf` uses the precompiled library `base-safe`, which only exists for the mingw backend (week 1 report §4.2).
- In a fresh `powershell -File` process, `Invoke-VcCommand` (`cmd.exe /c ... 2>&1` under `$ErrorActionPreference = "Stop"`) turned the harmless `'vswhere.exe' is not recognized` message from `vcvars64.bat` into a fatal error (log: [fix-issue-7-before-fresh-process.txt](fix-issue-7-before-fresh-process.txt), exit 1 after 1 s). That stopped the build before it even reached the `.lnk` step.

## What changed

**`scripts\build_native_eiffel.ps1`**
- `Invoke-VcCommand`: runs `cmd.exe` under `$ErrorActionPreference = "Continue"` and checks `$LASTEXITCODE` instead, so stderr text is printed, not fatal.
- `ec` and `finish_freezing`: run with `$env:ISE_C_COMPILER = "msc_vc140"`, under `Continue`, with explicit exit-code checks. The previous value of `ISE_C_COMPILER` is restored in a `finally` block.
- Smoke executable: same stderr guard.

**`tests\xpact_native_library.ecf`**
- Removed `<precompile name="base_pre" location="$ISE_PRECOMP\base-safe.ecf"/>` from both targets. Full compiles are slower without it, but they work with `msc_vc140`.

Compared with the week 1 patch applied to the original files, the only difference is two added comments (checked with `diff` in a scratch folder).

Why `msc_vc140` and not `msc`: in week 1 the plain `msc` backend failed to link with Visual Studio 18 (unresolved `__iob_func`, `_set_output_format`; report §4.1).

## Not changed here

- `scripts\run_native_runtime_smoke.ps1` and `tests\xpact_native_runtime.ecf` have the same mingw problems and the old `C:\El2502E` fallback. Their fix is also in patch 01, but it belongs to a separate issue.
- `scripts\import_msvc_environment.ps1`: the PATH growth is #4. Its stderr message is printed but did not stop these runs.
- `scripts\run_xmlconf_conformance.ps1` from patch 01: unrelated to this issue.
- The stale `EIFGENs\xpact_native_library\ec.lock` (week 1 report §4.3) was present before run 1 and did **not** stop it, so no lock handling was added.

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/7-msvc-c-backend` (base `cada501` plus this change). EiffelStudio 25.12.9.8922 win64, Visual Studio 18 Community 18.10.3 (MSVC 14.51.36231), Windows PowerShell 5.1. `ISE_EIFFEL` and `ISE_C_COMPILER` not set. Each run was a fresh `powershell -NoProfile -ExecutionPolicy Bypass` process with the default PATH (no Visual Studio Installer folder added).

| # | Command | Before (base `cada501`) | After (this branch) | Exit before → after |
|---|---|---|---|---|
| 1 | `-File scripts\build_native_eiffel.ps1` | Fails at `'vswhere.exe' is not recognized` (fresh process), or at "Expected Eiffel link response file not found" when vswhere is on PATH; no DLL | "Preparing C compilation using already configured **msc_vc140** C compiler"; `F_code\xpact_native_library.lnk` created; "Built ...\build\native-eiffel\xpact.dll (Production)"; "xpact Eiffel DLL smoke: ok" | 1 → **0** (27 s) |
| 2 | `scripts\build_native_eiffel.ps1 -BuildTier Assertions -SkipSmoke` | Not run (fails the same way) | msc_vc140; "Built ...\build\native-eiffel\xpact_assertions.dll (Assertions)" | → **0** (24 s) |
| 3 | `$env:ISE_C_COMPILER` around run 2, in the same process | n/a | `before=[]`, `after=[]`: restored | n/a |

Produced files:

| File | Size | SHA-256 |
|---|---|---|
| `build\native-eiffel\xpact.dll` (Production) | 9,661,440 bytes | `2899b89298d7a6a41832bee3ea16d67571c24866128566dca1f78c3e0db409a1` |
| `build\native-eiffel\xpact_assertions.dll` | 9,716,736 bytes | not recorded |

All three expectations were met.

Notes:
- The `'vswhere.exe' is not recognized` message still appears in the output. It is now printed instead of being fatal. Its cause (vcvars64.bat can't find `vswhere.exe` on PATH) is harmless here and is left alone.
- In the Assertions tier, `F_code` holds `xpact_native_library.lnk` (not `xpact_native_library_assertions.lnk`). `Get-LinkResponseFile` accepts it because it is the only candidate. This was already the case before and is not changed.
- Not tested: the Assertions smoke test (known crash at load, week 1 report §4.8), Finalized test matrix cells, other scripts that use the DLL.

Logs:
- Before: [fix-issue-7-before-fresh-process.txt](fix-issue-7-before-fresh-process.txt), [fix-issue-7-before-vswhere-on-path.txt](fix-issue-7-before-vswhere-on-path.txt)
- After: [fix-issue-7-after-production.txt](fix-issue-7-after-production.txt), [fix-issue-7-after-assertions.txt](fix-issue-7-after-assertions.txt)

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 7 -Commit <merged sha>
```

The build then stops at the `.lnk` error again.
