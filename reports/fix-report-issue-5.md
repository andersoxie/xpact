# Fix report: issue #5, versioning workflow for fixes

Issue: [#5](https://github.com/andersoxie/xpact/issues/5)   Branch: `fix/5-versioning-workflow`   Date: 2026-10-20

## Why

Many fixes (several hundred pushes) will go to `student-Mass`. Until now, fixes
were committed straight onto `student-Mass`, with nothing to check that they
name an issue or include test evidence. Some fixes were also made in a copied
folder (`xpact3.0\...`) that is not a git clone, so they had no commit hash at
all.

## What changed

| File | Purpose |
|---|---|
| `student/VERSIONING.md` | The rules, the step-by-step workflow, how to revert, how to find things later, review-point tags, setup |
| `student/tools/fix.ps1` | `start`, `finish`, `merge`, `revert`, `status`; checks the rules |
| `student/git/commit-template.txt` | Commit message template that asks for `Refs #<issue>` |

Each fix gets its own branch `fix/<issue>-<name>`, report and pull request, and
is squash-merged. So each fix is one commit on `student-Mass`, and reverting it
is a new commit (no history rewriting).

Local settings applied to this clone (not committed; listed in VERSIONING.md,
section Setup): `commit.template`, `pull.ff=only`, `fetch.prune=true`,
`push.autoSetupRemote=true`.

## Verification

Windows PowerShell 5.1, GitHub CLI 2.102.0, clone
`C:\Users\masou\Desktop\Lia\xpact\xpactGit`.

| # | Command | Expected | Actual | Exit |
|---|---|---|---|---|
| 1 | Parse `student/tools/fix.ps1` with the PowerShell parser | No syntax errors | 0 errors | - |
| 2 | `fix.ps1 status` (run from another folder) | Shows the branch and the last commits | Branch `student-Mass` and 5 commits shown | 0 |
| 3 | `fix.ps1 finish` on `student-Mass` | Refused: not a fix branch | "Not on a fix branch (fix/<issue>-<name>): student-Mass" | 1 |
| 4 | `fix.ps1 start -Issue 5 -Name versioning-workflow` | New branch from the latest `student-Mass` | "On fix/5-versioning-workflow, from student-Mass @ 9eb18bd" and the issue title | 0 |
| 5 | `fix.ps1 finish` with a commit that has no `Refs #5` | Refused | "Commit 1efaafb does not mention #5" | 1 |
| 6 | `fix.ps1 finish` with `Refs #5` but no fix report | Refused | "Missing reports/fix-report-issue-5.md" | 1 |
| 7 | `fix.ps1 finish` with this report committed | Pushes and opens a pull request | See the pull request for this issue | 0 |
| 8 | `fix.ps1 merge` | One squashed commit on `student-Mass`, branch deleted | See `git log --first-parent student-Mass` | 0 |

Rows 7 and 8 are this pull request itself going through the workflow.

Not tested yet: `fix.ps1 revert`. It will be tested the first time a fix has to
be reverted.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 5 -Commit <merged sha>
```

That removes `student/VERSIONING.md`, `student/tools/fix.ps1` and
`student/git/commit-template.txt`. The local git settings stay; remove them
with `git config --unset <name>` if needed.
