# Report: issue #108, the 6 missing labels (#35) and the project board

Issue: [#108](https://github.com/andersoxie/xpact/issues/108)   Branch: `fix/108-labels-and-board`   Base: `student-Mass` @ `a39362a`   Date: 2026-10-26

## In short

| | Item | Result |
|---|---|---|
| ✅ | #35: 6 labels from `labels.json` missing on GitHub | created; **all 21 match** colour and description |
| ✅ | Project board could not be read | read; **16 issues added, 9 statuses corrected**; every student issue on it, every closed one in Done |
| ⏳ | Week 2: decision with the supervisor | left open on purpose (the student asked to wait) |

Both changes were authorized by the student on 2026-10-26 (the student ran
`gh auth refresh -s read:project,project` and asked for the labels). They are
changes on GitHub; the repository only records them.

## 1. Labels (#35)

Created on `andersoxie/xpact` with `gh label create`, colour and description
copied from [`student/github/labels.json`](../../student/github/labels.json):

| Label | Colour | Description |
|---|---|---|
| `group:A-orientation` | `1d76db` | A - Orientation and assertion policy |
| `group:F-core` | `5319e7` | F - Xpact core investigation and adapters |
| `group:G-verification` | `fbca04` | G - Shared verification and measurement |
| `D1-beginner` | `c2e0c6` | Read, run prepared examples, document and report |
| `D4-expert` | `e99695` | Experienced developer owns the implementation |
| `type:blocker` | `000000` | Stops other work until resolved |

GitHub's 7 default labels (`duplicate`, `enhancement`, `good first issue`,
`help wanted`, `invalid`, `question`, `wontfix`) stay: no issue or pull request
uses them (checked with `gh issue list` / `gh pr list --label`), and removing
them was not asked for. They are named in `student/github/README.md`.

## 2. Project board

[xpact student work (Mass)](https://github.com/users/CodTanium/projects/3), compared with `gh issue list --state all`:

| Before (29 items) | Action | After (45 items + #108) |
|---|---|---|
| 16 student issues not on the board: #48, #51, #53, #55, #56, #60, #64, #66, #68, #70, #73, #74, #79, #102, #104, #106 | added (`gh project item-add`) | closed ones → Done; #73, #74, #79 → In review (waiting for Jenkins / PR #76) |
| Closed but not Done: #3 (In review), #28, #38, #39, #40, #45, #46 (Todo) | `gh project item-edit` | Done |
| Merged PRs #12, #47 in In review | `gh project item-edit` | Done |
| #13 open, Todo | none | Todo (on hold) |

The supervisor's issues #88, #90, #93 are not added: this board is for the student work.

## Expected results (written before the checks)

| # | Check | Expected |
|---|---|---|
| 1 | every label of `labels.json` on GitHub, same colour and description | 21 / 21, 0 differences |
| 2 | every issue by `CodTanium` on the board | none missing |
| 3 | closed issue on the board but not in Done | none |

## Verification

| # | Command | Actual | |
|---|---|---|---|
| 1 | `gh label list -R andersoxie/xpact --limit 100 --json name,color,description`, compared with `labels.json` | 21 in `labels.json`, 28 on GitHub, **0 problems**; 7 GitHub defaults extra | ✅ |
| 2 | `gh project item-list 3 --owner CodTanium` (read again after the changes) vs `gh issue list --state all` | 45 items: 41 Done, 3 In review, 1 Todo; **student issues not on the board: none** | ✅ |
| 3 | same | **closed but not Done: none**; open: #13 Todo, #73 / #74 / #79 In review | ✅ |
| 4 | `gh auth status` | scopes `gist`, `project`, `read:org`, `repo`, `workflow` | ✅ |
| 5 | link check over `student/`, `reports/`, `docs/` | 0 broken | ✅ |

## How to revert

The repository part: `.\student\tools\fix.ps1 revert -Issue 108 -Commit <merged sha>`.
On GitHub: `gh label delete <name> -R andersoxie/xpact` for each of the 6 labels;
board statuses can be set back with `gh project item-edit`.
