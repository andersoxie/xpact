# Fix report: issue #55, test matrix started outside the repository root runs a stale xpact_tests.exe and reports ok

Issue: [#55](https://github.com/andersoxie/xpact/issues/55)   Branch: `fix/55-project-path`   Base: `f22e3e7`   Date: 2026-10-22

## Why

`run_eiffel_test_matrix.ps1` passed `ec` an absolute `-config` path, but `ec`
writes `EIFGENs` to the **current folder**. The rest of the lane
(`finish_freezing`, the test executable) used `$RepoRoot\EIFGENs\...`. Started
from any other folder, the lane compiled into that folder and then finished
and ran whatever was left in the repository's `EIFGENs`, also with the
**current folder outside the repository**, where tests that read repository
files fail. Depending on what was left there, the result was:

- a **false pass**: the old C code relinked, a test printed `FAIL`, but the
  executable exited 0 (open bug #45) and the script printed
  `xpact Eiffel test matrix: ok` (row 2 below); first seen in #53;
- or a confusing failure, `gcc.exe: C1/Cobj1.o: No such file or directory`
  (row 1).

Jenkins starts the script in the workspace root, so CI was not affected.

## Options

| Option | Result |
|---|---|
| Document "run from the repository root" | Easy to miss; a wrong folder still gives a green result |
| `ec -project_path $RepoRoot` (proposed in the issue) | The build lands in the repository, but the test executable still runs in the caller's folder, so tests that read repository files fail |
| **`Push-Location $RepoRoot` around all lanes, `Pop-Location` in `finally`** (chosen) | `ec`, `finish_freezing` and the tests all use the repository root; the caller's folder is restored, also when a lane throws |

## What changed

| File | Change |
|---|---|
| `scripts/run_eiffel_test_matrix.ps1` | The lane loop runs inside `Push-Location $RepoRoot` / `finally { Pop-Location }` |
| `student/report/setup-guide.md` | Section 3: the matrix switches to the root itself; hand-run `ec` still needs it |
| `student/PLAN.md` | #55 moved from Known problems to Solved |

## Verification

Windows PowerShell 5.1, EiffelStudio 25.12.9.8922, default mingw C backend
(`ISE_C_COMPILER` not set). [run-outside-root.ps1](run-outside-root.ps1)
creates `%TEMP%\xpact-issue55-cwd`, changes to it, prints the time stamp of
`EIFGENs\xpact_tests\W_code\xpact_tests.exe` in the repository, runs
`run_eiffel_test_matrix.ps1 -AssertionMode Off -BuildMode Workbench` by its full
path, prints the time stamp again and whether `EIFGENs` appeared in the outside
folder, then deletes that folder. Each run:
`cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File <script> > <log> 2>&1"`.

| # | Run | Expected | Actual | Exit | Log |
|---|---|---|---|---|---|
| 1 | Before, outside folder, repository `W_code` left half-built by earlier runs | Wrong result | `ec` asks for `finish_freezing` in `%TEMP%\xpact-issue55-cwd\EIFGENs\...`; the script runs it in the repository instead: `gcc.exe: C1/Cobj1.o: No such file or directory`, `finish_freezing failed` | 1 | [before.txt](before.txt) |
| 2 | Before, outside folder, after a clean run from the root (unfixed script, exit 0) | False pass | Same mismatch; old code relinked, `FAIL: Phase 1 documents Windows-only native release`, then `xpact Eiffel test matrix: ok`; `EIFGENs in the current folder: True` | 0 | [before-stale-exe.txt](before-stale-exe.txt) |
| 3 | After, outside folder | Build and tests in the repository, nothing in the outside folder | `finish_freezing` in `...\xpactGit\EIFGENs\xpact_tests\W_code`, exe rebuilt (09:39:11 to 09:39:44), `xpact Phase 1 tests: ok`, no `FAIL`; `EIFGENs in the current folder: False` | 0 | [after.txt](after.txt) |
| 4 | After, from the repository root | Unchanged | `xpact Phase 1 tests: ok`, `xpact Eiffel test matrix: ok` | 0 | [after-from-root.txt](after-from-root.txt) |

Row 2 also shows #45 again: a test printed `FAIL` and `xpact_tests.exe` still
exited 0.

## How to revert

```powershell
git revert <sha of this commit>
```
