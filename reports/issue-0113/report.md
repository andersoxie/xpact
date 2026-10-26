# Report: issue #113, student PC environment changes of 2026-10-26

Issue: [#113](https://github.com/andersoxie/xpact/issues/113)   Branch: `fix/113-pc-environment`   Date: 2026-10-26

## In short

| | |
|---|---|
| 🔍 Found | The #104 check showed the test matrix and W3C were built with **MinGW gcc**, not MSVC: `ISE_C_COMPILER` had disappeared from the PC. Python 3.10 and Windows long paths caused all Python test failures |
| 🎯 Goal | The student asked for the same setup as the supervisor (`main` / Jenkins) |
| 🔧 Changed | MSVC backend (`msc_vc140`), Python 3.14.0, git `core.longpaths`, Windows long paths |
| ✅ Result | Matrix 4/4 and W3C 1,727/1,727 **with MSVC**; **all 178 Python tests pass** (were 102 problems with 3.10, 15 with long paths off) |
| ⚠️ Still different, by decision | EiffelStudio 25.12 Standard vs 25.02 Enterprise; MSVC 19.51 vs 19.44 |

## 1. Problem

| | |
|---|---|
| What went wrong | Today's matrix and W3C results (#104) came from MinGW gcc builds, while Jenkins builds with MSVC; and 102 of 178 Python tests failed |
| Environment | student PC, Windows 11, EiffelStudio 25.12.9.8922 Standard, VS 2026 (MSVC 19.51.36260) |
| Evidence | #104 logs: `Preparing C compilation using already configured mingw C compiler` in every matrix lane; `AttributeError: module 'hashlib' has no attribute 'file_digest'`; `[WinError 3] The system cannot find the path specified` |
| Cause | ✔ `ISE_C_COMPILER` not set (the setup guide sets it; the A02 baseline of 2026-10-22 recorded it as set; **why it disappeared is unknown**, no script in the repository removes it). ✔ Python 3.10 (`hashlib.file_digest` is 3.11+). ✔ Windows long paths off (confirmed below) |

## 2. The supervisor's setup

Taken from `main`: `docs/dual-w3c-lane.md`, `docs/dual-catalog-lane.md`,
`docs/benchmarks.md`, `docs/implementation-builds.md`, and the Jenkins log of
2026-10-23 ([`../issue-0073/jenkins-log-2026-10-23.txt`](../issue-0073/jenkins-log-2026-10-23.txt)).
The Jenkinsfiles set no Eiffel or Python variables; the machine's own setup is used.

| Setting | Supervisor | Student PC before | Student PC after | |
|---|---|---|---|---|
| Eiffel C backend | MSVC (`msc_vc140` in the implementation-build runner; Jenkins' own value not written anywhere) | not set → MinGW gcc | **`msc_vc140`** (user variable) | ✅ |
| Python | 3.14.0 | 3.10.6 (3.13 also installed) | **3.14.0**, first on the user `PATH` | ✅ |
| git `core.longpaths` | `true` (set by his scripts per command) | not set | **`true`** (global) | ✅ |
| Windows long paths | not documented | `LongPathsEnabled = 0` | **1** (set by the student as administrator) | ✅ |
| EiffelStudio | 25.02.9.8723 Enterprise, `C:\El2502E` | 25.12.9.8922 Standard | unchanged | ⚠️ |
| MSVC | 19.44.35229, VS 2022 Build Tools | 19.51.36260, VS 2026 | unchanged | ⚠️ |
| CMake | 4.3.3 on `PATH` | Visual Studio's copy after the MSVC import | unchanged | ⚠️ |

## 3. What was done

| # | Command | Note |
|---|---|---|
| 1 | `[Environment]::SetEnvironmentVariable("ISE_C_COMPILER", "msc_vc140", "User")` | as in the setup guide |
| 2 | `git config --global core.longpaths true` | |
| 3 | Python 3.14.0 from `https://www.python.org/ftp/python/3.14.0/python-3.14.0-amd64.exe`, SHA-256 `52ceb249f65009d936e6504f97cce42870c11358cb6e48825e893f54e11620aa`, Authenticode signature **valid** (Python Software Foundation); installed with `/quiet InstallAllUsers=0 PrependPath=0 Include_launcher=0 Include_test=0 Shortcuts=0` | per user, no administrator |
| 4 | user `PATH`: `Python314\Scripts`, `Python314`, then `Python313`, then `Python310` | 3.13 and 3.10 kept |
| 5 | `New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force` | run by the student in an administrator PowerShell |

**Why the exact versions were not installed.** Build 25.02.9.**8723** is not
published (eiffel.com's stable channel has rev 98732, SourceForge has no 25.02),
Enterprise needs a licence, and the build scripts always choose the newest
Visual Studio (`vswhere -latest`), so installing VS 2022 next to VS 2026 would
change nothing without uninstalling VS 2026 or changing the scripts. No problem
so far was caused by these versions (all were settings: paths, backend, Python
minimum, long paths, `-keep`), so the student decided to keep them and record
the difference. If a result ever differs from Jenkins, compare on Jenkins first.

## 4. Expected results (written before each run)

| # | Check | Expected |
|---|---|---|
| 1 | Matrix, all lanes, `ISE_C_COMPILER=msc_vc140` | 4 × ok, built with `msc_vc140`, not mingw |
| 2 | W3C, both finalized builds, same setting | 1,727 passed, 0 failed |
| 3 | Python tests, 3.14, long paths on, in the deep `xpact3.0` folder | all pass (the 15 problems of #104 gone) |

## 5. Verification

| # | Command | Actual | Exit | Log |
|---|---|---|---|---|
| 1 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All` (on `41731c8`) | 4 × `xpact Phase 1 tests: ok`; **4 builds with `msc_vc140`, 0 with mingw** | 0 | [matrix-msvc.txt](logs/matrix-msvc.txt) |
| 2 | `.\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -SkipWslC` (on `41731c8`) | both builds **1,727 passed, 0 failed, 0 errors**, built with `msc_vc140` | 0 | [w3c-msvc.txt](logs/w3c-msvc.txt) |
| 3 | `python -m unittest discover -s tests/python` with Python 3.14.0, `LongPathsEnabled = 1` (on `72b2f5c`) | **Ran 178 tests, OK (skipped=7)** | 0 | [python-3.14-longpaths.txt](logs/python-3.14-longpaths.txt) |

Rows 1-2 ran before the sync with `main` (#110); the same checks on the merged
code, also with MSVC, are in [`../issue-0110/report.md`](../issue-0110/report.md): same results.

Row 3 **confirms** the cause that #104 could only call suspected: the 15
`test_implementation_builds.py` problems came from Windows long paths being off.

## 6. Limitations

- Jenkins was not run; the remaining version differences (⚠️) are untested
  against each other.
- Which `ISE_C_COMPILER` the Jenkins machine uses is not written anywhere;
  "MSVC" is known from the Jenkins log (Visual Studio environment loaded), not
  the exact backend name.
- The 7 skipped Python tests skip themselves (for example when WSL or a tool
  is not available); they were not investigated.

## How to undo

| Change | Undo |
|---|---|
| `ISE_C_COMPILER` | `[Environment]::SetEnvironmentVariable("ISE_C_COMPILER", $null, "User")` |
| Python 3.14 default | remove the two `Python314` entries from the user `PATH`; uninstall in Settings → Apps |
| git long paths | `git config --global --unset core.longpaths` |
| Windows long paths | the `New-ItemProperty` command above with `-Value 0` (administrator) |
| Repository part | `.\student\tools\fix.ps1 revert -Issue 113 -Commit <merged sha>` |
