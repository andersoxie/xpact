# Fix report: issue #26, put the B03 work (#3, #12, #13) on hold

Issue: [#26](https://github.com/andersoxie/xpact/issues/26)   Branch: `fix/26-b03-on-hold`   Base: `student-Mass` @ `e6d6732`   Date: 2026-10-20

## Why

The student wants to check the B03 work further before presenting it to the
supervisor. `student/for superviser.txt` listed it under "Waiting for your
review" and asked "Review PR #12"; `student/PLAN.md` and `reports/README.md`
said pull request #12 was waiting for review.

Nothing about the work itself changes: #3 and #13 stay open, pull request #12
keeps its commit, and the analysis in #3, #12 and #13 is unchanged.

## What changed

| Where | Change |
|---|---|
| `student/for superviser.txt` | "Waiting for your review" section removed; question 1 ("Review PR #12") removed, the others renumbered; the labels line no longer names #3/#12/#13 |
| `student/PLAN.md` | "Waiting" row is now "On hold" with #3, #12, #13 and this issue; B03 line and week 3 table say "draft, on hold" |
| `reports/README.md` | "Open" paragraph is now "On hold"; commit `e6d6732` for #24; row for #26 |
| GitHub | Pull request #12 converted to draft (`gh pr ready 12 --undo`), so it no longer asks for review |

## Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | `grep -c "#12\|#13\|B03" "student/for superviser.txt"` | 0 |
| 2 | `gh pr view 12 --json isDraft,state` | `isDraft=true`, `state=OPEN` |
| 3 | Relative links in `student/PLAN.md` and `reports/README.md` | All resolve |
| 4 | `fix.ps1 finish` | Pushes and opens the pull request |

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/26-b03-on-hold`,
GitHub CLI 2.102.0.

| # | Command | Actual | Exit |
|---|---|---|---|
| 1 | `grep -c "#12\|#13\|B03" "student/for superviser.txt"` | `0` | 1 (no match) |
| 2 | `gh pr view 12 --json isDraft,state` | `PR #12 isDraft=true state=OPEN` | 0 |
| 3 | Link check (regex over `](...)`, `Test-Path` relative to the file) | Before this report: 1 broken, `issue-0026/report.md` (this file). After: 0 | - |
| 4 | `fix.ps1 finish` | See the pull request for this issue | 0 |

All expectations were met.

## Taking it off hold

```powershell
gh pr ready 12 --repo andersoxie/xpact
.\student\tools\fix.ps1 revert -Issue 26 -Commit <merged sha>
```

The first command asks for review on #12 again; the revert puts the
"Waiting for your review" section back into `for superviser.txt` and the
"Waiting" row back into `PLAN.md`.
