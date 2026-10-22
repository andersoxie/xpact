# Fix report: issue #53, Workbench lane does not load MSVC, finish_freezing fails with msc_vc140

Issue: [#53](https://github.com/andersoxie/xpact/issues/53)   Branch: `fix/53-workbench-msvc`   Base: `3076a92`   Date: 2026-10-22

## Why

`run_eiffel_test_matrix.ps1` loaded MSVC only when a Finalized lane was
selected. A Workbench lane also runs `finish_freezing` (the test system has
external C code, so `ec` freezes it), and with `ISE_C_COMPILER=msc_vc140` that
needs `cl` and `link`. Without them `finish_freezing` fails with no message,
and the script reports `finish_freezing failed for assertions-off / Workbench`.
First seen in [issue-0028](../issue-0028/report.md#how-the-lanes-were-run).

## Options

| Option | Result |
|---|---|
| Always load MSVC | Breaks the Workbench lane on machines with the default mingw backend and no Visual Studio |
| **Load MSVC for Finalized lanes (as before) or when `ISE_C_COMPILER` is `msc*`** (chosen) | MSVC is there whenever the C backend needs it; the mingw Workbench lane is unchanged |

## What changed

| File | Change |
|---|---|
| `scripts/run_eiffel_test_matrix.ps1` | Imports MSVC when a Finalized lane is selected **or** `$env:ISE_C_COMPILER -like "msc*"` |
| `student/report/setup-guide.md` | Section 3: the manual import is no longer needed for the test matrix; run scripts from the repository root; MSVC needs its own EiffelBase precompile. Section 5: #53 fixed, and how to rebuild the precompile |
| `student/PLAN.md` | Known problems: the Workbench row points to #53 |

## Found while testing (not changed by this fix)

1. **EiffelBase precompile for MSVC was missing on this PC.** With MSVC loaded,
   the first after-run stopped at
   `LNK1181: cannot open input file '...\precomp\spec\win64\EIFGENs\base-safe\W_code\msc_vc140\precomp.lib'`
   (and `VD43` from `ec`). Only `W_code\mingw` existed (built 2026-10-13); the
   #28 run on 2026-10-21 had linked the `msc_vc140` one, so it was removed
   in between, cause unknown. Rebuilt on 2026-10-22: backup of `base-safe` to
   `base-safe.backup-20261022`, `finished` markers deleted in `W_code\C1`-`C30`
   (left by the mingw build, so `nmake` skipped every C file), then
   `finish_freezing` in `W_code` with MSVC loaded and
   `ISE_C_COMPILER=msc_vc140`. Result: `W_code\msc_vc140\precomp.lib`
   (40,639,840 bytes); `W_code\mingw` unchanged. The setup guide has the steps.
2. **The script depends on the current folder.** `ec` writes `EIFGENs` to the
   current folder, but the script looks for `W_code`/`F_code` under the
   repository root. Started from another folder, it skipped `finish_freezing`,
   ran an **old** `EIFGENs\xpact_tests\W_code\xpact_tests.exe` and printed
   `ok`, exit 0: a false pass. To be filed as its own finding. The tests below
   run from the repository root ([run-workbench.ps1](run-workbench.ps1) sets it).

## Verification

Windows PowerShell 5.1, EiffelStudio 25.12.9.8922, Visual Studio 18 Community.
[run-workbench.ps1](run-workbench.ps1) removes Visual Studio from `PATH` and
any loaded MSVC environment, sets `ISE_C_COMPILER` (or removes it), changes to
the repository root and runs
`run_eiffel_test_matrix.ps1 -AssertionMode Off -BuildMode Workbench`. Each run:
`cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File run-workbench.ps1 [-CCompiler msc_vc140] > <log> 2>&1"`.
Rows 1-2 ran after the precompile was rebuilt; row 1 with the script as on `3076a92`.

| # | Run | Expected | Actual | Exit | Log |
|---|---|---|---|---|---|
| 1 | Before, `msc_vc140` | `finish_freezing failed` | `Preparing C compilation using already configured msc_vc140 C compiler...` then `finish_freezing failed for assertions-off / Workbench.` | 1 | [before-msc.txt](before-msc.txt) |
| 2 | After, `msc_vc140` | MSVC loaded, tests pass | `Loaded Visual Studio C++ x64 environment ...`, `xpact Phase 1 tests: ok`, `xpact Eiffel test matrix: ok` | 0 | [after-msc.txt](after-msc.txt) |
| 3 | After, `ISE_C_COMPILER` not set (mingw) | No MSVC import, tests pass as before | no `Loaded Visual Studio` line, `xpact Phase 1 tests: ok` | 0 | [after-default.txt](after-default.txt) |

## How to revert

```powershell
git revert <sha of this commit>
```
