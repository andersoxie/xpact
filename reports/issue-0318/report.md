# #318 · `fix.ps1` squash-merged into the deleted `student-Mass`

| | |
|---|---|
| Status | ✅ fixed and checked locally (2026-11-11) |
| Issue | [#318](https://github.com/andersoxie/xpact/issues/318) |
| Files | `student/tools/fix.ps1`, `student/VERSIONING.md` |

## 1. Problem

`student/tools/fix.ps1` still followed the workflow from before 2026-11-08, without saying so:

| # | What the script did | Rule now (CLAUDE.md, VERSIONING.md) |
|---|---|---|
| 1 | default `-Base student-Mass` (branch deleted 2026-11-10) | work branch `incremental-test` |
| 2 | `merge` ran `gh pr merge --squash` | merge commit, never squash |
| 3 | `merge` ran `git branch -D` (drops unmerged work too) | keep anything not merged |
| 4 | `revert` ran `git revert <sha>`; fails on a merge commit ("is a merge but no -m option was given") | every PR since 2026-11-10 is a merge commit |
| 5 | nothing stopped `-Base main` | never touch `main` |

- **Environment:** student PC, Windows 11, Windows PowerShell 5.1, `incremental-test` @ `2862bdc`.
- **Command:** reading the source (`fix.ps1` lines 17, 132, 211, 215).
- **Cause:** ✅ confirmed: the script was written for `student-Mass` (#5) and not changed when the branch and the merge rule changed.

## 2. Fix

- `-Base` defaults to `incremental-test`; `-Base main` throws before anything runs.
- `merge`: checks that the pull request's base is `-Base`, then `gh pr merge --merge`; local branch removed with `git branch -d`.
- `revert`: adds `-m 1` when the commit has two parents (reverts a whole merged pull request).
- `VERSIONING.md`: the box, step 6, the by-hand commands and the revert section say the same.

## Verification

Run on `fix/318-fix-ps1-merge-commits`, Windows PowerShell 5.1:

| Check | Command | Result |
|---|---|---|
| Syntax | `[Parser]::ParseFile("student\tools\fix.ps1", …)` | ✅ 0 errors |
| `main` refused | `.\student\tools\fix.ps1 status -Base main` | ✅ throws "fix.ps1 does not work on main…" |
| Normal run | `.\student\tools\fix.ps1 status` | ✅ prints the branch and the last commits |
| Revert of a merge commit | the new revert lines on `2862bdc` (Merge PR #317) in a detached worktree | ✅ exit 0; tree equals `2862bdc^1` (`git diff --stat` empty) |

Not checked: `fix.ps1 merge` end to end (it would merge a real pull request); this PR itself is merged with `gh pr merge --merge`, the same command the script now runs.
