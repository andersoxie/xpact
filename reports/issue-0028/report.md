# Fix report: issue #28, regression test for the CR loop variant

Issue: [#28](https://github.com/andersoxie/xpact/issues/28)   Branch: `fix/28-cr-regression-test`   Base: `student-Mass` @ `8850dab`   Date: 2026-10-22

## Why

With assertions on, every input that contains a CR byte stops in
`XP_PARSER.normalized_input` with "Non-decreasing loop variant"
(1,357 of the 1,360 W3C crashes on 2026-10-21). No test in
`tests/xp_test_root.e` catches it, so the main test matrix stays green
(assertions off) or fails only on B03 (assertions on).

This adds a regression test only. **The parser is not changed**: the repair
is for the parser's developers (see "Proposed repair" below).

### Why the existing tests miss it

The broken loop (`src/xp_parser.e`, first loop in `normalized_input`) only
runs when `a_allow_alias` is True. `parse` passes
`can_defer_position_accounting`, which is True only when the handler wants
no events (no start, end, character data or default events, no eager
positions). Every existing parse test uses `XP_COLLECTING_HANDLER`, which
wants events, so those parses take the second (copying) loop, which is
correct. The benchmark program uses `XP_NULL_EVENT_HANDLER`, which is why the
W3C runner found the bug.

The new test therefore uses `XP_NULL_EVENT_HANDLER`. It runs before
`test_garbage_collection_suspension`, because B03 (#3, not merged) stops
the assertions-on run there and later tests would not be reached.

## What changed

| File | Change |
|---|---|
| `tests/xp_test_root.e` | New test `test_cr_line_ends_with_deferred_positions`, called from `make` before `test_garbage_collection_suspension` |
| `reports/issue-0028/` | This report and the logs |
| `reports/README.md` | Row for #28 |

## Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | `cr-lf.xml` with `xpact_benchmarks.exe` (assertions off), `--conformance-file` | ACCEPT, exit 0 |
| 2 | `cr-lf.xml` with `xpact_benchmarks_assertions` | Crash in `normalized_input`, loop variant, exit 1 (bug still present) |
| 3 | `lf.xml` with both builds (control) | ACCEPT, exit 0 |
| 4 | Matrix `-AssertionMode Off -BuildMode Workbench` with the new test | `xpact Phase 1 tests: ok`, exit 0 |
| 5 | Matrix `-AssertionMode On -BuildMode Workbench` with the new test | Fails **in the new test** with the `normalized_input` loop variant violation, nonzero exit (the test catches the bug) |
| 6 | As 5, with the proposed repair applied locally (not committed) | New test passes; the run then stops at the known B03 failure in `test_garbage_collection_suspension` (K1), not in `normalized_input` |
| 7 | `git diff student-Mass -- src` on the branch | Empty: no parser change committed |

## Verification

Windows 11, Windows PowerShell 5.1, EiffelStudio 25.12.9.8922,
`ISE_C_COMPILER=msc_vc140`, MSVC 14.51. Base commit `8850dab` plus the new test.
Every log starts with the commit, command and date and ends with the exit code.

| # | Command | Actual | Exit | Log |
|---|---|---|---|---|
| 1 | `xpact_benchmarks.exe --conformance-file cr-lf.xml` (assertions off) | ACCEPT | 0 | [before-repro.txt](before-repro.txt) |
| 2 | same, `xpact_benchmarks_assertions` | `XP_PARSER normalized_input @8`: Non-decreasing loop variant | 1 | [before-repro.txt](before-repro.txt) |
| 3 | `lf.xml` with both builds | ACCEPT, ACCEPT | 0, 0 | [before-repro.txt](before-repro.txt) |
| 4 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode Off -BuildMode Workbench` | `xpact Phase 1 tests: ok` | 0 | [matrix-off-workbench.txt](matrix-off-workbench.txt) |
| 5 | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Workbench` | Fails in `test_cr_line_ends_with_deferred_positions @3` with the `normalized_input` loop variant: **the test catches the bug** | 1 | [matrix-on-workbench.txt](matrix-on-workbench.txt) |
| 6 | as 5, with [proposed-repair.diff](proposed-repair.diff) applied locally | The new test passes; the run stops at the known B03 postcondition in `test_garbage_collection_suspension` (K1) | 1 | [matrix-on-workbench-with-repair.txt](matrix-on-workbench-with-repair.txt) |
| 7 | `git diff --stat student-Mass -- src` | empty: the repair was removed again with `git restore src/xp_parser.e` | 0 | - |

All seven expectations were met. When the parser is repaired, check 5
turns into check 6; when B03 (#3) is also merged, the assertions-on lane
should pass completely.

### How the lanes were run

Two things in Windows PowerShell 5.1 stopped the matrix script before it
reached the tests. Neither is caused by this change, and no script was
changed:

1. `ec` and `vcvars64.bat` write normal messages to stderr. When the
   script's output is captured by PowerShell, `$ErrorActionPreference = "Stop"`
   turns them into a fatal error. Workaround: run the script in a child
   `powershell.exe` and let `cmd` redirect the output to the log.
   `vcvars64.bat` also needs `C:\Program Files (x86)\Microsoft Visual Studio\Installer`
   (where `vswhere.exe` is) on `PATH`.
2. **New observation:** with `-BuildMode Workbench` alone,
   `run_eiffel_test_matrix.ps1` does not load MSVC (it only does that when
   `Finalized` is selected, lines 85-88). With `ISE_C_COMPILER=msc_vc140`,
   `finish_freezing` then fails silently. Workaround: dot-source
   `scripts\import_msvc_environment.ps1` first. Worth a separate finding.

## Proposed repair (not committed)

In the first loop of `XP_PARSER.normalized_input`, a CR sets
`l_needs_copy` but does not advance `i`. The loop would stop anyway (its
exit condition includes `l_needs_copy`), but Eiffel checks the variant
`a_input.count - i + 1` after every pass, and it did not decrease. One line
fixes it ([proposed-repair.diff](proposed-repair.diff)):

```eiffel
if c = '%R' then
    l_needs_copy := True
    i := i + 1
```

This is a parser change, so it is left to the parser's developers, like
B03 (#3, pull request #12).

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 28 -Commit <merged sha>
```

This removes the test and this folder. Issue #28 stays open until the
parser is repaired.
