# GitHub setup

The plan from `docs/xpact-student-introduction.md` as GitHub labels, milestones,
issues and a project board.

| File | Content |
|---|---|
| `labels.json` | 15 labels: group (A, B, C, F, G), difficulty (D1–D4), priority (P0, P1), type (task, finding, blocker), and `workflow` |
| `milestones.json` | One milestone per review point, weeks 2, 3, 4, 5, 7 and 10. Due dates assume that week 1 started on 2026-10-05. Change them if that is wrong. |
| `issues/*.md` | 23 issue drafts: the guide's suggested selection, the week 2 findings, and 3 from the weeks 1–2 history (21–23). Edit or delete drafts before running the script. |
| `setup-github.ps1` | Creates all of the above on GitHub. Safe to run again: it skips a draft whose title **exactly** matches an existing issue. |

## Drafts and real issues (2026-10-20)

Issues on GitHub so far were created one by one, not with the script. Before
running it, check that no draft duplicates a real issue:

| Draft | Real issue | Note |
|---|---|---|
| `05-finding-b03-postcondition.md` | [#3](https://github.com/andersoxie/xpact/issues/3) | Title changed to match #3 exactly, so the script skips it |
| `22-blocker-build-fixes.md` | (none) | Partly solved by #2, #7, #10 on `student-Mass`; still not in `main` |
| `01-A01.md` | (none; A01 was marked done in [#18](https://github.com/andersoxie/xpact/issues/18)) | The script would create an A01 issue for finished work: delete the draft or close the issue afterwards |

Issues created outside the drafts: #2, #4, #7, #10, #13, #28 (findings), #5, #14,
#16, #18, #20, #29 (tasks). Their reports are indexed in
[`reports/README.md`](../../reports/README.md).

## Labels on GitHub (2026-10-20)

Nine of the labels in `labels.json` were created on GitHub by hand with
`gh label create` (not with the script), with the colours and descriptions
from `labels.json`. They were created **without asking the supervisor first**,
although the section "Running it" below says to ask; this is noted in
[`for superviser.txt`](../for%20superviser.txt).

| Labels | Applied to |
|---|---|
| `type:finding` `group:B-reliable-results` `D2-guided` `P0` | #2, #4, #7, #10: build fixes; without them no result could be reproduced |
| `type:finding` `group:C-correctness` `D3-advanced` `P0` | #3 (B03) and pull request #12; a parser change reviewed by its developer. #28 (loop variant in `normalized_input`) |
| `type:finding` `group:C-correctness` `D3-advanced` `P1` | #13 |
| `type:task` `workflow` | #5, #14, #16, #18, #20, #22, #24: versioning, reports, plan and summary updates |
| `type:task` `D2-guided` `P1` | #29: W3C run with assertions off and on (no `group:G` label on GitHub yet) |

`workflow` is new: housekeeping tasks are not findings and belong to no group
of the task register. The other six labels in `labels.json` (`group:A`,
`group:F`, `group:G`, `D1`, `D4`, `type:blocker`) are not on GitHub yet. The
issue templates add `type:finding` or `type:task` automatically; add the group,
difficulty and priority labels by hand.

## Milestones and issues

| Milestone | Issues |
|---|---|
| Week 2 - Baseline | A01, A02 · findings: finalized lane without `-keep`, B03 postcondition, runner stops at the first failure, DLL crash code, Python 3.10 harness, 53 xmlconf crashes · blocker: build fixes not in `main` |
| Week 3 - Failure reporting | B01, B02 · finding: Jenkins precompile prompt |
| Week 4 - Input matrix | G01, xmlconf verdict rules |
| Week 5 - Regressions | C02, C03, C10 (part) |
| Week 7 - Comparison | A04, G03 |
| Week 10 - Handover | A06 (open all ten weeks), report and handover, F01 and F02 (optional) |

## Running it

Creating labels, milestones and issues needs **write access** to the repository.
Ask the supervisor first whether to use `andersoxie/xpact` or a fork of your own.

```powershell
winget install GitHub.cli          # once (on this PC winget is missing: gh is in %LOCALAPPDATA%\Programs\GitHubCLI\bin)
gh auth login                      # once; choose GitHub.com and log in with the browser
gh auth refresh -s project         # only for -CreateProject

cd C:\Users\masou\Desktop\Lia\xpact\xpactGit
.\student\github\setup-github.ps1 -DryRun                    # shows what it would do
.\student\github\setup-github.ps1                            # labels, milestones, issues
.\student\github\setup-github.ps1 -CreateProject             # ... plus the project board
.\student\github\setup-github.ps1 -Repo <you>/xpact          # use your fork instead
```

## Project board columns

The script creates the board and adds the issues. You set up the columns once, in the browser:

1. Open the project, go to **Settings** and then **Status**, and set the options
   to `Backlog`, `This week`, `In progress`, `In review` and `Done`.
2. In the view menu, choose **Layout: Board**, grouped by Status.
3. Under **Workflows**, turn on "Item closed -> Done" and "Pull request merged -> Done".
4. Move all issues to `Backlog`, then each week drag that week's issues to `This week`.
