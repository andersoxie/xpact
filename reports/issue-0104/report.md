# Check report: issue #104, full check of `student-Mass` @ `41731c8` (2026-10-26)

Issue: [#104](https://github.com/andersoxie/xpact/issues/104)   Branch: `fix/104-check-2026-10-26`   Checked: `student-Mass` @ `41731c8` (contains `main` @ `64d027f`)   Date: 2026-10-26

## In short

| | |
|---|---|
| 🎯 Goal | After the sync with `main` (#102, #103): does everything build and pass with assertions on, and what is the real state of every open issue? |
| ✅ Code | Every build and test of xpact passes: Eiffel matrix 4/4 lanes, both DLLs, C# DLL tests 3,360/3,360 on both DLLs, W3C 1,727/1,727 in both finalized builds |
| ✅ Issues | Fixes verified here for **#3** (B03), **#39** (invalid UTF-8), **#40** (chunk ending with `<`); **#68** and **#70** were merged but never closed |
| ❌ Python tests | 102 of 178 fail with the PC's default Python 3.10; **15** with Python 3.13; **2** (one test) in the shorter-path git clone. All caused by the environment, not by xpact |
| 🆕 Found | 4 problems with no issue yet (section 6); `student/PLAN.md` was 4 days out of date (updated by this change) |
| ⏳ Not verified | Anything on Jenkins: #73, #74, #79 still need a Jenkins run |

## 1. What was checked

| | |
|---|---|
| Folder | `C:\Users\masou\Desktop\Lia\xpact3.0\xpact-codex-w3c-xml-conformance-benchmarks` (the non-git working copy, synced with `sync-latest.ps1`; marker `.synced-commit` = `41731c8`) |
| Control | the git clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit` on `student-Mass` @ `41731c8` (Python tests only) |
| Machine | student PC, Windows 11, EiffelStudio 25.12.9.8922 Standard, VS 18 (MSVC), .NET 10, Python 3.10.6 (default `python`) and 3.13 (`py -3.13`); `ISE_EIFFEL` and `ISE_C_COMPILER` unset; Windows `LongPathsEnabled = 0`; no CMake |
| Assertions | test matrix: assertions-off and assertions-on lanes, finalized with `-keep`; DLLs: `xpact_assertions.dll` and `xpact.dll`; W3C: `Finalized` (off) and `FinalizedAssertions` (on) |
| Callbacks, chunks | C# DLL tests: all callback sets, whole input, every split point and byte by byte (as in #37) |

## 2. Folder against git

| Check | Result |
|---|---|
| Every file of `git ls-tree -r 41731c8` (531) present in the folder, same content (line endings ignored) | ✅ 531/531; only `.vscode/settings.json` differs, which `sync-latest.ps1` leaves alone on purpose |
| Files in the folder that git does not have (outside `EIFGENs/`, `build/`) | personal notes, plus two build leftovers (`xpact_native_library.rc`, `xpact_eiffel_dll_smoke.obj`); harmless |

## 3. Expected results (written before the runs)

| # | Check | Expected |
|---|---|---|
| 1 | Eiffel test matrix, all lanes | 4 × `xpact Phase 1 tests: ok`, exit 0 (B03 fix #12 and the #80 parser fixes are in; the supervisor's parser changes #85, #87 are new to this matrix) |
| 2-8 | DLL builds, ABI, runtime smoke, CRC corpus, shim audit, examples | exit 0, as in the #79 final run |
| 9-11 | C# DLL tests on both DLLs | 0 failures, 0 crashes, as in #79 |
| 12 | W3C, both finalized builds | 1,727 passed, 0 failed, 858 skipped |
| P | Python unit tests | all pass, as in #79 (28 tests then; the supervisor has added more since) |

## 4. Results

Logs: [`logs/`](logs/). The steps are in [`logs/run-checks.ps1`](logs/run-checks.ps1), one fresh `powershell` per step; exit codes in [`logs/steps.tsv`](logs/steps.tsv).

| # | Command | Actual | Exit | |
|---|---|---|---|---|
| 1 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All` | 4 × `xpact Phase 1 tests: ok`, `xpact Eiffel test matrix: ok` ([log](logs/matrix-all.txt)) | 0 | ✅ |
| 2 | `.\scripts\build_native_eiffel.ps1` | `xpact Eiffel DLL smoke: ok` ([log](logs/02-dll-production.txt)) | 0 | ✅ |
| 3 | `.\scripts\build_native_eiffel.ps1 -BuildTier Assertions` | `xpact Eiffel DLL smoke: ok` ([log](logs/03-dll-assertions.txt)) | 0 | ✅ |
| 4 | `.\scripts\run_native_abi_tests.ps1 -Target Windows` | public and bridge ABI smoke ok ([log](logs/04-native-abi-tests.txt)) | 0 | ✅ |
| 5 | `.\scripts\run_native_runtime_smoke.ps1` | both cells ok ([log](logs/05-native-runtime-smoke.txt)) | 0 | ✅ |
| 6 | `.\scripts\run_chunked_crc_corpus.ps1 -Target Xpact -ParseMode All -SkipBuild` | ([log](logs/06-chunked-crc-corpus.txt)) | 0 | ✅ |
| 7 | `.\scripts\run_incremental_shim_audit.ps1 -SkipBuild` | ([log](logs/07-incremental-shim-audit.txt)) | 0 | ✅ |
| 8 | `.\scripts\run_contributed_examples.ps1` | ([log](logs/08-contributed-examples.txt)) | 0 | ✅ |
| 9 | `dotnet build tests\dotnet\XpactDllTests -c Release` | 0 errors ([log](logs/09-dotnet-build.txt)) | 0 | ✅ |
| 10 | `XpactDllTests.exe` (`xpact_assertions.dll`, built in step 3, SHA-256 `ed7b2c86…`) | **3,360 pass, 0 fail, 0 crash, 0 timeout** ([log](logs/10-dll-tests-assertions.txt)) | 0 | ✅ |
| 11 | `XpactDllTests.exe --dll build\native-eiffel\xpact.dll` (SHA-256 `fde0c281…`) | **3,360 pass, 0 fail, 0 crash, 0 timeout** ([log](logs/11-dll-tests-production.txt)) | 0 | ✅ |
| 12 | `.\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -SkipWslC` | W3C `Finalized` and `FinalizedAssertions`: **1,727 passed, 0 failed, 0 errors**, 858 skipped, 0 known ([log](logs/12-benchmarks-w3c.txt)) | 0 | ✅ |
| P1 | `python -m unittest discover -s tests/python` (Python 3.10.6) | 178 tests: **20 failures, 82 errors**, 7 skipped ([log](logs/01-python-unit-tests.txt)) | 1 | ❌ |
| P2 | same with `py -3.13` | **2 failures, 13 errors**, all in `test_implementation_builds.py` ([log](logs/01b-python-3.13.txt)) | 1 | ❌ |
| P3 | `py -3.13 -m unittest tests.python.test_implementation_builds` from a `subst` drive | same 15; **inconclusive**: Python resolved the drive back to the long path ([log](logs/01c-implementation-builds-short-path.txt)) | 1 | ⚠️ |
| P4 | P2 in the git clone (same code, root path 41 characters shorter) | **1 failure, 1 error**, both `test_long_checkout_path_preserves_verification_and_dirty_recovery` ([log](logs/01d-python-3.13-in-clone.txt)) | 1 | ❌ |

`-SkipWslC` leaves out the WSL/GCC lane, which is not part of this check. The
C# DLL test summary prints an empty "Commit:" line in the folder, because it
is not a git clone.

## 5. Investigation of the Python failures

| Step | Finding | Cause |
|---|---|---|
| P1 | 69 errors are `AttributeError: module 'hashlib' has no attribute 'file_digest'`; the files are the supervisor's new tests (`test_implementation_builds`, `test_jenkins_xpact_summary`, `test_dual_*`, `test_libexpat_adapter`) | ✔ **confirmed**: `hashlib.file_digest` exists from Python 3.11; the PC's default `python` is 3.10.6. `student/report/setup-guide.md` still says "3.10 or newer" |
| P2 | With 3.13: 15 left, all `shutil.Error … [WinError 3] The system cannot find the path specified` while copying `.git\objects` | see P4 |
| P3 | Tried to shorten the path with `subst`; the tracebacks still show `C:\Users\…` | inconclusive, not used as evidence |
| P4 | In the git clone 13 of the 15 disappear. The failing copy destinations in the folder are about **262 characters** long ([`pathlen.py`](logs/pathlen.py) measures the folders in the errors) | ✔ **confirmed by the comparison**: the folder's long root path plus the tests' nested folder names pass Windows' 260-character limit, and long paths are off on this PC |
| P4 | `test_long_checkout_path_preserves_verification_and_dirty_recovery` still fails in the clone; the test itself makes a path longer than 260 (`assertGreater(len(...), 260)`, line 139) | ❓ **suspected**: needs Windows long-path support (`LongPathsEnabled = 1`); not changed, it is an administrator setting |

None of this is a failure of xpact. The failed test cleanups left about
400 KB under `build/implementation-build-tests/` (ignored by git).

## 6. State of the issues

| Issue | Before this check | Evidence now | New status |
|---|---|---|---|
| [#3](https://github.com/andersoxie/xpact/issues/3) B03 | open; fix #12 merged | matrix lane assertions-on / Workbench passes; `final_finished_or_suspended` no longer fails | ✅ verified |
| [#39](https://github.com/andersoxie/xpact/issues/39) invalid UTF-8 | open; fixed in #80 | the `utf8` group (2,658 cases) passes on both DLLs | ✅ verified |
| [#40](https://github.com/andersoxie/xpact/issues/40) chunk ending with `<` | open; fixed in #80 | 0 crashes on `xpact_assertions.dll` (was 644) | ✅ verified |
| [#68](https://github.com/andersoxie/xpact/issues/68), [#70](https://github.com/andersoxie/xpact/issues/70) | open; PRs #69, #71 merged | every file their "Done when" lists is on `student-Mass` | ✅ verified |
| [#13](https://github.com/andersoxie/xpact/issues/13) GC swallows exceptions | open | not changed by any merge | still open |
| [#73](https://github.com/andersoxie/xpact/issues/73), [#74](https://github.com/andersoxie/xpact/issues/74), [#79](https://github.com/andersoxie/xpact/issues/79) | open | student PC passes; Jenkins not rerun yet. PR #76 (#74) had a conflict after #103, fixed and retested on 2026-10-26 | still open |

**Found, no issue filed yet** (to decide with the supervisor):

1. Python 3.10 no longer runs the Python tests (`hashlib.file_digest`); the setup guide says 3.10 works.
2. Jenkins "Eiffel Tests" stage still prints no test result (unchanged since [#73's log](../issue-0073/jenkins-log-2026-10-23.txt)).
3. SonarQube `HTTP 401` on Jenkins (server token).
4. `tests/python/run_w3c_conformance.py` is an old copy (361 lines vs 459), used by nothing.

Small: the C# DLL test README gives `bin\Release\net10.0\` for the program; the
check found it by searching `build\dotnet\XpactDllTests\bin`.

## 7. Limitations

- Everything ran on the student PC only; nothing here proves the Jenkins results.
- The W3C numbers cover the 1,727 applicable cases; the 858 skipped ones
  (old editions, XML 1.1, external entities) are not tested (see `w3cerror.txt`
  analysis in the personal notes).
- The long-path cause of the last Python test is suspected, not proven.

## How to repeat

```powershell
cd C:\Users\masou\Desktop\Lia\xpact3.0\xpact-codex-w3c-xml-conformance-benchmarks
.\sync-latest.ps1
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All
powershell -NoProfile -File <path>\reports\issue-0104\logs\run-checks.ps1
py -3.13 -m unittest discover -s tests/python
```
