# Report: issue #115, bring the student docs up to date (2026-10-26)

Issue: [#115](https://github.com/andersoxie/xpact/issues/115)   Branch: `fix/115-docs-2026-10-26`   Base: `student-Mass` @ `97795fb`   Date: 2026-10-26

## In short

Six student pages still described 22 October: B03, #38-#40 and the DLL smoke
crash "broken" or "on hold", the supervisor page asking questions that have
since been answered, no week 4 note. They now describe `97795fb` (0 behind
`main`). Docs only; no code, no earlier evidence changed.

## What changed

| Page | Before | After |
|---|---|---|
| `student/PLAN.md` | header @ `41731c8`; week 4 ⬜; "Merged since" stopped at #103; "Next" listed Python 3.10 and long paths | header @ `97795fb`, 0 behind `main`; week 4 🟡 with what is done; rows for #105, #107, #109, #111/#112, #114; "Next" rewritten |
| `student/README.md` | "Updated 2026-10-22 … B03 … on hold" | 2026-10-26 status; newest results point to the #110 report |
| `student/GUIDE.md` | section 6: #3, #38, #39, #40, draft 07 listed as broken | section 6 rebuilt from the 2026-10-26 results; only #73/#74/#79 (Jenkins), #13 and the Jenkins "Eiffel Tests" stage left |
| `reports/README.md` | "20 fixes … draft #12 … on hold" | 43 rows (with #115), PR #76 open, Jenkins rerun pending |
| `student/for superviser.txt` | status and 5 questions of 2026-10-22 | status of 2026-10-26; the 4 answered questions listed as answered; 6 open questions |
| `student/notes/weekly/week-04.md` | did not exist | new, from `TEMPLATE.md` |

## Facts checked before writing them down

| Statement | Check | Result |
|---|---|---|
| `student-Mass` is 0 behind `main` | `git rev-list --count origin/student-Mass..origin/main` | 0 |
| #12, #80, #72, #78 merged by the supervisor | `gh pr view N --json mergedBy` | `andersoxie` for all four |
| 43 rows in `reports/README.md` (with #115) | `grep -c '^| \[#' reports/README.md` | 43 |
| Test results quoted | [#110 report](../issue-0110/report.md), [#113 report](../issue-0113/report.md) | as quoted |

## Verification

| # | Check | Expected | Actual | |
|---|---|---|---|---|
| 1 | earlier evidence untouched: `git diff --name-only origin/student-Mass -- student/baseline student/results 'reports/issue-*'` | nothing | nothing | ✅ |
| 2 | link check over `student/`, `reports/`, `docs/` | 0 broken | 0 broken | ✅ |
| 3 | `git diff --stat origin/student-Mass` | the six pages, `reports/README.md`, this report | as expected | ✅ |

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 115 -Commit <merged sha>
```
