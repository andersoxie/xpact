# Report: issue #34, repair the repository state of 2026-10-21

Issue: [#34](https://github.com/andersoxie/xpact/issues/34)   Branch: `fix/34-repo-repair`   Base: `student-Mass` @ `42d6b40`   Date: 2026-10-22

> **In short:** a check of the clone against [`CLAUDE.md`](../../CLAUDE.md)
> found five problems in how the work of 2026-10-21 was recorded. ✅ All five
> are repaired or recorded. Nothing in `src/`, `tests/`, `scripts/` or any
> test result changes.

## Environment

`C:\xpact\xpact-student-Mass`, Windows 11, Windows PowerShell 5.1 and Git Bash,
git, GitHub CLI 2.102.1 (logged in as `CodTanium`).

## The problems

### 1. ✅ Week 2 baseline log overwritten (working copy only)

| | |
|---|---|
| Problem | `student/baseline/logs/matrix-finalized-keep.log`, evidence for K1/K2 of the week 2 baseline, was overwritten in the working copy |
| Command | `git diff --stat` |
| Expected | The week 2 logs never change |
| Actual | `Bin 40731 -> 3686 bytes`; the new content is a UTF-16 PowerShell error record (`xpact_tests.exe : At line:1 char:1 … RemoteException`) |
| Investigation | The committed file (`git show HEAD:…`) is intact. `student/results/A02-baseline/matrix-finalized-keep.log` is a different file |
| Cause | **Confirmed:** `run_baseline.ps1` wrote its logs into `student/baseline/logs/` during the A02 rerun, before `-LogDir` was added in `1799b35` |
| Fix | `git restore student/baseline/logs/matrix-finalized-keep.log`. The overwritten copy was kept outside the repository during the repair |
| Verification | ✅ `git status` no longer lists the file; its first line is again `# ec -batch -clean -finalize -keep …`, `# started 2026-10-14T16:22:40` |

### 2. ✅ Four commits pushed without a pull request

| | |
|---|---|
| Problem | `1ea242e` (#28), `492c6eb` (#32), `1799b35` and `42d6b40` (#33) went straight to `origin/student-Mass` |
| Command | `git log --oneline --graph --all`, `gh pr list --repo andersoxie/xpact --state all` |
| Expected | Every change goes through a `fix/<issue>-<name>` branch and a squash-merged pull request ([VERSIONING.md](../../student/VERSIONING.md), rule 5) |
| Actual | No pull request for any of the four; #31 (for #28) was closed with "Committed directly on student-Mass as 1ea242e" |
| Investigation | Each commit has `Refs #N`; #28 and #32 have reports with verification; #33 has `student/results/A02-baseline/README.md` |
| Cause | **Confirmed:** pushed by hand with `git push`. Why the workflow was skipped is **unknown** |
| Fix | Not rewritten (a force push on a shared branch would be worse). Listed in [VERSIONING.md, "Committed without a pull request"](../../student/VERSIONING.md#committed-without-a-pull-request-2026-10-21), with the rule that `git push origin student-Mass` is never used for new work |
| Verification | ✅ The four SHAs are in VERSIONING.md and `reports/README.md` |

### 3. ✅ Pull request #31 closed, its branch left behind

| | |
|---|---|
| Problem | `fix/28-cr-regression-test` stayed on GitHub and locally after #31 was closed |
| Command | `git for-each-ref refs/heads refs/remotes` |
| Investigation | `git diff 1ea242e 0d27d9f --stat -- tests reports/issue-0028` is empty: the branch has nothing that is not on `student-Mass` |
| Cause | **Confirmed:** follows from 2 |
| Fix | `git branch -D fix/28-cr-regression-test`, `git push origin --delete fix/28-cr-regression-test` |
| Verification | ✅ `git ls-remote origin fix/28-cr-regression-test` prints nothing |

### 4. ✅ Doc updates of 2026-10-21 never committed

| | |
|---|---|
| Problem | Changes to nine student docs were only in the working copy: the new clone path `C:\xpact\xpact-student-Mass`, "Tools on this PC", the manual steps for `fix.ps1` in PowerShell 5.1, the supervisor page, the week 3 note, `history/README.md` and the A01 and draft 12 checklists |
| Command | `git status --short`, `git diff --stat` |
| Cause | **Suspected:** taken out of #31 by `0d27d9f` ("Take the unrelated student docs out of this pull request") and not committed anywhere else |
| Fix | Reviewed (`git diff`) and committed here as they are. They describe the state at `8850dab`; bringing them up to date is a separate step |
| Verification | ✅ After this pull request, `git status` lists none of them |

### 5. ✅ Reports index incomplete

| | |
|---|---|
| Problem | `reports/README.md` had "see git log --grep" for #28 and #32, and no row for #33 |
| Fix | SHAs filled in, rows for #33 and #34 added |
| Verification | ✅ Every row except #34 itself has a commit |

### Also in this change

- `CLAUDE.md`, the rules for documentation, issues and pull requests, is added to git.
- `xmlconf/` (the W3C suite, unpacked by hand, 6.4 MB) is downloaded data: it is
  **not** committed (CLAUDE.md), only excluded in this clone's `.git/info/exclude`.

## What changed

| File | Change |
|---|---|
| `CLAUDE.md` | New in git |
| `student/VERSIONING.md` | Section "Committed without a pull request (2026-10-21)", plus the uncommitted changes of problem 4 |
| `reports/README.md` | SHAs for #28 and #32, rows #33 and #34 |
| `reports/issue-0034/report.md` | This report |
| `student/README.md`, `student/PLAN.md`, `student/for superviser.txt`, `student/github/README.md`, `student/github/issues/01-A01.md`, `student/github/issues/12-xmlconf-verdicts.md`, `student/history/README.md`, `student/notes/weekly/week-03.md` | The uncommitted changes of problem 4, unchanged |

## How to revert

```powershell
git revert <merged sha>
```

This brings back the uncommitted-docs state in git, not the overwritten log
(that was never committed) and not the deleted branch (its content is `1ea242e`).
