# Fix report: issue #46, B02, deliberately failing meta-tests

Issue: [#46](https://github.com/andersoxie/xpact/issues/46)   Branch: `fix/46-meta-tests`   Base: `f777826`   Date: 2026-10-22
Logs and scripts: [`student/results/B02-meta-tests/`](../../student/results/B02-meta-tests/README.md) (where the issue asks for them)

## Why

B01 (#45) made a failure exit nonzero, shown with a temporary failing
`assert` that was not committed. B02 keeps that proof available: a
meta-test that fails on demand, without editing any real test, so anyone can
check at any time that a failure still reaches the exit status and the CI
wrapper in every build.

## Options

| Option | Result |
|---|---|
| A separate failing test target in the ECF | One more target to build per configuration; does not test the real runner |
| A command-line argument | `run_eiffel_test_matrix.ps1` and Jenkins would have to pass it through |
| **An environment variable read by a meta-test in the real runner** (chosen) | Inherited by the wrappers and Jenkins without changing them; unset, it does nothing |

## What changed

| File | Change |
|---|---|
| `tests/xp_test_root.e` | New `test_meta_deliberate_failure`, run last through `run_test`. `XPACT_META_FAIL=assert` (or `1`): a failed `assert`. `XPACT_META_FAIL=exception`: raises a `DEVELOPER_EXCEPTION` (the #60 path). Unset or another value: nothing. It prints `xpact meta-test: ...` when it fails on purpose |
| `tests/xp_native_runtime_smoke.e` | With `XPACT_META_FAIL` set to any value, a failed `assert` |
| `student/GUIDE.md`, `student/PLAN.md` | B01/B02 done; the notes on K2, draft 06 and #28 updated |

Usage, from the repository root:

```powershell
$env:XPACT_META_FAIL = "assert"     # or "exception"
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All   # must fail
Remove-Item Env:XPACT_META_FAIL
```

## Verification

EiffelStudio 25.12.9.8922, mingw C backend, Windows PowerShell 5.1.
[run-set.ps1](../../student/results/B02-meta-tests/run-set.ps1) sets or removes
`XPACT_META_FAIL` and runs each lane through
[run-lane.ps1](../../student/results/B02-meta-tests/run-lane.ps1) (MSVC loaded, repository
root) with `cmd /c "powershell ... > <log> 2>&1"`; the exit status is the last
line of each log.

Expected, written before the runs: with `assert` and `exception` every lane
exits nonzero and shows the meta-test's line; unset, the results are those of
B01 (assertions-off and native `ok`, assertions-on exits 1 on B03, #3).

| Configuration | `XPACT_META_FAIL=assert` | `XPACT_META_FAIL=exception` | unset |
|---|---|---|---|
| Assertions off, Workbench | `FAIL: meta-test: deliberate failure ...`, `FAILED`, **exit 1** | `FAIL: test_meta_deliberate_failure raised an exception`, **exit 1** | `ok`, exit 0 |
| Assertions off, Finalized | same, **exit 1** | same, **exit 1** | `ok`, exit 0 |
| Assertions on, Workbench | B03 and the meta-test (`43 run, 1 raised an exception`), **exit 1** | B03 and the meta-test (`43 run, 2 raised an exception`), **exit 1** | B03 only, exit 1 |
| Assertions on, Finalized (`-keep`) | same, **exit 1** | same, **exit 1** | B03 only, exit 1 |
| Native smoke, assertions off | `FAIL: meta-test ...`, `xpact native runtime smoke: FAILED`, **exit 1** | (not separate: any value fails) | `ok`, exit 0 |
| Native smoke, assertions on | same, **exit 1** | | `ok`, exit 0 |

In every failing row the wrapper says so (`Test executable failed for ...` or
`Native runtime smoke failed for ...`) and exits 1. Logs:
`assert-*.txt`, `exception-*.txt`, `unset-*.txt` in
[`student/results/B02-meta-tests/`](../../student/results/B02-meta-tests/).

**Not tested: Jenkins.** No Jenkins server is available from the student
PC. The Jenkins stage calls `run_eiffel_test_matrix.ps1` (`ci/Jenkinsfile.all-tests`,
stage "xpact Eiffel regression matrix"), which inherits the job's
environment, so setting `XPACT_META_FAIL=assert` on a Jenkins run should turn
that stage red. That has to be checked on Jenkins.

## How to revert

```powershell
git revert <sha of this commit>
```
