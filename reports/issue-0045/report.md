# Fix report: issue #45, B01, failing tests must return a nonzero exit status

Issue: [#45](https://github.com/andersoxie/xpact/issues/45)   Branch: `fix/45-nonzero-exit`   Base: `aff0584`   Date: 2026-10-22
Logs and scripts: [`student/results/B01-nonzero-exit/`](../../student/results/B01-nonzero-exit/) (where the issue asks for them)

## Why

Both Eiffel test runners ended with

```eiffel
if failed then
    check tests_passed: False end
```

(`XP_TEST_ROOT.make`; `smoke_passed` in `XP_NATIVE_RUNTIME_SMOKE.make`). A
`check` is only evaluated when assertions are compiled in. In the
assertions-off builds a failing test printed `FAIL: ...` and the process
still exited 0, so `run_eiffel_test_matrix.ps1`, `run_native_runtime_smoke.ps1`
and Jenkins reported `ok`. Seen by accident on 2026-10-22 in #55 (a `FAIL`
line followed by `xpact Eiffel test matrix: ok`).

## Options

| Option | Result |
|---|---|
| Turn on `check` assertions in the assertions-off targets | Changes what "assertions off" means; still depends on Eiffel check instructions, which the task says not to rely on |
| Raise a developer exception | Exit status depends on how the runtime reports an uncaught exception |
| **Print a `FAILED` line and call `{EXCEPTIONS}.die (1)`** (chosen) | Exit status 1 in every build, independent of assertion settings; the summary line says why |

## What changed

| File | Change |
|---|---|
| `tests/xp_test_root.e` | When a test failed: `xpact Phase 1 tests: FAILED`, then `{EXCEPTIONS}.die (1)` instead of `check tests_passed: False end` |
| `tests/xp_native_runtime_smoke.e` | Same: `xpact native runtime smoke: FAILED`, then `{EXCEPTIONS}.die (1)` |

The wrappers needed no change: both already throw when the executable exits
nonzero.

## Verification

EiffelStudio 25.12.9.8922, mingw C backend, Windows PowerShell 5.1.
[run-lane.ps1](../../student/results/B01-nonzero-exit/run-lane.ps1) loads MSVC and runs one lane
from the repository root; [run-set.ps1](../../student/results/B01-nonzero-exit/run-set.ps1) runs
a list of lanes through `cmd /c "powershell ... > <log> 2>&1"` and appends the
exit status to each log. "Deliberate failure" is
[deliberate-failure.diff](../../student/results/B01-nonzero-exit/deliberate-failure.diff):
`assert ("B01 deliberate failure (temporary, not committed)", False)` at the
start of both runners, applied for rows 1-9 only and not committed (B02, #46,
adds a permanent switchable one).

Expected results were written down before the runs: before the fix the
assertions-off runs exit 0 despite `FAIL`; after it every run with a failure
exits nonzero; without the deliberate failure only the assertions-on matrix
lanes fail (on B03, #3).

| # | Code | Lane | Actual | Exit | Log |
|---|---|---|---|---|---|
| 1 | before + deliberate | Off / Workbench | `FAIL: B01 deliberate failure ...`, then `xpact Eiffel test matrix: ok` | **0** | [before-off-workbench.txt](../../student/results/B01-nonzero-exit/before-off-workbench.txt) |
| 2 | before + deliberate | Off / Finalized | same | **0** | [before-off-finalized.txt](../../student/results/B01-nonzero-exit/before-off-finalized.txt) |
| 3 | before + deliberate | native smoke, Off | `FAIL: B01 deliberate failure ...` | **0** | [before-native-off.txt](../../student/results/B01-nonzero-exit/before-native-off.txt) |
| 4 | after + deliberate | Off / Workbench | `FAIL: ...`, `xpact Phase 1 tests: FAILED`, `Test executable failed for assertions-off / Workbench.` | 1 | [after-deliberate-off-workbench.txt](../../student/results/B01-nonzero-exit/after-deliberate-off-workbench.txt) |
| 5 | after + deliberate | Off / Finalized | same, `... assertions-off / Finalized.` | 1 | [after-deliberate-off-finalized.txt](../../student/results/B01-nonzero-exit/after-deliberate-off-finalized.txt) |
| 6 | after + deliberate | On / Workbench | deliberate `FAIL` and B03 recorded (`42 run, 1 raised an exception`), `FAILED` | 1 | [after-deliberate-on-workbench.txt](../../student/results/B01-nonzero-exit/after-deliberate-on-workbench.txt) |
| 7 | after + deliberate | On / Finalized (`-keep`) | same | 1 | [after-deliberate-on-finalized.txt](../../student/results/B01-nonzero-exit/after-deliberate-on-finalized.txt) |
| 8 | after + deliberate | native smoke, Off | `FAIL: ...`, `xpact native runtime smoke: FAILED`, `Native runtime smoke failed for assertions-off.` | 1 | [after-deliberate-native-off.txt](../../student/results/B01-nonzero-exit/after-deliberate-native-off.txt) |
| 9 | after + deliberate | native smoke, On | same, `assertions-on` | 1 | [after-deliberate-native-on.txt](../../student/results/B01-nonzero-exit/after-deliberate-native-on.txt) |
| 10 | after | Off / Workbench | `xpact Phase 1 tests: ok` | 0 | [after-clean-off-workbench.txt](../../student/results/B01-nonzero-exit/after-clean-off-workbench.txt) |
| 11 | after | Off / Finalized | `xpact Phase 1 tests: ok` | 0 | [after-clean-off-finalized.txt](../../student/results/B01-nonzero-exit/after-clean-off-finalized.txt) |
| 12 | after | On / Workbench | B03 only: `42 run, 1 raised an exception`, `FAILED` | 1 | [after-clean-on-workbench.txt](../../student/results/B01-nonzero-exit/after-clean-on-workbench.txt) |
| 13 | after | native smoke, Off | `xpact native runtime smoke: ok` | 0 | [after-clean-native-off.txt](../../student/results/B01-nonzero-exit/after-clean-native-off.txt) |
| 14 | after | native smoke, On | `xpact native runtime smoke: ok` | 0 | [after-clean-native-on.txt](../../student/results/B01-nonzero-exit/after-clean-native-on.txt) |

The native smoke script builds Workbench only, so it has no Finalized row.

Done-when items of #45: a deliberately failing test makes `xpact_tests.exe`
exit nonzero (rows 4-7); in workbench and finalized `-keep` builds (rows 6-7)
and with assertions off (rows 4-5); `run_eiffel_test_matrix.ps1` reports it
(`Test executable failed for ...`); before/after logs in
`student/results/B01-nonzero-exit/`.

## How to revert

```powershell
git revert <sha of this commit>
```
