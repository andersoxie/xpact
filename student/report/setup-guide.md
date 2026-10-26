# Setup guide: build xpact and run the assertions-enabled tests on Windows

For a developer who has a Windows PC and a clone of this repository, and wants
to reproduce the builds and tests used in the student project. Tested on
2026-10-22 (task A02, [#33](https://github.com/andersoxie/xpact/issues/33));
the results of that run are in
[`../results/A02-baseline/`](../results/A02-baseline/README.md).

> **Updated 2026-10-26** ([#113](https://github.com/andersoxie/xpact/issues/113)): the student PC was brought closer to the
> supervisor's Jenkins machine (MSVC backend, Python 3.14, long paths); every test
> passed afterwards ([report](../../reports/issue-0113/report.md)).

## 1. Install the tools

| Tool | Student PC (2026-10-26) | Supervisor / Jenkins | Notes |
|---|---|---|---|
| Windows | 11 Home, 64-bit | 11, 64-bit | |
| EiffelStudio | 25.12.9.8922 Standard, win64 | ⚠️ **25.02.9.8723 Enterprise** (`C:\El2502E`) | Puts `ec` and `finish_freezing` on `PATH` |
| Visual Studio | Community 2026 (18.10), MSVC 14.51 (`cl` 19.51.36260) | ⚠️ **2022 Build Tools, `cl` 19.44.35229** | Install the workload **Desktop development with C++** (component `VC.Tools.x86.x64`). Build Tools alone are enough |
| Git | 2.55 | 2.43 | `core.longpaths true` (section 2b) |
| Windows PowerShell | 5.1 (built in) | 5.1 | All scripts run in it. See section 5 for its quirks |
| Python | **3.14.0** (per user, first on `PATH`) | 3.14.0 | **3.11 or newer**: the implementation-build scripts and their tests use `hashlib.file_digest` (3.11+). 3.10 fails 102 of 178 Python tests ([#104](../../reports/issue-0104/report.md)) |
| GitHub CLI (`gh`) | 2.102 | - | Only for issues, pull requests and the project board (scopes `repo`, `project`) |
| CMake | Visual Studio's copy, after the MSVC import | 4.3.3 | Only for the libexpat lanes |

⚠️ = still different on purpose: the student decided on 2026-10-26 to keep
these versions and record the difference. No result so far has depended on
them; if a result ever differs from Jenkins, compare on Jenkins first.

`gh` on the student PC is not on `PATH`; its location (and the other tools') is in
[`../README.md`](../README.md) ("Tools on this PC").

## 2. Set the Eiffel C backend once

EiffelStudio compiles Eiffel to C and then calls a C compiler. The default on
Windows is **mingw**, which cannot link with the MSVC-built parts of xpact.
Use the MSVC backend `msc_vc140`:

```powershell
[Environment]::SetEnvironmentVariable("ISE_C_COMPILER", "msc_vc140", "User")
```

Open a new terminal afterwards. `build_native_eiffel.ps1` and
`run_native_runtime_smoke.ps1` set it themselves (#7, #10); the test matrix
does not, so without this setting the matrix still uses mingw.

Check it: `[Environment]::GetEnvironmentVariable("ISE_C_COMPILER","User")`.
On the student PC it was set on 2026-10-22 (A02), found **missing** on
2026-10-26 (how it was removed is unknown; no script in the repository does it)
and set again ([#113](https://github.com/andersoxie/xpact/issues/113)). A matrix log shows the backend in the line
`Preparing C compilation using already configured ... C compiler`.

## 2b. Allow long paths once

Some Python tests build paths longer than 260 characters, more so in a
deep working folder:

```powershell
git config --global core.longpaths true
# in PowerShell as Administrator:
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
```

Without it, `test_implementation_builds.py` fails with
`[WinError 3] The system cannot find the path specified` (15 problems in the
deep folder `C:\Users\masou\Desktop\Lia\xpact3.0\...`, 2 in the shorter clone
path). With it, all 178 Python tests pass ([#113](https://github.com/andersoxie/xpact/issues/113)).

## 3. Prepare each terminal

From the repository root:

```powershell
cd C:\xpact\xpact-student-Mass
. .\scripts\import_msvc_environment.ps1
```

- The import puts the Visual Studio Installer folder (`vswhere.exe`) on `PATH`
  for `vcvars64.bat` itself (#51); it no longer has to be added by hand.
- It loads the MSVC compiler (`cl`, `link`) for commands you run by hand
  (`ec`, `finish_freezing`, `cl`). The scripts load it themselves;
  `run_eiffel_test_matrix.ps1` also for workbench lanes when `ISE_C_COMPILER`
  is `msc*` (#53). Running the import twice is safe (#4).
- `run_eiffel_test_matrix.ps1` switches to the repository root itself (#55).
  For `ec` commands you run by hand, start in the repository root: `ec` writes
  `EIFGENs` to the current folder.
- With `msc_vc140`, EiffelBase must also be precompiled for MSVC:
  `...\Eiffel User Files\25.12\precomp\spec\win64\EIFGENs\base-safe\W_code\msc_vc140\precomp.lib`.
  If only `W_code\mingw` exists, workbench builds stop with `LNK1181` (see
  section 5).

## 4. Build and test

The student project uses **assertions-enabled** builds (guide, "Your role").

| # | Command | What it does | Expected on 2026-10-22 |
|---|---|---|---|
| 1 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Workbench` | Compiles `tests\xpact_tests.ecf` target `xpact_tests_assertions` (workbench) and runs `xpact_tests.exe` | Fails, exit 1: the #28 regression test catches the CR bug |
| 2 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Finalized` | Same, finalized (with `-keep` since #48) | Fails like 1 |
| 3 | `ec -batch -clean -finalize -keep -config tests\xpact_tests.ecf -target xpact_tests_assertions`, then `finish_freezing` in `EIFGENs\xpact_tests_assertions\F_code`, then `xpact_tests.exe` there | The finalized lane that really checks contracts | Fails like 1 |
| 4 | `.\scripts\run_native_runtime_smoke.ps1 -AssertionMode On` | Eiffel native runtime smoke test | `xpact native runtime smoke: ok` |
| 5 | `.\scripts\build_native_eiffel.ps1 -BuildTier Assertions` | Builds `build\native-eiffel\xpact_assertions.dll` and runs its C smoke test | DLL builds; the smoke test crashes (K3) |
| 6 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode Off -BuildMode Workbench` | The assertions-off lane, for comparison | `xpact Phase 1 tests: ok` |

Or run 1-5 at once, with a log per step:

```powershell
.\student\baseline\run_baseline.ps1 -LogDir student\results\<folder> `
    -Step environment,event-trace,matrix-workbench,matrix-finalized,matrix-finalized-keep,native-runtime-smoke,assertions-dll
```

Leave out the `xmlconf` step: its script was never brought into git. Run the
W3C suite with the Python runner instead, as in
[`../results/w3c-conformance-2026-10-21/`](../results/w3c-conformance-2026-10-21/README.md).

Python harness tests (no EiffelStudio needed):

```powershell
python -m unittest discover -s tests/python -p test_w3c_conformance.py
```

A command finishing is not proof that the tests passed. Check the exit code
(`$LASTEXITCODE`) and read the end of the output.

## 5. Problems and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `'vswhere.exe' is not recognized` and the script stops | Visual Studio Installer folder not on `PATH`; PowerShell 5.1 turns stderr into an error | Fixed in #51 |
| `finish_freezing failed for assertions-on / Workbench`, no other message | MSVC not loaded, `ISE_C_COMPILER=msc_vc140` | Fixed in #53 |
| `LNK1181: cannot open input file '...\base-safe\W_code\msc_vc140\precomp.lib'` | EiffelBase is precompiled only for mingw | Back up `EIFGENs\base-safe`, delete the `finished` files in its `W_code\C*` folders, then run `finish_freezing` in `W_code` with MSVC loaded and `ISE_C_COMPILER=msc_vc140` (done 2026-10-22, [issue-0053](../../reports/issue-0053/report.md)) |
| A script stops at `ec.exe : Eiffel Compilation Manager` / `NativeCommandError` | You captured its output inside PowerShell (`*>&1`, `| Out-File`); PowerShell 5.1 then treats `ec`'s stderr as fatal | Run without redirection, or let `cmd` write the log: `cmd /c "powershell -NoProfile -File scripts\... > log.txt 2>&1"` |
| `Expected Eiffel link response file not found` | mingw backend (no `.lnk` file) | Fixed in #7; set `ISE_C_COMPILER` (section 2) |
| `The input line is too long` | `PATH` grew with every MSVC import | Fixed in #4; open a new terminal |
| `Cannot create project directory ... fixing the permissions` | Stale `EIFGENs\<target>\ec.lock` after an interrupted build | Delete that `ec.lock` |
| `_csv.Error: need to escape` in the Python tests | Python 3.10 | Fixed in #32 |
| `AttributeError: module 'hashlib' has no attribute 'file_digest'` (many Python tests) | Python 3.10 | Use Python 3.11 or newer (section 1) |
| `shutil.Error ... [WinError 3] The system cannot find the path specified` in `test_implementation_builds.py` | Windows long paths off | Section 2b |
| `fix.ps1` stops on "Already on 'student-Mass'" | PowerShell 5.1 and git's stderr | Do its steps by hand ([VERSIONING.md](../VERSIONING.md)) |

## 6. Known failures (not setup problems)

These fail on a correct setup. Do not try to fix them by changing the build:

- **#28**: any CR byte breaks a loop variant in `XP_PARSER.normalized_input`
  (assertions on). Caught by `test_cr_line_ends_with_deferred_positions`.
- **#3 (B03)**: postcondition `final_finished_or_suspended` in
  `test_garbage_collection_suspension`. Fix in draft pull request #12.
- **K3**: the assertions-DLL smoke test crashes (`0xC0000028` and other codes).
- The test runner stops at the first failure, so tests after it do not run
  (draft 06).
