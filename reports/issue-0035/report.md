# Report: issue #35, GitHub labels and week milestones from CLAUDE.md

Issue: [#35](https://github.com/andersoxie/xpact/issues/35)   Branch: `fix/35-labels-milestones`   Base: `fix/37-dll-test-program`   Date: 2026-10-22

> **In short:** ✅ 4 labels and 10 milestones were created on GitHub (with the
> student's agreement, 2026-10-22), and every issue got a milestone.
> ✅ `labels.json`, `milestones.json` and `student/github/README.md` now
> describe what is on GitHub. ⬜ The project board is not created yet.

## Why

[`CLAUDE.md`](../../CLAUDE.md) asks for the labels `bug`, `test`, `build`,
`documentation`, `regression`, `investigation`, for milestones per project
week and for a board Todo → In progress → In review → Done. Before this,
GitHub had no milestones, and `test`, `build`, `regression`, `investigation`
did not exist.

## Done on GitHub (not a file change)

| | Command | Result |
|---|---|---|
| ✅ | `gh label create test\|build\|regression\|investigation --repo andersoxie/xpact --color … --description …` | 4 labels; `bug` and `documentation` already existed |
| ✅ | `gh api repos/andersoxie/xpact/milestones -f title=… -f due_on=…` × 10 | Milestones 1-10, `Week 1 - Setup` … `Week 10 - Handover`, due each Friday from 2026-10-09 |
| ✅ | `gh issue edit <n> --milestone … --add-label …` for #2-#33 | Every issue has a milestone; build fixes `build,bug`, parser findings `bug,investigation`, workflow tasks `documentation`, #28 `bug,regression,test`, #29/#32/#33 `test` |
| ⬜ | `gh project list --owner CodTanium` | `missing required scopes [read:project]`: the board needs `gh auth refresh -s project` in the browser first |

One command failed and was repeated: `gh issue edit 13 --milestone "Week2 - Baseline"`
(a typo, no space); rerun with `"Week 2 - Baseline"`, ✅.

## What changed

| File | Change |
|---|---|
| `student/github/labels.json` | + `bug`, `test`, `build`, `documentation`, `regression`, `investigation` (21 labels) |
| `student/github/milestones.json` | 10 milestones, weeks 1-10, same titles, dates and descriptions as on GitHub (was 6) |
| `student/github/README.md` | Rewritten: state table first, the two kinds of labels, milestones with their issues and drafts, the board, how the script treats existing labels |

## Expected results (written before checking)

| # | Check | Expected |
|---|---|---|
| 1 | Both JSON files load (`python -c "import json; json.load(…)"`) | 21 labels, 10 milestones |
| 2 | `gh label list` | contains `test`, `build`, `regression`, `investigation` |
| 3 | `gh api repos/andersoxie/xpact/milestones --jq '.[].title'` | the 10 titles in `milestones.json`, same order |
| 4 | `gh issue list --state all --json number,milestone` | no issue without a milestone |

## Verification

| # | Actual | |
|---|---|---|
| 1 | `21 10` | ✅ |
| 2 | `build`, `test`, `regression`, `investigation` listed | ✅ |
| 3 | `Week 1 - Setup` … `Week 10 - Handover`, 10 titles in the same order | ✅ |
| 4 | `[]`: no issue without a milestone (#2-#41) | ✅ |

## How to revert

`git revert <merged sha>` restores the files. The labels and milestones on
GitHub stay; remove them with `gh label delete` and
`gh api -X DELETE repos/andersoxie/xpact/milestones/<n>` if needed.

## Update 2026-10-22: project board ✅

After the student ran `gh auth refresh -s project`:

| | Command | Result |
|---|---|---|
| ✅ | `gh project create --owner CodTanium --title "xpact student work (Mass)"` | [project 3](https://github.com/users/CodTanium/projects/3) |
| ✅ | GraphQL `updateProjectV2Field` on the Status field | options `Todo`, `In progress`, `In review`, `Done` |
| ❌ | `gh project link 3 --owner CodTanium --repo andersoxie/xpact`, then GraphQL `linkProjectV2ToRepository` | "Only projects owned by the same owner as the repository can be linked." **Confirmed** GitHub rule; the board still holds the repository's issues |
| ✅ | `gh issue create` from drafts 09 and 10 | #45 (B01), #46 (B02), same titles as the drafts |
| ✅ | `gh project item-add` + `item-edit` for #2-#46 and PR #12 | `gh project item-list 3 --owner CodTanium`: Done 19, In review 2 (#3, PR #12), Todo 7 |

Still to do by hand in the browser: switch the view to **Board** layout and
check the built-in workflows (item closed / pull request merged → `Done`).
