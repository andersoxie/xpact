# Fix report: issue #22, one-page status summary for the supervisor

Issue: [#22](https://github.com/andersoxie/xpact/issues/22)   Branch: `fix/22-supervisor-summary`   Base: `student-Mass` @ `4df05be`   Date: 2026-10-20

## What changed

| File | Change |
|---|---|
| `student/for superviser.txt` | **New**: one page on the 16 commits in `main..student-Mass` @ `4df05be`: code changes (why, what, where), items waiting for review (#12, #13), documentation-only commits, how fixes are made, questions for the supervisor |
| `reports/README.md` | Row for #22 |

## Expected results (written before checking)

| # | Check | Expected |
|---|---|---|
| 1 | Every commit in `origin/main..4df05be` | Named in the summary |
| 2 | Every 7-character hash in the summary | Is one of those commits, except `b930600` (the week 1 patch, described as such) |
| 3 | Code files named in the summary | Exactly `git diff --name-only origin/main 4df05be -- src scripts tests` |

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/22-supervisor-summary`.

| # | Command | Actual |
|---|---|---|
| 1 | `git rev-list --abbrev-commit origin/main..4df05be`, each searched in the file | all 16 listed |
| 2 | each hash in the file checked with `git merge-base --is-ancestor` against `4df05be` and `origin/main` | only `b930600` is outside the range, as intended |
| 3 | `git diff --name-only origin/main 4df05be -- src scripts tests` | the same 5 files as in the summary: `build_native_eiffel.ps1`, `import_msvc_environment.ps1`, `run_native_runtime_smoke.ps1`, `xpact_native_library.ecf`, `xpact_native_runtime.ecf` |

The summary is pinned to `4df05be`; later commits (this one included) are not in it.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 22 -Commit <merged sha>
```
