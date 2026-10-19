# Fix report: issue #16, update `student/PLAN.md` with the week 3 work

Issue: [#16](https://github.com/andersoxie/xpact/issues/16)   Branch: `fix/16-plan-update`   Base: `student-Mass` @ `4a957b1`   Date: 2026-10-20

## Why

`student/PLAN.md` was last changed on 2026-10-15 (`cd0e1e4`): every box was
unticked and every task linked only to its issue draft. Since then the week 1
build fixes, the versioning workflow, the report folders and the B03 analysis
were done on GitHub (issues #2-#14, pull requests #6-#15). `student/PLAN2.md`
still said the build fixes were "not in `main`", saved as patches, and called
`PLAN.md` "the empty version".

## What changed

**`student/PLAN.md`**
- Intro: tasks link to the GitHub issue when one exists, otherwise to the draft;
  points to `VERSIONING.md` and `reports/README.md`.
- New "Where things stand" table: current week (3), what was done, what waits
  for review (#12), what is still blocked (fixes on `student-Mass`, not `main`)
  and what is next (A02 rerun in git, B01/B02, week 3 note).
- Week 1: native build and first error report ticked; A01 left open with what
  is still missing.
- Week 2: baseline ticked; A02 left open (rerun in git is next); B03 ticked as
  reported (#3, fix in #12); new finding #13 added; the crash and Jenkins
  findings from `PLAN2.md` added to the list.
- New section "Build fixes and workflow in git (week 3)": one row per issue with
  pull request, merged commit and report; which parts of patch 01 and 02 are
  still not applied.
- Week 3: week 3 note added. Weeks 4-10 unchanged.

**`student/PLAN2.md`**
- A note at the top: snapshot as of 2026-10-15, current status in `PLAN.md`,
  and what changed since. The rest is unchanged, so it stays an accurate record
  of weeks 1-2.

**`reports/README.md`**: row for #16.

## Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | Every relative link in `PLAN.md` and `PLAN2.md` | Resolves |
| 2 | In-page link `#build-fixes-and-workflow-in-git-week-3` | Matches the GitHub anchor of the section heading |
| 3 | Issue states and merge commits named in `PLAN.md` | Match GitHub |
| 4 | `fix.ps1 finish` | Pushes and opens the pull request |

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/16-plan-update`,
Windows PowerShell 5.1, GitHub CLI 2.102.0.

| # | Command | Actual | Exit |
|---|---|---|---|
| 1 | Link check (regex over `](...)`, `Test-Path` relative to the file) on `student\PLAN.md`, `student\PLAN2.md` | `relative links: 104, broken: 0` | - |
| 2 | Heading `## Build fixes and workflow in git (week 3)` lowercased, punctuation removed, spaces to dashes; `grep -c "(#build-fixes-and-workflow-in-git-week-3)" student/PLAN.md` | slug `build-fixes-and-workflow-in-git-week-3`; used `1` time | 0 |
| 3 | `gh issue list --state all`, `gh pr list --state all` (with merge commits) | Closed: #2, #4, #5, #7, #10, #14. Open: #3, #13, #16. Merged: #6 `cada501`, #8 `eb6fc5d`, #9 `3b8a205`, #11 `20e6bc3`, #15 `4a957b1`. Open: #12. All as written in `PLAN.md` | 0 |
| 4 | `fix.ps1 finish` | See the pull request for this issue | 0 |

All expectations were met.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 16 -Commit <merged sha>
```
