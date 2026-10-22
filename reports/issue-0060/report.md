# Fix report: issue #60, the test runner stops at the first failure, so later tests do not run

Issue: [#60](https://github.com/andersoxie/xpact/issues/60) (from draft `student/github/issues/06-finding-runner-stops.md`)   Branch: `fix/60-runner-continues`   Base: `d279717`   Date: 2026-10-22

## Why

`XP_TEST_ROOT.make` called the 42 tests one after another. A test that
raised an exception (a contract violation with assertions on) ended `make`,
so every test after it was skipped and its result unknown. On `d279717` the
assertions-on lanes stop in `test_garbage_collection_suspension` (B03, #3),
call 35 of 42 (`XP_TEST_ROOT make @35` in the trace), so 7 tests did not run.

## Options

| Option | Result |
|---|---|
| A separate process per test | Clean isolation, but needs a new driver and 42 compilations or a command-line selector |
| **`run_test` with `rescue`/`retry` around each test** (chosen) | One exception fails one test; the runner records it, prints the trace and goes on. No test is changed |

## What changed

| File | Change |
|---|---|
| `tests/xp_test_root.e` | `make` calls `run_test ("<name>", agent <name>)` for each of the 42 tests. `run_test` counts the test; in `rescue` it sets `failed`, prints `FAIL: <name> raised an exception` and the original exception trace, and retries without the test. When a test raised, `make` prints `xpact Phase 1 tests: <n> run, <k> raised an exception` |

How the run ends is unchanged: `check tests_passed: False end` when
anything failed. That only works with assertions on; making it exit nonzero
in every build is B01 (#45).

## Verification

[run-lane.ps1](run-lane.ps1) loads MSVC and runs one lane of
`run_eiffel_test_matrix.ps1` from the repository root (EiffelStudio
25.12.9.8922, mingw C backend). Each run:
`cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File run-lane.ps1 -AssertionMode <m> -BuildMode <b> > <log> 2>&1"`.

| # | Lane | Expected | Actual | Exit | Log |
|---|---|---|---|---|---|
| 1 | Before, On / Workbench | stops in test 35 | `XP_TEST_ROOT test_garbage_collection_suspension @18`, `make @35`; no later test runs | 1 | [before-on-workbench.txt](before-on-workbench.txt) |
| 2 | After, On / Workbench | B03 recorded, all 42 run | `FAIL: test_garbage_collection_suspension raised an exception` + trace (`XP_NATIVE_PARSER parse @10 final_finished_or_suspended: Postcondition violated`); `xpact Phase 1 tests: 42 run, 1 raised an exception`; then `tests_passed` | 1 | [after-on-workbench.txt](after-on-workbench.txt) |
| 3 | After, On / Finalized | as 2 | as 2 | 1 | [after-on-finalized.txt](after-on-finalized.txt) |
| 4 | After, Off / Workbench | unchanged | `xpact Phase 1 tests: ok` | 0 | [after-off-workbench.txt](after-off-workbench.txt) |
| 5 | After, Off / Finalized | unchanged | `xpact Phase 1 tests: ok` | 0 | [after-off-finalized.txt](after-off-finalized.txt) |

The 7 tests after B03 run and pass with assertions on (no other `FAIL`
line). No compiler warning: a first version used the obsolete
`EXCEPTION.trace_as_string` and got `Obsolete Call`; it now uses `trace`.

## How to revert

```powershell
git revert <sha of this commit>
```
