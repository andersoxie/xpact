# Fix report: issue #20, bring the student docs in line with the week 3 workflow

Issue: [#20](https://github.com/andersoxie/xpact/issues/20)   Branch: `fix/20-docs-week3-sync`   Base: `student-Mass` @ `df189d9`   Date: 2026-10-20

## Why

Week 3 moved every fix to `reports/issue-NNNN/` and the `fix.ps1` workflow, but
several documents still described the week 2 setup, and some week 3 results
were missing from the places that should hold them. An audit on 2026-10-20 found
the gaps listed in #20.

## Expected results (written before the change)

| # | Check | Expected |
|---|---|---|
| 1 | `git diff --stat origin/student-Mass` | Only documentation files (`*.md`, the pull request template, one issue draft) and this report; no code, script or ECF changes |
| 2 | Relative links in every changed Markdown file | All resolve |
| 3 | Old wording searched in `student/`, `reports/`, `.github/` | No "PLAN.md is the empty version", no `Documents\xpact-student-mass` path, no "Closes #" instruction for pull requests into `student-Mass`, no "apply the patches before rerunning" without saying most are already in git |
| 4 | Draft 05 title vs. issue #3 title | Identical, so `setup-github.ps1` skips it |
| 5 | `fix.ps1 finish` | Pushes and opens the pull request |

## What changed

| File | Change |
|---|---|
| `student/notes/weekly/week-03.md` | **New**: the week 3 note |
| `reports/error-reports/2026-10-19.md` | New "Outcome" section: issue, confirmed cause and status for each error. The original text is unchanged |
| `reports/README.md` | #18 commit `df189d9`; row for #20 |
| `student/README.md` | PLAN.md is the live plan (not "the empty version"); layout with `reports/`, `VERSIONING.md`, `tools/`, `git/`; `fix/<issue>-<name>` branches; workflow via `fix.ps1`; issues are closed by hand; the clone path |
| `student/results/README.md` | `results/` is for task evidence that is not a code fix; fixes go in `reports/issue-NNNN/` |
| `.github/pull_request_template.md` | `Refs #` instead of `Closes #` (with the reason); evidence in `reports/issue-NNNN/` |
| `student/baseline/BASELINE.md` | Dated updates: K1 root cause (#3, #12, #13); the deleted `student-test` branch and where its fixes are now |
| `student/baseline/README.md` | Don't reapply patch 01; what is still missing (`run_xmlconf_conformance.ps1`, patch 02); the clone path |
| `student/history/README.md` | "Applying the patches" replaced by a status table: which parts are in git (#2, #7, #10, #4) and which are not |
| `student/github/README.md` | Clone path; where `gh` is on this PC; table of drafts vs. real issues |
| `student/github/issues/05-finding-b03-postcondition.md` | Title made identical to #3; note that it was created as #3 |
| `student/github/issues/22-blocker-build-fixes.md` | Status note: on `student-Mass`, still not in `main` |
| `student/PLAN.md` | Last-updated commit; week 3 note ticked; #20 row; "Next" mentions the missing xmlconf runner and patch 02 |

Historical records are left as written and get dated "Update 2026-10-20" notes
instead (`BASELINE.md`, the error report, `week-01.md`, `week-02.md`,
`PLAN2.md`).

Verified while writing: `scripts/run_xmlconf_conformance.ps1` is not in the
repository, so `run_baseline.ps1 -Step xmlconf` cannot run yet (stated in
`baseline/README.md`).

## Verification

Clone `C:\Users\masou\Desktop\Lia\xpact\xpactGit`, branch `fix/20-docs-week3-sync`.

| # | Command | Actual | Exit |
|---|---|---|---|
| 1 | `git diff --cached --stat origin/student-Mass` | 14 files, all documentation: the 13 in the table above plus this report; no `src/`, `scripts/`, `tests/` or ECF files | 0 |
| 2 | Link check: every `](...)` in the changed `.md` files that is not `http(s):`, `mailto:` or `#`, anchor removed, `test -e` relative to the file | 106 relative links checked, **0 broken** | 0 |
| 3 | `grep -rnE` for the old wording over `student/`, `reports/`, `.github/` (`*.md`) | none found | - |
| 4 | `gh issue view 3 --json title` vs. line 2 of draft 05 | identical (`TITLE MATCH`) | 0 |
| 5 | `fix.ps1 finish` | See the pull request for this issue | 0 |

All expectations were met. While writing the week 3 note, one link pointed to
`reports/issue-0003/report.md`, which exists only on the #12 branch until it is
merged. It was changed to link pull request #12 instead.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 20 -Commit <merged sha>
```
