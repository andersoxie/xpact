# GitHub setup

How the work is tracked on [andersoxie/xpact](https://github.com/andersoxie/xpact):
**one issue per problem or task**, labels to sort them, one milestone per
project week, and a pull request into `student-Mass` for every change
(never into `main`; see [`CLAUDE.md`](../../CLAUDE.md)).

| | What | State (2026-10-22) |
|---|---|---|
| ✅ | Labels | 21, listed in [`labels.json`](labels.json); all on GitHub except 6 (see below) |
| ✅ | Milestones | `Week 1 - Setup` … `Week 10 - Handover`, in [`milestones.json`](milestones.json), all on GitHub |
| ✅ | Issues | #2-#40 on GitHub, each with a milestone and labels; drafts for the rest in [`issues/`](issues/) |
| ⬜ | Project board | Not created: `gh` needs the `project` scope first (`gh auth refresh -s project`, in the browser) |

## Labels

Two kinds, used together on every issue.

**What kind of work** (from `CLAUDE.md`, created 2026-10-22 in [#35](https://github.com/andersoxie/xpact/issues/35)):

| Label | Use it for |
|---|---|
| `bug` | Something in xpact that does not work |
| `test` | Tests, test runs and test tools |
| `build` | Build scripts, ECFs, compilers, the C backend |
| `documentation` | Docs, plans, reports |
| `regression` | A regression test, or something that used to work |
| `investigation` | The cause is not confirmed yet |

**Where it belongs in the task register** (created 2026-10-20 in [#24](https://github.com/andersoxie/xpact/issues/24), first without asking the supervisor; noted in [`for superviser.txt`](../for%20superviser.txt)):

| Labels | Meaning |
|---|---|
| `type:finding` / `type:task` / `type:blocker` | Something observed that is wrong / planned work / stops other work |
| `group:A` … `group:G` | Task group of the register (A orientation, B reliable results, C correctness, F core, G verification) |
| `D1-beginner` … `D4-expert` | How much help it needs |
| `P0` / `P1` | Must be solved first / after P0 |
| `workflow` | Versioning, reports and plan updates (not a project finding) |

Not on GitHub yet: `group:A-orientation`, `group:F-core`,
`group:G-verification`, `D1-beginner`, `D4-expert`, `type:blocker`. The issue
templates add `type:finding` or `type:task` by themselves; add the others by hand.

## Milestones and issues

Due on the Friday of each week; week 1 started on 2026-10-05.

| Milestone | Issues on GitHub | Drafts not on GitHub yet |
|---|---|---|
| Week 1 - Setup | #2, #4, #7, #10 (build fixes), #18 (A01) | |
| Week 2 - Baseline | #3 (B03), #13, #33 (A02) | 04 `-keep`, 06 runner stops, 07 DLL crash, 21 xmlconf crashes, 22 build fixes not in `main` |
| Week 3 - Failure reporting | #5, #14, #16, #20, #22, #24, #26, #34, #35 (workflow) · #28 (CR loop variant), #29 (W3C run), #32 (Python 3.10) | 09 B01, 10 B02, 23 Jenkins precompile |
| Week 4 - Input matrix | | 11 G01, 12 xmlconf verdicts |
| Week 5 - Regressions | #37 (DLL test program) · #38 (C01), #39 (UTF-8), #40 (chunk ends with `<`) | 13 C02, 14 C03, 15 C10 (now partly covered by #37) |
| Week 6 - One improvement | | |
| Week 7 - Comparison | | 16 A04, 17 G03 |
| Week 8 - Consolidate | | 19 F01, 20 F02 (optional) |
| Week 9 - Analyse and draft | | 18 report |
| Week 10 - Handover | | 03 A06, 18 handover |

Every issue's report is indexed in [`reports/README.md`](../../reports/README.md).

<details>
<summary>Drafts that already have a real issue (check before running the script)</summary>

| Draft | Real issue | Note |
|---|---|---|
| `05-finding-b03-postcondition.md` | [#3](https://github.com/andersoxie/xpact/issues/3) | Title matches #3 exactly, so the script skips it |
| `08-finding-python310.md` | [#32](https://github.com/andersoxie/xpact/issues/32) | Fixed; delete the draft or the script makes a duplicate |
| `02-A02.md` | [#33](https://github.com/andersoxie/xpact/issues/33) | Done; delete the draft or the script makes a duplicate |
| `01-A01.md` | (none; A01 was marked done in [#18](https://github.com/andersoxie/xpact/issues/18)) | The script would create an A01 issue for finished work |
| `22-blocker-build-fixes.md` | (none) | Partly solved by #2, #7, #10 on `student-Mass`; still not in `main` |

Issues created outside the drafts: #2, #4, #7, #10, #13, #28, #38, #39, #40
(findings), #5, #14, #16, #18, #20, #22, #24, #26, #29, #34, #35, #37 (tasks).

</details>

## Project board

`CLAUDE.md` asks for a board with **Todo → In progress → In review → Done**.
Not created yet, because `gh` is logged in without the `project` scope. Once:

```powershell
gh auth refresh -s project                                   # opens the browser
.\student\github\setup-github.ps1 -CreateProject -DryRun     # check first
```

Then in the browser: **Settings → Status**, options `Todo`, `In progress`,
`In review`, `Done`; **Layout: Board**, grouped by Status; under
**Workflows**, "Item closed → Done" and "Pull request merged → Done".
An issue goes to `In review` when its pull request is open, and to `Done`
only after the result is verified (`CLAUDE.md`: never close an issue just
because the code changed).

## Running the setup script

Creating labels, milestones and issues needs **write access** to the
repository. Ask the supervisor first whether to use `andersoxie/xpact` or a
fork of your own.

```powershell
winget install GitHub.cli          # once (done on this PC 2026-10-21, see ../README.md "Tools on this PC")
gh auth login                      # once; choose GitHub.com and log in with the browser

cd C:\xpact\xpact-student-Mass
.\student\github\setup-github.ps1 -DryRun                    # shows what it would do
.\student\github\setup-github.ps1                            # labels, milestones, issues
.\student\github\setup-github.ps1 -Repo <you>/xpact          # use your fork instead
```

Running it again: labels are created with `--force`, so existing ones are set
to the colour and description in `labels.json` and the 6 missing ones **are
created** (ask first). A milestone that exists is skipped, and so is a draft
whose title **exactly** matches an existing issue.
