# Report: issue #128, C02 final-input regressions (#38, #39, #40)

Issue: [#128](https://github.com/andersoxie/xpact/issues/128)   Branch: `fix/128-final-input-regressions`   Base: `student-Mass` @ `ed3febc`   Date: 2026-10-26

## In short

| | |
|---|---|
| Task | Week 5, C02: "Regressions added to the test suite". #38, #39 and #40 were fixed in #80 without tests; the C# program that found them is not in CI |
| Change | Tests only: `check_final_input_regressions()` in the DLL smoke test, `test_final_input_regressions` in the Eiffel suite. No change in `src/` |
| Result | Both DLLs `smoke: ok`; Eiffel matrix 4/4 ok (MSVC). With the #38 or #40 fix undone, the new tests fail |
| Results page | [`student/results/C02-final-input/`](../../student/results/C02-final-input/README.md) |

## Environment

Windows 11 Home 10.0.26300; EiffelStudio 25.12.9.8922 Standard; MSVC 19.51
(`ISE_C_COMPILER=msc_vc140`, VS 2026 `vcvars64.bat`); finalized DLLs
`xpact.dll` SHA-256 `3861c3bd…`, `xpact_assertions.dll` `179ae298…`.

## What changed

| File | Change |
|---|---|
| `tests/native/xpact_eiffel_dll_smoke.c` | `check_final_input_regressions()`: 7 C02 inputs + 42 UTF-8 inputs × 6 callback sets × every split; called from `main` |
| `tests/xp_test_root.e` | `test_final_input_regressions` + helper `native_final_input_accepted`; registered in `make` |
| `student/results/C02-final-input/README.md` | New: what is tested, the undo-fix proof |
| `student/github/issues/13-C02.md`, `student/PLAN.md`, `student/notes/weekly/week-05.md`, `reports/README.md` | ticked / rows; week 5 decision marked skipped by the student |

## Expected results (written before running, in #128)

| # | Check | Expected |
|---|---|---|
| 1 | both DLL builds, today's code | smoke ok |
| 2 | Eiffel matrix | 4/4 ok |
| 3 | #38 fix undone | smoke fails on `<root>` with a start handler |
| 4 | #40 fix undone | assertions build stops at a non-final `<` |

## Verification

| # | Command | Actual | |
|---|---|---|---|
| 1 | `scripts\build_native_eiffel.ps1 -BuildTier Assertions` | `xpact Eiffel DLL smoke: ok`, exit 0 ([log](build-assertions.txt)) | ✅ |
| 2 | `scripts\build_native_eiffel.ps1 -BuildTier Production` | `xpact Eiffel DLL smoke: ok`, exit 0 ([log](build-production.txt)) | ✅ |
| 3 | `set ISE_C_COMPILER=msc_vc140` then `scripts\run_eiffel_test_matrix.ps1` | 4 × `xpact Phase 1 tests: ok`, `xpact Eiffel test matrix: ok`, exit 0, `msc_vc140` in every build ([log](eiffel-matrix.txt)) | ✅ |
| 4 | #38 fix undone in `src/xp_native_parser.e` (lines 908 and 927), `build_native_eiffel.ps1 -BuildTier Production -OutputDir build\undo-fix38` | exit 1: `FAIL: final input <root>, handlers 1, split 0 of 6: error 0, expected 3; starts 1, ends 0` ([log](undo-fix-38-smoke.txt)) | ✅ expected 3 |
| 5 | the same, with the smoke test of `student-Mass` | `smoke: ok`: the old tests do **not** catch #38 ([log](undo-fix-38-old-smoke.txt)) | ✅ shows the gap |
| 6 | #40 fix undone in `src/xp_parser.e` (line 6417), `run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Workbench` | `FAIL: test_final_input_regressions raised an exception`, `index_in_bounds: Loop invariant violated`; 67 run, 1 raised ([log](undo-fix-40-eiffel.txt)) | ✅ expected 4 |
| 7 | the same, `build_native_eiffel.ps1 -BuildTier Assertions` | smoke crashes, exit code `-1073741784` (`0xC0000028`) ([log](undo-fix-40-smoke.txt)) | ✅ |
| 8 | the same, with the smoke test of `student-Mass` | crashes too ([log](undo-fix-40-old-smoke.txt)): on the DLL side an older check already reached #40 | ℹ️ |
| 9 | `git checkout -- src/` after each undo; `git diff --stat src/` | empty | ✅ |

#39 was not undone: its fix is spread over many features of `src/xp_parser.e`.
The 2026-10-22 run shows these inputs accepted by the DLLs of that day.

## Problems met (kept separate)

**1. The first matrix run used MinGW, not MSVC.**

| | |
|---|---|
| Problem | `run_eiffel_test_matrix.ps1` compiled all 4 builds with MinGW gcc |
| Environment | the tool shell of this session; `ISE_C_COMPILER` is set for the user (`msc_vc140`) but the session started before it was set, so the variable was empty |
| Command | `cmd /c "powershell -NoProfile -File scripts\run_eiffel_test_matrix.ps1 > … 2>&1"` |
| Expected / actual | MSVC (`msc_vc140`) / MinGW gcc (4/4 ok, but not the supervisor's setup) |
| Error output | none; the log shows `mingw/bin/gcc` ([log](eiffel-matrix-mingw-by-mistake.txt)) |
| Cause | ✔ confirmed: empty `ISE_C_COMPILER` in the process (`echo $ISE_C_COMPILER` empty; user value `msc_vc140`) |
| Fix | rerun with `set ISE_C_COMPILER=msc_vc140` (row 3). A workaround for this session, not a code change; `build_native_eiffel.ps1` sets the backend itself |


## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 128 -Commit <merged sha>
```
