# Fix report: issue #4, "The input line is too long" after repeated MSVC imports

Issue: [#4](https://github.com/andersoxie/xpact/issues/4)   Branch: `fix/4-msvc-import-path-growth`   Base: `student-Mass` @ `eb6fc5d`   Date: 2026-10-20

## Summary

| Item | Value |
|---|---|
| Script | `scripts\import_msvc_environment.ps1` |
| Cause | Every script dot-sources this file, and every import copied the whole `vcvars64.bat` environment into the session again. PATH grew by 1,432 characters per import until `vcvars64.bat` exceeded cmd.exe's ~8,191-character limit on the 5th import. |
| Fix | Skip the import when an x64 MSVC environment is already loaded, and remove duplicate PATH entries when importing |
| Result | 20 imports in one process all succeed, PATH stays at 2,657 characters; two native builds in one process both succeed |

## Expected results (written before testing)

| # | Command | Expected |
|---|---|---|
| 1 | `issue4-repeat-import.ps1` (dot-sources `scripts\import_msvc_environment.ps1` 20 times in one process) | All 20 imports succeed. PATH grows once on the first import and then stays the same. Imports 2-20 say the environment is already loaded. Exit 0. |
| 2 | Same, on the base commit `eb6fc5d` (before the fix) | Fails on the 5th import with "The input line is too long.", exit 1 (as in #4) |
| 3 | `.\scripts\build_native_eiffel.ps1` twice in one PowerShell process | Both builds succeed (exit 0); the second one does not re-run vcvars64.bat for the import |
| 4 | `cl.exe` and `link.exe` after the import | Found on PATH |

## What changed

`scripts\import_msvc_environment.ps1`:

1. **Skip when already loaded.** If `VSCMD_VER` is set, `VSCMD_ARG_TGT_ARCH` is `x64` and `cl.exe` is on PATH, the script prints "Visual Studio C++ x64 environment already loaded (<version>)" and returns. `return` in a dot-sourced file only leaves that file, so the calling script continues.
2. **De-duplicate PATH.** When the environment is imported, duplicate PATH entries are dropped, ignoring case and trailing `\`, keeping the first occurrence so the order of the remaining entries is unchanged. That also covers importing on top of a different Visual Studio environment, where step 1 doesn't apply.

No caller uses the variables this file sets (`$VcVars`, `$VsRoot`, `$VsWhere`): each script finds `vcvars64.bat` with its own `Get-VcVars` function. So skipping the import is safe for the 6 scripts that dot-source it (`build_native_eiffel.ps1`, `run_eiffel_test_matrix.ps1`, `run_native_runtime_smoke.ps1`, `run_benchmarks.ps1`, `run_contributed_examples.ps1`, `run_large_xml_benchmarks.ps1`).

The same approach already existed in another local copy (`xpactVsCode\xpact\scripts\import_msvc_environment.ps1`). This version also checks the target architecture.

## Not changed here

- Scripts that run `vcvars64.bat` again for each `cl`/`link` call (`Invoke-VcCommand` and similar) still do so, in a child `cmd.exe`. That no longer grows the session's PATH, and it starts from the now-bounded PATH (2,657 + ~1,430 characters, well under the limit).
- The harmless `'vswhere.exe' is not recognized` message from `vcvars64.bat` on the first import is unchanged.

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/4-msvc-import-path-growth`. Visual Studio 18 Community 18.10.3 (MSVC 14.51.36231), EiffelStudio 25.12.9.8922, Windows PowerShell 5.1. Each test in a fresh `powershell -NoProfile -ExecutionPolicy Bypass` process; PATH length 1,335 at the start.

| # | Command | Before (`eb6fc5d`) | After (this branch) | Exit before → after |
|---|---|---|---|---|
| 1, 2 | `-File fix-issue-4-repeat-import.ps1` (20 imports in one process) | PATH 1,335 → 2,767 → 4,199 → 5,631 → 7,063; **import 5 fails**: "The input line is too long." | PATH 1,335 → **2,657** after import 1, unchanged for imports 2-20 ("already loaded (18.0)") | 1 → **0** |
| 3 | `.\scripts\build_native_eiffel.ps1` twice in one process | not run | Build 1 imports (PATH 2,657), build 2 prints "already loaded"; both print "Built ...\xpact.dll (Production)" and "xpact Eiffel DLL smoke: ok"; PATH 2,657 at the end | → **0** (49 s) |
| 4 | `Get-Command cl.exe, link.exe` after 20 imports | n/a | `...\MSVC\14.51.36231\bin\HostX64\x64\cl.exe` and `...\link.exe` (the MSVC linker, not Git's `link`) | n/a |

All four expectations were met. The first import's PATH is 110 characters shorter than before (2,657 vs 2,767) because duplicate entries are removed.

Not tested: the other 5 scripts that dot-source the import; `run_eiffel_test_matrix.ps1 -BuildMode Finalized` is the most common one.

Logs:
- Before: [before-repeat-import.txt](before-repeat-import.txt)
- After: [after-repeat-import.txt](after-repeat-import.txt), [after-two-builds.txt](after-two-builds.txt)
- Test script: [repeat-import.ps1.txt](repeat-import.ps1.txt)

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 4 -Commit <merged sha>
```

Workaround after a revert: run each script in a new PowerShell window.
