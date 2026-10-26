# Report: issue #134, student docs up to date after week 5

Issue: [#134](https://github.com/andersoxie/xpact/issues/134)   Branch: `fix/134-docs-week5`   Base: `student-Mass` @ `e847813`   Date: 2026-10-26

## In short

| | |
|---|---|
| Change | Docs only: merge commits for #128 and #132 in `reports/README.md`; issues #130, #131 linked in the plan's Known problems; the "Merged since" table brought up to #132; week 5 note |
| Correction | The cause icons for #122, #123, #126 and #131 said ❔ (unknown) next to "suspected". The plan's legend uses ❓ for suspected, so they now show ❓ (plan and `student/results/expat-2.8.1/README.md`) |

## Verification

| # | Check | Actual | |
|---|---|---|---|
| 1 | link check of the changed pages | 0 broken | ✅ |
| 2 | `git diff --stat` | only `.md` files under `reports/` and `student/` | ✅ |

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 134 -Commit <merged sha>
```
