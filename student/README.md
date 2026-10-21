# Student workspace (Mass)

Everything produced for the ten-week xpact student assignment lives in this
folder, so it stays separate from the parser code. The plan, the task register
(A01–H06) and the suggested task selection come from
[`docs/xpact-student-introduction.md`](../docs/xpact-student-introduction.md).

**Start here: [PLAN.md](PLAN.md)**: the 10-week plan and where things stand now
(the live status). [PLAN2.md](PLAN2.md) is the frozen, detailed record of weeks 1–2
as of 2026-10-15.

## Find it fast

| I want to see… | Open |
|---|---|
| Where things stand and what's next | [PLAN.md](PLAN.md), section "Where things stand" and "Next tests" |
| A one-page status for the supervisor | [`for superviser.txt`](for%20superviser.txt) |
| Every fix: issue, pull request, commit, report | [`../reports/README.md`](../reports/README.md) |
| What failed on a given day | [`../reports/error-reports/`](../reports/error-reports/) |
| Test results and investigations | [`results/README.md`](results/README.md) |
| The week 2 baseline | [`baseline/BASELINE.md`](baseline/BASELINE.md) |
| Weekly notes | [`notes/weekly/`](notes/weekly/) |
| Issues not on GitHub yet | [`github/issues/`](github/issues/), listed in [`github/README.md`](github/README.md) |
| How to make and revert a fix | [VERSIONING.md](VERSIONING.md) |

The clone on this PC is `C:\xpact\xpact-student-Mass`. Make every
change there, never in a copied folder: a copy has no commit hash, so its
results can't be traced.

## Tools on this PC (2026-10-21)

| Tool | Where | Note |
|---|---|---|
| Python 3.15 | `%APPDATA%\uv\python\cpython-3.15.0-windows-x86_64-none\python.exe` | Installed with uv, **not on `PATH`**: `python` opens the Microsoft Store alias. Call it by its full path, or run `uv python install --default` once |
| GitHub CLI 2.102 | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\gh.exe` | Installed with winget, logged in as `CodTanium`. A VS Code terminal opened before the install doesn't find `gh` until VS Code is restarted |
| EiffelStudio 25.12, Visual Studio 18 (MSVC 14.51) | standard install paths | `ec` is on `PATH`; load MSVC with `. .\scripts\import_msvc_environment.ps1` |

`tools/fix.ps1` does not work in **Windows PowerShell 5.1**: git writes normal
messages ("Already on …", push progress) to stderr, and the script stops on
them. Until that is fixed, do its steps by hand, as described in
[VERSIONING.md](VERSIONING.md#fixps1-in-windows-powershell-51).

## Layout

| Path | What goes there |
|---|---|
| [`PLAN.md`](PLAN.md) / [`PLAN2.md`](PLAN2.md) | Live plan and status / frozen weeks 1–2 record |
| [`VERSIONING.md`](VERSIONING.md) | How every fix is made: issue, branch, report, pull request, squash merge, revert |
| [`tools/fix.ps1`](tools/fix.ps1) | Runs and checks those steps (`start`, `finish`, `merge`, `revert`, `status`) |
| [`git/commit-template.txt`](git/commit-template.txt) | Commit message template (asks for `Refs #<issue>`) |
| [`history/`](history/) | Weeks 1–2 before this repository: error reports, build fix notes, the old fixes as patches |
| [`baseline/`](baseline/) | The week 2 assertions-enabled baseline: script, event trace, logs, BASELINE.md |
| [`results/`](results/) | Evidence for task work that is **not** a code fix: investigations, orientation notes, measurements, test runs |
| [`notes/weekly/`](notes/weekly/) | Half-page weekly notes, one file per week |
| [`report/`](report/) | The university report, demonstration notes and handover guide (weeks 8–10) |
| [`github/`](github/) | Labels, milestones and issue drafts, plus `setup-github.ps1`, which creates them on GitHub |
| [`for superviser.txt`](for%20superviser.txt) | One-page status for the supervisor |

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
cd C:\xpact\xpact-student-Mass
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
