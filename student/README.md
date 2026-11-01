# Student workspace (Mass)

Everything produced for the ten-week xpact student assignment lives in this
folder, so it stays separate from the parser code. The plan, the task register
(A01–H06) and the suggested task selection come from
[`docs/xpact-student-introduction.md`](../docs/xpact-student-introduction.md).

> **Updated 2026-10-31 (week 7)** · describes `student-Mass` @ `c12b705`, which includes all of `main`.
> Weeks 1-7 ✅ (week 7: one table rerun left) · W3C 2,585 cases, 0 failed · the supervisor merged
> `student-Mass` into `main` and Jenkins passed (PR #177) · open problems and the left-to-do list:
> [PLAN.md](PLAN.md) ("Known problems", "Next" item 12) · #13 ⏸ on hold.

## Start here

| | Read | When |
|---|---|---|
| 1️⃣ | [GUIDE.md](GUIDE.md) | **Lost?** The whole project in plain words: what it is, the builds, the scripts, what to do next |
| 2️⃣ | [PLAN.md](PLAN.md) | **Every day.** Where things stand, pull requests to merge, the known problems, next steps |
| 3️⃣ | [`../CLAUDE.md`](../CLAUDE.md) and [VERSIONING.md](VERSIONING.md) | **Before a change.** How to report, test, branch and open a pull request |


## Find it fast

| I want to see… | Open |
|---|---|
| Where things stand and what's next | [PLAN.md](PLAN.md): "At a glance", "Known problems", "Next" |
| Every open problem and its cause | [PLAN.md, Known problems](PLAN.md#-known-problems-living-list) |
| The newest test results | W3C, all 2,585 cases: [`../reports/latest-2026-10-28/`](../reports/latest-2026-10-28/README.md) · xpact vs Expat across chunks: [`results/G03-comparison/`](results/G03-comparison/README.md) · each fix since: [`../reports/README.md`](../reports/README.md) |
| The open questions for the supervisor | [PLAN.md](PLAN.md), "Next", item 2 |
| Every fix: issue, pull request, commit, report | [`../reports/README.md`](../reports/README.md) |
| What failed on a given day | [`../reports/error-reports/`](../reports/error-reports/) |
| Test results and investigations | [`results/README.md`](results/README.md) |
| The week 2 baseline | [`baseline/BASELINE.md`](baseline/BASELINE.md) |
| Weekly notes | [`notes/weekly/`](notes/weekly/) |
| Issues not on GitHub yet | [`github/issues/`](github/issues/), listed in [`github/README.md`](github/README.md) |
| How to make and revert a fix | [VERSIONING.md](VERSIONING.md) |

The clone on this PC is `C:\Users\masou\Desktop\Lia\xpact\xpactGit`
(`xpact\w10-attr-defaults` and `xpact\w11-plan` are extra worktrees of it, used to
build several fixes side by side). Make every change there, never in a copied
folder: a copy has no commit hash, so its results can't be traced.

## Tools on this PC (2026-10-31)

| Tool | Where | Note |
|---|---|---|
| Python 3.14.0 | `%LOCALAPPDATA%\Programs\Python\Python314\python.exe` | On `PATH` as `python`; the project needs 3.11 or newer ([#113](../reports/issue-0113/report.md)) |
| GitHub CLI 2.102 | `%LOCALAPPDATA%\Programs\GitHubCLI\bin\gh.exe` | On `PATH`, logged in as `CodTanium` |
| EiffelStudio 25.12, Visual Studio 18 (MSVC 14.51) | standard install paths | `ec` is on `PATH`; load MSVC with `. .\scripts\import_msvc_environment.ps1` |

`tools/fix.ps1` works in **Windows PowerShell 5.1** for `start` and `finish` when it is run
plainly. Two things still stop it: adding `2>&1` (git's normal messages on stderr then count as
errors), and a pull request title with `""` in it (5.1 splits the argument). In those cases do the
step by hand, as described in [VERSIONING.md](VERSIONING.md#fixps1-in-windows-powershell-51).

## Layout

| Path | What goes there |
|---|---|
| [`GUIDE.md`](GUIDE.md) | The project in plain words (written 2026-10-21 as `guide.txt`, updated) |
| [`PLAN.md`](PLAN.md) | Live plan and status |
| [`VERSIONING.md`](VERSIONING.md) | How every fix is made: issue, branch, report, pull request, squash merge, revert |
| [`tools/fix.ps1`](tools/fix.ps1) | Runs and checks those steps (`start`, `finish`, `merge`, `revert`, `status`) |
| [`git/commit-template.txt`](git/commit-template.txt) | Commit message template (asks for `Refs #<issue>`) |
| [`history/`](history/) | Weeks 1–2 before this repository: error reports, build fix notes, the old fixes as patches |
| [`baseline/`](baseline/) | The week 2 assertions-enabled baseline: script, event trace, logs, BASELINE.md |
| [`results/`](results/) | Evidence for task work that is **not** a code fix: investigations, orientation notes, measurements, test runs |
| [`notes/weekly/`](notes/weekly/) | Half-page weekly notes, one file per week; other notes in [`notes/`](notes/), e.g. the [tests chosen on 2026-10-21](notes/next-tests-2026-10-21.txt) |
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

A `fix/...` branch that still exists belongs to an open pull request, or was merged and not
deleted yet (the list is in [PLAN.md](PLAN.md), "Next" item 12).

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
- Parser changes (`src/`): at first they waited for the parser's developer. Since
  2026-10-28 they are merged into `student-Mass` after the full check set (both builds, compared
  with Expat 2.8.1; see each `reports/issue-NNNN/report.md`); the supervisor reviews them when he
  merges `student-Mass` into `main`.
- An issue is closed after the result is checked locally on `student-Mass`; no Jenkins run is
  needed (student decision, 2026-10-31).

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
