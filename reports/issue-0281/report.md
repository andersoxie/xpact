# Issue #281: docs housekeeping, status lines that are out of date

| Item | Value |
|---|---|
| Issue | [#281](https://github.com/andersoxie/xpact/issues/281) (label `documentation`) |
| Branch | `docs/housekeeping-2026-11-11`, from `incremental-test` @ `7667a16` |
| Change | docs only, no code, no test result changed |
| Status | ✅ done, see Verification |

## Problem

Status lines in the docs said things that were no longer true on 2026-11-11 (details in the issue).

## Facts checked before editing (2026-11-11)

| Claim in the docs | Checked with | Result |
|---|---|---|
| #227 open | `gh issue view 227` | CLOSED 2026-11-10 |
| mass-xpact #84, #73, #75 not refiled | `gh issue list` | refiled as #272, #273, #274 (open) |
| merge `incremental-test` into `main` to do | `git rev-list --left-right --count origin/main...origin/incremental-test` | `3 0`: `main` has everything; 3 commits only on `main` |
| PR for #151 not merged, #151 open | `gh issue view 151`, PR search | PR #152 merged; #151 closed 2026-10-31; #147, #149 closed 2026-10-28 |
| PR for #210 not merged | `gh pr list --head fix/210-xpact-website` | PR #212 merged 2026-11-02 |
| no load test | PR #258 | load test done (#255, `website/docs/load-test.md`) |
| reports not updated with week 8 | `git log -- student/report/ActualReport.md` | updated in PR #269 (2026-11-10) |
| branches `fix/124…175` still there | `git branch -r` | gone; only `fix/197-parallel-test2` left |
| code-review line numbers | read `WorkerRunner.cs:90-101`, `appsettings.json:8` | match the findings |

## Changes

- `student/PLAN.md`, `student/CONTINUE-HERE.md`, `student/notes/weekly/week-08.md`: status lines updated (list above).
- `student/report/ActualReport.md`: "file #73, #75, #84 on andersoxie" ticked (#273, #274, #272).
- `reports/issue-0151/report.md`, `reports/issue-0210/report.md`: done "Next" boxes ticked with the proof; a dated update note under the 0210 limitations (the original lines stay as they were).
- `website/docs/testing.md`, `website/docs/roadmap.md`: memory-cap test, load test and forwarded headers marked done; HTTPS marked as the supervisor's.
- `website/docs/security.md`: new section with the 7 code-review findings of 2026-11-11, all marked **suspected, not tested**.
- `TODO_CODE_REVIEW.md`: a status note that the old boxes were never updated. No box was ticked, because each would need its own proof.

Not changed on purpose: older mass-xpact reports (history), `results.tsv` absolute paths (evidence), the `fix/197-parallel-test2` branch (#197 still open).

## Verification

See `link-check.txt`: every relative link in the changed files points to a file that exists.
