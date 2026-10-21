# Student workspace (Mass)

Everything produced for the ten-week xpact student assignment lives in this
folder, so it stays separate from the parser code. The plan, the task register
(A01–H06) and the suggested task selection come from
[`docs/xpact-student-introduction.md`](../docs/xpact-student-introduction.md).

**Start here: [PLAN.md](PLAN.md)**: the 10-week plan and where things stand now
(the live status). [PLAN2.md](PLAN2.md) is the frozen, detailed record of weeks 1–2
as of 2026-10-15.

The clone on this PC is `C:\Users\masou\Desktop\Lia\xpact\xpactGit`. Make every
change there, never in a copied folder: a copy has no commit hash, so its
results can't be traced.

## Layout

| Path | What goes there |
|---|---|
| [`PLAN.md`](PLAN.md) / [`PLAN2.md`](PLAN2.md) | Live plan and status / frozen weeks 1–2 record |
| [`VERSIONING.md`](VERSIONING.md) | How every fix is made: issue, branch, report, pull request, squash merge, revert |
| [`tools/fix.ps1`](tools/fix.ps1) | Runs and checks those steps (`start`, `finish`, `merge`, `revert`, `status`) |
| [`git/commit-template.txt`](git/commit-template.txt) | Commit message template (asks for `Refs #<issue>`) |
| [`history/`](history/) | Weeks 1–2 before this repository: error reports, build fix notes, the old fixes as patches |
| [`baseline/`](baseline/) | The week 2 assertions-enabled baseline: script, event trace, logs, BASELINE.md |
| [`results/`](results/) | Evidence for task work that is **not** a code fix: investigations, orientation notes, measurements |
| [`notes/weekly/`](notes/weekly/) | Half-page weekly notes, one file per week |
| [`report/`](report/) | The university report, demonstration notes and handover guide (weeks 8–10) |
| [`github/`](github/) | Labels, milestones and issue drafts, plus `setup-github.ps1`, which creates them on GitHub |

Outside this folder:

| Path | What it is |
|---|---|
| [`../reports/`](../reports/) | **One folder per fix**, `reports/issue-NNNN/` (report with verification, logs), indexed in `reports/README.md`; dated error reports in `reports/error-reports/` |
| `.github/ISSUE_TEMPLATE/` | "Task" and "Finding" forms for new issues |
| `.github/pull_request_template.md` | The checklist for pull requests opened by hand (`fix.ps1 finish` writes its own) |
| `.github/workflows/python-harness.yml` | Runs the Python harness tests on every pull request (no Eiffel needed) |

## Branches

| Branch | Purpose |
|---|---|
| `main` | The teacher's code. Never commit to it directly. |
| `student-Mass` | Your integration branch. Every fix lands here as one squashed commit. |
| `fix/<issue>-<name>` | One short-lived branch per issue, e.g. `fix/7-msvc-c-backend`, made by `fix.ps1 start` from the latest `student-Mass` and deleted by `fix.ps1 merge` |

A `fix/...` branch that still exists belongs to an open pull request, e.g.
`fix/3-start-tag-loop-variant` for #12, which waits for review because it
changes the parser.

## Working on one issue

The full rules are in [VERSIONING.md](VERSIONING.md). In short:

```powershell
cd C:\Users\masou\Desktop\Lia\xpact\xpactGit
.\student\tools\fix.ps1 start -Issue 7 -Name msvc-c-backend   # branch + reports\issue-0007\
#   write the expected results in reports\issue-0007\report.md BEFORE testing,
#   change, test, save the logs next to the report, add "## Verification",
#   add a row to reports\README.md, commit (the template asks for "Refs #7")
.\student\tools\fix.ps1 finish                                # checks, pushes, opens the pull request
.\student\tools\fix.ps1 merge                                 # squash-merges into student-Mass
```

After merging:

- The pull request goes into `student-Mass`, not the default branch `main`, so
  "Closes #7" does **not** close the issue. Comment "Fixed in `<sha>` (PR #N)"
  on the issue and close it by hand.
- Update [PLAN.md](PLAN.md) when a planned task changes state, and write the
  week's note in [`notes/weekly/`](notes/weekly/).
- Parser changes (`src/`) are not merged by `fix.ps1 merge` until the parser's
  developer has reviewed the pull request.

## What every result must record

From the guide, "One issue at a time": for each result keep

- the input or its hash,
- the source revision (`git rev-parse HEAD`) and any uncommitted changes,
- compiler and assertion settings, callback configuration and chunk sizes,
- expected and actual outcome,
- the exact command and its exit status.

Keep confirmed observations separate from possible explanations. A green
manifest or a count of test definitions is not evidence that the tests passed.

## Logs in git

The repository's `.gitignore` excludes `*.log`. An exception lets `.log` files
under `student/` be committed, because they are the evidence. Build output
(`EIFGENs/`, `build/`, `*.exe`) is still ignored everywhere.
