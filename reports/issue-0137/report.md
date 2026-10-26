# Report: issue #137, finish PR #76 and clean up merged branches

Issue: [#137](https://github.com/andersoxie/xpact/issues/137)   Branch: `fix/137-branch-cleanup`   Base: `student-Mass` @ `7cf5a94`   Date: 2026-10-26

## In short

| | |
|---|---|
| ✅ PR #76 (#74) | brought up to `student-Mass` (no conflicts), retested, squash-merged as `7cf5a94`. #74 **stays open** for a Jenkins run |
| ✅ GitHub branches | 11 merged branches deleted on andersoxie/xpact; `main` and `student-Mass` unchanged by the deletions |
| ✅ Local branches | 20 deleted in the clone; `student-Mass` and `portfolio` kept |
| ✅ mass-xpact copy | the same branches deleted there after the portfolio refresh; its `main` unchanged |
| Not touched | `main`, the supervisor's 13 `codex/*` branches |

## Expected results (in #137, written before)

| # | Expected | Actual | |
|---|---|---|---|
| 1 | every deleted branch has a MERGED pull request | 11 of 11 (10 into `student-Mass`, `fix/w3c-known-failures` into `main` by the supervisor, PR #80) | ✅ |
| 2 | `main` and `student-Mass` unchanged by the deletions | before and after: `main` = `de01371`, `student-Mass` = `7cf5a94` | ✅ |
| 3 | PR #76 builds pass | compiler choice 8/8, both DLL smokes ok, runtime smoke ok, matrix 4/4 (MSVC); [#74 report, section 6](../issue-0074/report.md) | ✅ |

## Evidence

[`branch-cleanup.txt`](branch-cleanup.txt): every deleted branch with its last
commit and its PR, the heads of `main` and `student-Mass` before and after,
and the branches left. A deleted branch can be restored from its tip:
`git push origin <tip>:refs/heads/<name>`.

`student-test` (local only, 2026-09-27) was checked before it was deleted:
`git log student-Mass..student-test` is empty, so nothing was lost.

## Commands

```powershell
gh pr list -R andersoxie/xpact --head <branch> --state all   # must be MERGED
git push origin --delete <branch>
git branch -D <branch>                                      # local
git push mine --delete <branch>                             # mass-xpact copy
```
