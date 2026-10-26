# Report: issue #110, sync `student-Mass` with `main` after #101, and test the result

Issue: [#110](https://github.com/andersoxie/xpact/issues/110)   Pull request: [#111](https://github.com/andersoxie/xpact/pull/111) (merge commit `e8c5cb3`)   Date: 2026-10-26

## In short

| | |
|---|---|
| 🎯 Goal | `student-Mass` was 11 commits behind `main` (the supervisor's #101, parser performance). Bring it level, then prove nothing broke |
| ✅ Sync | `main` @ `de01371` merged into `student-Mass` with a merge commit; **0 behind `main`**, 8 ahead (our own work); `main` unchanged |
| ✅ Tests | Eiffel matrix 4/4, both DLLs, C# DLL tests 3,360/3,360 on both, W3C 1,727/1,727 in both builds; **all built with MSVC** (`msc_vc140`) |
| ⚠️ Python | 15 problems in `test_implementation_builds.py`, exactly as expected: paths over 260 characters in this deep folder, Windows long paths still off |

## 1. What #101 brought in

11 commits by the supervisor, 25-26 October: ASCII validation during input
normalization, attribute name sets without strings (new
`src/xp_attribute_name_range_set.e`), no document-prefix rescans when positions
move back, no per-byte CDATA marker allocation, batched text positions, cheap
DOCTYPE no-op parsing; +533 lines in `tests/xp_test_root.e`; profiling evidence
in `docs/*performance*.md` and `benchmarks/results/`.

## 2. Sync

| Step | Command | Result |
|---|---|---|
| Conflict check, in memory only | `git merge-tree --write-tree origin/student-Mass origin/main` | exit 0, **no conflicts** |
| Pull request | #111, `main` → `student-Mass`, "Create a merge commit" | merged as `e8c5cb3` |
| Level check | `git rev-list --count origin/student-Mass..origin/main` | **0** (ahead: 8) |
| `main` unchanged | `git rev-parse origin/main` before and after | `de01371` both times |
| Local copy | `.\sync-latest.ps1` | "Synced to student-Mass @ e8c5cb3", 0 files removed |

## 3. Tests on the merged code

Expected results were written before the runs: [expected.md](expected.md).
Folder `C:\Users\masou\Desktop\Lia\xpact3.0\xpact-codex-w3c-xml-conformance-benchmarks`
(synced copy of `e8c5cb3`), student PC, EiffelStudio 25.12.9.8922, MSVC 19.51
(VS 2026), `ISE_C_COMPILER=msc_vc140`, Python 3.14.0. Steps in
[logs/run.ps1](logs/run.ps1), one fresh `powershell` each; exit codes in [logs/steps.tsv](logs/steps.tsv).

| # | Command | Expected | Actual | Exit | |
|---|---|---|---|---|---|
| 1 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All` | 4 × ok | 4 × `xpact Phase 1 tests: ok`; 4 builds with `msc_vc140`, 0 with mingw ([log](logs/1-matrix.txt)) | 0 | ✅ |
| 2 | `.\scripts\build_native_eiffel.ps1` | smoke ok | `xpact Eiffel DLL smoke: ok` ([log](logs/2-dll-production.txt)) | 0 | ✅ |
| 3 | `.\scripts\build_native_eiffel.ps1 -BuildTier Assertions` | smoke ok | `xpact Eiffel DLL smoke: ok` ([log](logs/3-dll-assertions.txt)) | 0 | ✅ |
| 4 | `XpactDllTests.exe` (`xpact_assertions.dll`, SHA-256 `f4f75bdd…`) | 3,360/3,360 | **3,360 pass, 0 fail, 0 crash, 0 timeout** ([log](logs/4-dll-tests-assertions.txt)) | 0 | ✅ |
| 5 | `XpactDllTests.exe --dll build\native-eiffel\xpact.dll` (SHA-256 `952ace95…`) | 3,360/3,360 | **3,360 pass, 0 fail, 0 crash, 0 timeout** ([log](logs/5-dll-tests-production.txt)) | 0 | ✅ |
| 6 | `.\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -SkipWslC` | 1,727 passed | `Finalized` and `FinalizedAssertions`: **1,727 passed, 0 failed, 0 errors**, 858 skipped; built with `msc_vc140` ([log](logs/6-benchmarks-w3c.txt)) | 0 | ✅ |
| 7 | `python -m unittest discover -s tests/python` (3.14.0) | all pass except the long-path tests in this folder | 178 tests: 2 failures, 13 errors, all in `test_implementation_builds.py`, the same 15 as in #104 ([log](logs/7-python-3.14.txt)) | 1 | ⚠️ as expected |

Step 7: `LongPathsEnabled` was still `0` when checked after the run. The cause
was shown in [#104](../issue-0104/report.md#5-investigation-of-the-python-failures):
in the git clone (a shorter path) 13 of the 15 do not occur. Not an xpact problem.

## 4. Limitations

- Student PC only; Jenkins not run. EiffelStudio 25.12 and MSVC 19.51 here,
  25.02 and 19.44 on the supervisor's machine.
- `-SkipWslC` leaves out the WSL/GCC benchmark lane.
- No timing comparison was made: #101 is a speed change, and the supervisor's
  own measurements are in `docs/*performance*.md`.
