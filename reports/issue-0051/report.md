# Fix report: issue #51, import_msvc_environment.ps1 stops on "'vswhere.exe' is not recognized"

Issue: [#51](https://github.com/andersoxie/xpact/issues/51)   Branch: `fix/51-vswhere-path`   Base: `2960f6c`   Date: 2026-10-22

## Why

`vcvars64.bat` calls `vswhere.exe` by name. `vswhere.exe` lives in
`C:\Program Files (x86)\Microsoft Visual Studio\Installer`, which is normally
not on `PATH`, so `vcvars64.bat` prints `'vswhere.exe' is not recognized as an
internal or external command` to stderr. When the caller captures the output,
Windows PowerShell 5.1 with `$ErrorActionPreference = "Stop"` turns that line
into a `NativeCommandError` and `import_msvc_environment.ps1` stops at the
`cmd.exe` call. Every script that loads MSVC through it
(`build_native_eiffel.ps1`, `run_eiffel_test_matrix.ps1`,
`run_native_runtime_smoke.ps1`) stopped the same way. The workaround was a
manual first line in the setup guide.

The script already knew where `vswhere.exe` is (`$VsWhere`, used to find
Visual Studio), but did not give that folder to `vcvars64.bat`.

## Options

| Option | Result |
|---|---|
| Keep the manual `PATH` line in the setup guide | Every new terminal needs it; easy to forget, and it fails with a misleading message |
| Run `vcvars64.bat` with `$ErrorActionPreference = "Continue"` | Hides the message but also any real error on stderr |
| **Add the Installer folder to `PATH` inside the `cmd.exe` call** (chosen) | `vcvars64.bat` finds `vswhere.exe`, nothing is written to stderr. The folder is appended, so it changes no other lookup |

## What changed

| File | Change |
|---|---|
| `scripts/import_msvc_environment.ps1` | `cmd.exe` runs `set "PATH=%PATH%;<Installer folder>"` before `vcvars64.bat` |
| `student/report/setup-guide.md` | Section 3: manual `PATH` line removed; problems table points to #51. Also step 2 of section 4 now says the finalized lane fails like step 1, as it does since #48 |
| `student/PLAN.md` | Workaround note: the `vcvars64.bat` workaround is fixed by #51 |

## Verification

Windows PowerShell 5.1, Visual Studio 18 Community (vcvars 18.10.3).
[repro.ps1](repro.ps1) removes the Installer folder from `PATH` and any loaded
MSVC environment, then dot-sources `import_msvc_environment.ps1` with its
output captured (`*>&1`), as a calling script does.
[repro-twice.ps1](repro-twice.ps1) loads it three times in one session.
Each was run as `cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File <script> > <log> 2>&1"`.

| # | Run | Expected | Actual | Exit | Log |
|---|---|---|---|---|---|
| 1 | Before: `repro.ps1` | Stops on `'vswhere.exe' is not recognized` | `NativeCommandError` at `import_msvc_environment.ps1:32` | 1 | [before.txt](before.txt) |
| 2 | After: `repro.ps1` | MSVC loaded, `cl.exe` found | `Loaded Visual Studio C++ x64 environment ...`, `cl.exe: ...\14.51.36231\bin\HostX64\x64\cl.exe` | 0 | [after.txt](after.txt) |
| 3 | After: `repro-twice.ps1` | Run 1 loads, runs 2-3 skip, `PATH` does not grow (#4) | Run 1 loaded; runs 2-3 `already loaded (18.10.3)`; `PATH` length 2579 each time | 0 | [after-repeated.txt](after-repeated.txt) |

## How to revert

```powershell
git revert <sha of this commit>
```
