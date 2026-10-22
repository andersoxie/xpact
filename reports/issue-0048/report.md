# Fix report: issue #48, assertions-on Finalized test lane does not check assertions (missing -keep)

Issue: [#48](https://github.com/andersoxie/xpact/issues/48) (from draft `student/github/issues/04-finding-finalized-keep.md`)   Branch: `fix/48-finalized-keep`   Base: `6ad5f84`   Date: 2026-10-22

## Why

`.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Finalized`
compiled the `xpact_tests_assertions` target with `ec -batch -clean -finalize`.
Without `-keep`, `ec -finalize` leaves every assertion out of the finalized
system, whatever the ECF says. So the "assertions-on" Finalized lane ran with no
assertions and reported `ok` (exit 0), while the Workbench lane and a
hand-built `-finalize -keep` run fail on the same tests (baseline 2026-10-14,
`student/baseline/logs/matrix-finalized.log` and `matrix-finalized-keep.log`).
Jenkins (`ci/Jenkinsfile.all-tests`, stage "xpact Eiffel regression matrix")
calls this script, so CI showed the same false pass.

`build_native_eiffel.ps1` already uses `-finalize -keep` for the DLLs.

## Options

| Option | Result |
|---|---|
| Leave it, document that the Finalized lane does not check assertions | The lane stays green while assertions fail; the matrix has no finalized assertions coverage |
| **Add `-keep` to every Finalized lane** (chosen) | The assertions-on lane checks what the ECF enables. The assertions-off target enables none, so `-keep` changes nothing there (row 3 below) |

## What changed

| File | Change |
|---|---|
| `scripts/run_eiffel_test_matrix.ps1` | Finalized lanes compile with `-finalize -keep` instead of `-finalize` |

**Behaviour change:** the assertions-on / Finalized lane, locally and in
Jenkins, now fails until the CR loop variant in `XP_PARSER.normalized_input`
([#28](https://github.com/andersoxie/xpact/issues/28)) is repaired. That
failure is real; before this fix it was hidden. Agreed with the student
before the change, as the draft asked.

## Verification

Commands run in `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, EiffelStudio
25.12.9.8922 win64, Windows PowerShell 5.1, MSVC environment loaded first.
Expected results were written down before each run.

| # | Command | Expected | Actual | Exit | Log |
|---|---|---|---|---|---|
| 1 | Before: `run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Finalized` | `ok`, exit 0 (the false pass) | `xpact Eiffel test matrix: ok` | 0 | [before-finalized-on.txt](before-finalized-on.txt) |
| 2 | After: same command | Fails on a contract violation | `XP_PARSER normalized_input @8`: `Non-decreasing loop variant or negative value reached`, from `XP_TEST_ROOT.test_cr_line_ends_with_deferred_positions` (#28); `Test executable failed for assertions-on / Finalized.` | 1 | [after-finalized-on.txt](after-finalized-on.txt) |
| 3 | After: `run_eiffel_test_matrix.ps1 -AssertionMode Off -BuildMode Finalized` | Unchanged, `ok` | `xpact Phase 1 tests: ok`, `xpact Eiffel test matrix: ok` | 0 | [after-finalized-off.txt](after-finalized-off.txt) |

Row 2 is the same violation the assertions-on Workbench lane reports
([issue-0028/matrix-on-workbench.txt](../issue-0028/matrix-on-workbench.txt)),
so the Finalized and Workbench lanes now agree.

## How to revert

```powershell
git revert <sha of this commit>
```
