# Fix report: issue #14, one folder per fix under `reports/`

Issue: [#14](https://github.com/andersoxie/xpact/issues/14)   Branch: `fix/14-reports-layout`   Base: `student-Mass` @ `20e6bc3`   Date: 2026-10-20

## Why

`reports/` was one flat list: 18 files for 5 fixes, named
`fix-report-issue-<N>.md` and `fix-issue-<N>-<what>.txt`.

- Names sort as text, so GitHub listed issue 10 before issue 2.
- At 3-5 files per fix, the ~500 planned fixes would mean ~2,000 files in one
  folder. GitHub's folder view stops at 1,000 entries.
- Only a name prefix tied a report to its logs.

## What changed

| Before | After |
|---|---|
| `reports/fix-report-issue-<N>.md` | `reports/issue-<NNNN>/report.md` |
| `reports/fix-issue-<N>-<what>.txt` | `reports/issue-<NNNN>/<what>.txt` |
| `reports/error-report-2026-10-19.md` | `reports/error-reports/2026-10-19.md` |
| (none) | `reports/README.md`: index of every fix with issue, pull request, commit and report |

`<NNNN>` is the issue number padded to four digits (`issue-0002`), so the
folders sort by number up to issue 9999.

- **Moves:** all 18 files with `git mv`; git records them as renames, so
  `git log --follow` still shows each file's history.
- **Links inside the reports:** the links to logs in #2, #4, #7 and #10 and the
  link to the error report in #2 now use the new names. Quoted command lines
  and error messages (for example `-File fix-issue-4-repeat-import.ps1` in #4,
  "Missing reports/fix-report-issue-5.md" in #5) are records of what was run or
  printed at the time, and were left as they were. `student/history/` is the
  pre-git record and was not touched.
- **`student/tools/fix.ps1`:** new `Get-ReportDirectory`; `finish` checks
  `reports/issue-<NNNN>/report.md`; `start` creates the folder and prints its
  path; `revert` prints the new path.
- **`student/VERSIONING.md`:** rule 5 and the step-by-step and revert examples.

Links from earlier pull requests and issue comments to
`blob/<commit>/reports/fix-report-issue-<N>.md` still work, because they point
at a fixed commit. One link points at the branch instead
(`blob/student-Mass/reports/fix-report-issue-2.md`, in the closing comment on
#2) and would show "not found" after the merge, so a comment on #2 gives the
new location.

## Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | PowerShell parser on `fix.ps1` | 0 errors |
| 2 | Folder name for issues 2, 14, 1234 | `issue-0002`, `issue-0014`, `issue-1234` |
| 3 | Every relative link in `reports/**/*.md` and `VERSIONING.md` | Resolves to an existing file |
| 4 | `git diff -M --name-status` of the move commit | 18 renames, no delete/add pairs |
| 5 | `git log --follow reports/issue-0007/report.md` | Shows the original commit `eb6fc5d` |
| 6 | `fix.ps1 finish` with the move committed but no report for #14 | Refused: "Missing reports/issue-0014/report.md", exit 1, nothing pushed |
| 7 | `fix.ps1 start -Issue 14 -Name start-test` | Creates `reports/issue-0014/` and prints that path |
| 8 | `fix.ps1 finish` with this report | Pushes and opens the pull request |

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/14-reports-layout`,
Windows PowerShell 5.1, GitHub CLI 2.102.0.

| # | Command | Actual | Exit |
|---|---|---|---|
| 1 | `[Parser]::ParseFile("student\tools\fix.ps1", ...)` | `parse errors: 0` | - |
| 2 | `"reports/issue-{0:D4}" -f $n` for 2, 14, 1234 | `reports/issue-0002`, `reports/issue-0014`, `reports/issue-1234` | - |
| 3 | Link check over `reports\**\*.md` and `student\VERSIONING.md` | Before this report existed: 1 broken link, `issue-0014/report.md` (this file). After: 0 | - |
| 4 | `git diff -M --name-status HEAD~1 HEAD` (commit `5b98e3c`) | `renames: 18` | 0 |
| 5 | `git log --follow --oneline -- reports/issue-0007/report.md` | `5b98e3c Move each fix's report ...`, `eb6fc5d Build the native Eiffel library ... (#8)` | 0 |
| 6 | `powershell -File student\tools\fix.ps1 finish` | "Missing reports/issue-0014/report.md. Every fix needs a report with a Verification section." Nothing pushed | **1** |
| 7 | `fix.ps1 start -Issue 14 -Name start-test` (throwaway branch, deleted afterwards) | "On fix/14-start-test, from student-Mass @ 20e6bc3", "Next: fix, test, write reports/issue-0014/report.md (logs next to it) ..."; `Test-Path reports\issue-0014` = `True` | 0 |
| 8 | `fix.ps1 finish` | See the pull request for this issue | 0 |

All expectations were met. Row 8 is this pull request itself.

Not tested: `fix.ps1 revert` (its only change is the path in a printed message).

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 14 -Commit <merged sha>
```

That moves the files back to the flat names and restores the old checks in
`fix.ps1`. Reports added after this fix would need moving by hand.
