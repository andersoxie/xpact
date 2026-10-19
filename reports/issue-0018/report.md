# Fix report: issue #18, mark A01 as done in `student/PLAN.md`

Issue: [#18](https://github.com/andersoxie/xpact/issues/18)   Branch: `fix/18-a01-done`   Base: `student-Mass` @ `b631e15`   Date: 2026-10-20

## Why

The student finished task A01 (orientation: XML events, contracts, Git and the
repository layout; one accepted and one rejected document traced to their test
and parser path) and confirmed it on 2026-10-20. `student/PLAN.md` still showed
A01 as "partly done".

## What changed

| File | Change |
|---|---|
| `student/PLAN.md` | A01 ticked, with the date and this issue; "Also done" row in "Where things stand" |
| `student/github/issues/01-A01.md` | "Done (2026-10-20)" note above the earlier "Partly done" note, which is kept as history |
| `reports/README.md` | Row for #18 |

The A01 draft's "Done when" list asks for notes in
`student/results/A01-orientation/`. That folder is not in the repository yet,
so `PLAN.md` names it as the place for the notes on the checking tests and the
change-and-predict exercise.

## Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | `git diff --stat` against `student-Mass` | Only the three files above, plus this report |
| 2 | Relative links in the changed files | All resolve, except the planned `results/A01-orientation/`, which is not written as a link |
| 3 | `fix.ps1 finish` | Pushes and opens the pull request |

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/18-a01-done`.

| # | Command | Actual | Exit |
|---|---|---|---|
| 1 | `git diff --stat origin/student-Mass` | `reports/README.md`, `reports/issue-0018/report.md`, `student/PLAN.md`, `student/github/issues/01-A01.md` | 0 |
| 2 | Link check (regex over `](...)`, `Test-Path` relative to the file) | 0 broken | - |
| 3 | `fix.ps1 finish` | See the pull request for this issue | 0 |

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 18 -Commit <merged sha>
```
