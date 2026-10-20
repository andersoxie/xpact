# Fix report: issue #24, record the GitHub labels in the repository

Issue: [#24](https://github.com/andersoxie/xpact/issues/24)   Branch: `fix/24-record-labels`   Base: `student-Mass` @ `384f838`   Date: 2026-10-20

## Why

On 2026-10-20, nine labels were created on `andersoxie/xpact` with
`gh label create` and applied to every issue (#2-#22) and to pull request #12.
Labels are GitHub settings, not files, so nothing in the repository recorded
them. `student/github/labels.json` had no `workflow` label, and
`student/github/README.md` says to ask the supervisor before creating labels,
which was not done.

## What changed

| File | Change |
|---|---|
| `student/github/labels.json` | New `workflow` label (same colour and description as on GitHub); 15 labels |
| `student/github/README.md` | Label count; new section "Labels on GitHub (2026-10-20)": which labels exist, which issue has which, that they were created without asking first, what the templates add |
| `student/for superviser.txt` | Section "GitHub labels" (added without asking, can be removed) and question 4 "Keep the labels?" |
| `reports/README.md` | Commit `384f838` for #22; row for #24 |

Labels applied on GitHub (not a file change, listed here for the record):

| Labels | Issues |
|---|---|
| `type:finding` `group:B-reliable-results` `D2-guided` `P0` | #2, #4, #7, #10 |
| `type:finding` `group:C-correctness` `D3-advanced` `P0` | #3, pull request #12 (without `type:finding`) |
| `type:finding` `group:C-correctness` `D3-advanced` `P1` | #13 |
| `type:task` `workflow` | #5, #14, #16, #18, #20, #22, #24 |

## Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | `labels.json` parses as JSON | 15 entries |
| 2 | Each label of `labels.json` that exists on GitHub | Same colour and description as in `labels.json`; 9 of them exist |
| 3 | Relative links in `student/github/README.md` and `reports/README.md` | All resolve |
| 4 | `fix.ps1 finish` | Pushes and opens the pull request |

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/24-record-labels`,
Windows PowerShell 5.1, GitHub CLI 2.102.0.

| # | Command | Actual | Exit |
|---|---|---|---|
| 1 | `Get-Content student\github\labels.json -Raw \| ConvertFrom-Json` | `labels.json entries: 15` | - |
| 2 | `gh label list --json name,color,description`, compared with `labels.json` | `type:finding`, `type:task`, `group:B-reliable-results`, `group:C-correctness`, `D2-guided`, `D3-advanced`, `P0`, `P1`, `workflow`: all `matches labels.json: True`; `from labels.json on GitHub: 9` | 0 |
| 3 | Link check (regex over `](...)`, URL-decoded, `Test-Path` relative to the file) | Before this report: 1 broken, `issue-0024/report.md` (this file). After: 0 | - |
| 4 | `fix.ps1 finish` | See the pull request for this issue | 0 |

All expectations were met.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 24 -Commit <merged sha>
```

That only reverts the files. To remove the labels from GitHub as well:
`gh label delete <name> --repo andersoxie/xpact` for each of the nine labels.
