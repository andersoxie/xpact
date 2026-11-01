# GitHub setup

> **Last updated:** 2026-10-26 · describes `student-Mass` @ `a39362a` (labels and board checked on GitHub, [#108](https://github.com/andersoxie/xpact/issues/108))

How the work is tracked on [andersoxie/xpact](https://github.com/andersoxie/xpact):
**one issue per problem or task**, labels to sort them, one milestone per
project week, and a pull request into `student-Mass` for every change
(never into `main`; see [`CLAUDE.md`](../../CLAUDE.md)).

| | What | State (2026-10-22) |
|---|---|---|
| ✅ | Labels | 21, listed in [`labels.json`](labels.json); **all 21 on GitHub** with the same colour and description (the last 6 created 2026-10-26, [#108](https://github.com/andersoxie/xpact/issues/108)) |
| ✅ | Milestones | `Week 1 - Setup` … `Week 10 - Handover`, in [`milestones.json`](milestones.json), all on GitHub |
| ✅ | Issues | #2-#70 on GitHub, each with a milestone and labels; drafts for the rest in [`issues/`](issues/) |
| ✅ | Project board | [xpact student work (Mass)](https://github.com/users/CodTanium/projects/3): Todo → In progress → In review → Done, every issue on it ([below](#project-board)) |

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

**Where it belongs in the task register** (created 2026-10-20 in [#24](https://github.com/andersoxie/xpact/issues/24), first without asking the supervisor; noted to the supervisor):

| Labels | Meaning |
|---|---|
| `type:finding` / `type:task` / `type:blocker` | Something observed that is wrong / planned work / stops other work |
| `group:A` … `group:G` | Task group of the register (A orientation, B reliable results, C correctness, F core, G verification) |
| `D1-beginner` … `D4-expert` | How much help it needs |
| `P0` / `P1` | Must be solved first / after P0 |
| `workflow` | Versioning, reports and plan updates (not a project finding) |

All 21 are on GitHub. `group:A-orientation`, `group:F-core`,
`group:G-verification`, `D1-beginner`, `D4-expert` and `type:blocker` were
created on 2026-10-26 ([#108](https://github.com/andersoxie/xpact/issues/108), authorized by the student). GitHub's
7 default labels (`duplicate`, `enhancement`, `good first issue`, `help wanted`,
`invalid`, `question`, `wontfix`) are also there; no issue or pull request uses
them, and they are not in `labels.json`. The issue templates add `type:finding`
or `type:task` by themselves; add the others by hand.

## Milestones and issues

Due on the Friday of each week; week 1 started on 2026-10-05.

| Milestone | Issues on GitHub | Drafts not on GitHub yet |
|---|---|---|
| Week 1 - Setup | #2, #4, #7, #10 (build fixes), #18 (A01), #68 (A01 evidence) | |
| Week 2 - Baseline | #3 (B03), #13, #33 (A02), #48 (`-keep`) | 04 `-keep`, 06 runner stops, 07 DLL crash, 21 xmlconf crashes, 22 build fixes not in `main` |
| Week 3 - Failure reporting | #5, #14, #16, #20, #22, #24, #26, #34, #35 (workflow) · #28 (CR loop variant), #29 (W3C run), #32 (Python 3.10) · #45 B01, #46 B02 · #51, #53, #55, #60 (findings) · #56, #64, #66, #70 (workflow) | 23 Jenkins precompile (dropped, #56) |
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
| `09-B01.md`, `10-B02.md` | [#45](https://github.com/andersoxie/xpact/issues/45), [#46](https://github.com/andersoxie/xpact/issues/46) | Same titles, so the script skips them |
| `01-A01.md` | (none; A01 was marked done in [#18](https://github.com/andersoxie/xpact/issues/18), evidence in [#68](https://github.com/andersoxie/xpact/issues/68)) | The script would create an A01 issue for finished work |
| `22-blocker-build-fixes.md` | (none) | Partly solved by #2, #7, #10 on `student-Mass`; still not in `main` |

Issues created outside the drafts: #2, #4, #7, #10, #13, #28, #38, #39, #40,
#48, #51, #53, #55, #60 (findings), #5, #14, #16, #18, #20, #22, #24, #26, #29,
#34, #35, #37, #43, #56, #64, #66, #68, #70 (tasks).

</details>

## Project board

✅ **[xpact student work (Mass)](https://github.com/users/CodTanium/projects/3)**,
created 2026-10-22 ([#35](https://github.com/andersoxie/xpact/issues/35)), with
the columns `CLAUDE.md` asks for:

| Status | Means | On the board, checked 2026-10-26 ([#108](https://github.com/andersoxie/xpact/issues/108)) |
|---|---|---|
| ⬜ Todo | Not started | #13 (⏸ on hold) |
| 🟡 In progress | Being worked on | |
| 🔵 In review | Pull request open, or waiting for the parser developer or Jenkins | #73, #74 (PR #76), #79: waiting for a Jenkins rerun |
| ✅ Done | Merged **and** the result verified | every closed student issue, plus the merged PRs #12 and #47 (41 items) |

An issue goes to `Done` only after its result is checked (`CLAUDE.md`: never
close an issue just because the code changed).

- The board belongs to the account `CodTanium`. It **cannot be linked** to
  `andersoxie/xpact` (GitHub only links a project to a repository of the same
  owner), so it does not show in the repository's Projects tab. Issues of
  the repository can be added to it all the same.
- The `gh` login has the `project` scope since 2026-10-26 (`gh auth refresh -s read:project,project`).
  That day the board was read and brought up to date ([#108](https://github.com/andersoxie/xpact/issues/108)): 16 student
  issues were missing (#48-#106), 7 closed issues were still in Todo or In review,
  and the merged PRs #12 and #47 were still in In review. The supervisor's own
  issues (#88, #90, #93) are not on this student board.
- A new issue does not land on the board by itself. Add it with
  `gh project item-add 3 --owner CodTanium --url <issue url>`, or from the
  issue page (**Projects** → *xpact student work (Mass)*).
- Set up once in the browser (the API cannot do it): **Layout → Board** for
  the view, and under **⋯ → Workflows** check that "Item closed" and "Pull
  request merged" set the status to `Done`.

How it was made: `gh project create --owner CodTanium`, the Status field
options set with the GraphQL mutation `updateProjectV2Field`, then
`gh project item-add` and `gh project item-edit` for every issue.
`setup-github.ps1 -CreateProject` was not used: it tries to link the board
to the repository, which fails for the reason above.

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
to the colour and description in `labels.json` (all 21 exist since 2026-10-26). A milestone that exists is skipped, and so is a draft
whose title **exactly** matches an existing issue.
