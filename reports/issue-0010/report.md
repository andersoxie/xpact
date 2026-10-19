# Fix report: issue #10, run_native_runtime_smoke.ps1 cannot build

Issue: [#10](https://github.com/andersoxie/xpact/issues/10)   Branch: `fix/10-native-runtime-msvc`   Base: `student-Mass` @ `3b8a205`   Date: 2026-10-20

## Summary

| Item | Value |
|---|---|
| Files | `scripts\run_native_runtime_smoke.ps1`, `tests\xpact_native_runtime.ecf` |
| Cause | Same as #2 and #7. The include fallback pointed to the non-existent `C:\El2502E`. Then the Eiffel smoke program was built with the default **mingw** backend, whose gcc linker can't resolve the MSVC CRT symbols in the `cl`-compiled native objects (`__security_check_cookie`, `__GSHandlerCheck`). |
| Fix | Week 1 fix (`student/history/patches/01-week1-build-fixes.patch`, commit `b930600`) for these two files: 25.12 Standard include fallback, `ISE_C_COMPILER=msc_vc140` around the build (restored afterwards), stderr guards for native commands, `<precompile>` removed from both targets |
| Result | Both cells build and the smoke program prints ok; exit 0 |

## Expected results (written before testing)

| # | Command | Expected |
|---|---|---|
| 1 | `.\scripts\run_native_runtime_smoke.ps1` (both cells), fresh process, `ISE_EIFFEL` and `ISE_C_COMPILER` unset | Include directory found; both cells (assertions-on, assertions-off) are compiled with `msc_vc140`, link, and `xpact_native_runtime.exe` exits 0 for each; script exit 0 |
| 2 | `$env:ISE_C_COMPILER` in the calling process after run 1 | Unchanged (empty) |

## What changed

**`scripts\run_native_runtime_smoke.ps1`**
- `Get-IseInclude`: fallback set to `C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard\studio\spec\win64\include`. `ISE_EIFFEL` still takes priority.
- New `Invoke-NativeCommand`: runs a native command under `$ErrorActionPreference = "Continue"` and returns its exit code, so stderr text (like the `vswhere.exe` message) is printed but not fatal.
- `cl`, `ec`, `finish_freezing` and the smoke `.exe` run through `Invoke-NativeCommand`. `ec` and `finish_freezing` run with `ISE_C_COMPILER=msc_vc140`; the previous value is restored in a `finally` block.

**`tests\xpact_native_runtime.ecf`**
- Removed the mingw-only `<precompile name="base_pre" .../>` from both targets.

Both files are byte-for-byte what the week 1 patch produces from the original files (checked by applying the patch in a scratch folder and running `diff`).

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/10-native-runtime-msvc`. EiffelStudio 25.12.9.8922 win64, Visual Studio 18 Community 18.10.3 (MSVC 14.51.36231), Windows PowerShell 5.1. Fresh `powershell -NoProfile -ExecutionPolicy Bypass` process, default PATH.

| # | Command | Before (`3b8a205`) | After (this branch) | Exit before → after |
|---|---|---|---|---|
| 1 | `scripts\run_native_runtime_smoke.ps1` | "Cannot find Eiffel runtime include directory." | assertions-on: "Preparing C compilation using already configured **msc_vc140** C compiler", "xpact native runtime smoke: ok"; assertions-off: same | 1 → **0** (26 s) |
| 1b | Same, with `ISE_EIFFEL` set (before only) | mingw link fails: `undefined reference to '__security_check_cookie'`, `'__GSHandlerCheck'` | (not needed: the fallback now works) | 1 |
| 2 | `$env:ISE_C_COMPILER` around run 1, same process | n/a | `before=[]`, `after=[]`: restored | n/a |

Both expectations were met.

Not tested: `-AssertionMode On` / `Off` on their own (both cells ran in run 1), a custom `-OutputDir`.

Logs:
- Before: [before-default.txt](before-default.txt), [before-ise-eiffel.txt](before-ise-eiffel.txt)
- After: [after.txt](after.txt)

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 10 -Commit <merged sha>
```
