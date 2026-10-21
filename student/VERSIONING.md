# Versioning workflow

Every fix should be **traceable** (you can see which issue it belongs to and
why it was made), **tested** (the evidence is in the repository) and **easy to
revert** (one commit undoes it). This page describes how that is done on
`student-Mass`.

## The rules

1. **Work only in the git clone.** Never fix files in a copied folder such as
   `xpact3.0\...`: those changes have no commit hash and can't be traced or
   reverted.
2. **One issue per fix.** Every fix starts from a GitHub issue that describes
   the problem.
3. **One branch per fix:** `fix/<issue>-<short-name>`, e.g.
   `fix/2-include-fallback`, always created from the latest `student-Mass`.
4. **Every commit names its issue** with `Refs #<issue>` on the last line.
5. **Every fix has its own folder** `reports/issue-<NNNN>/` (issue number padded
   to four digits, e.g. `reports/issue-0002/`). It holds `report.md` with a
   `## Verification` section (the exact command, the result and the exit
   status) and the logs as `<what>.txt`. Add the fix to the index in
   [`reports/README.md`](../reports/README.md).
6. **Every fix goes through a pull request** into `student-Mass`, and is
   **squash-merged**. So each fix becomes exactly one commit on `student-Mass`,
   with the pull request number in its subject.
7. **Undo with `git revert`, never by rewriting history.** No force pushes and
   no `git reset` on `student-Mass`. A revert is a fix of its own, with its own
   branch, report and pull request.

`student\tools\fix.ps1` runs the steps and checks rules 3-7 for you.

## A fix, step by step

```powershell
cd C:\xpact\xpact-student-Mass

# 1. Branch from the latest student-Mass (also creates reports\issue-0002\)
.\student\tools\fix.ps1 start -Issue 2 -Name include-fallback

# 2. Change the code, then test it and save the log
.\scripts\build_native_eiffel.ps1 *> reports\issue-0002\build-log.txt

# 3. Write reports\issue-0002\report.md (cause, options, ## Verification)
#    and add a row to reports\README.md

# 4. Commit (the template asks for "Refs #2")
git add scripts\build_native_eiffel.ps1 reports\
git commit

# 5. Check, push and open the pull request
.\student\tools\fix.ps1 finish

# 6. When the checks on the pull request pass, squash-merge it
.\student\tools\fix.ps1 merge
```

`finish` refuses to push if a commit doesn't mention the issue, if the report
is missing, or if the report has no `## Verification` section. `merge` prints
the commit to use if the fix ever has to be reverted.

## `fix.ps1` in Windows PowerShell 5.1

In Windows PowerShell 5.1 the script stops as soon as git writes to stderr,
which git also does for normal messages ("Already on 'student-Mass'", push
progress). Until the script is fixed, run the same steps by hand. This is how
#29 was done:

```powershell
# start
git fetch --prune origin
git switch student-Mass
git merge --ff-only origin/student-Mass
git switch -c fix/29-w3c-assertions
mkdir reports\issue-0029

# ... change, test, write reports\issue-0029\report.md, commit with "Refs #29" ...

# finish: check yourself that every commit says "Refs #29" and that the
# report has a "## Verification" section, then
git push -u origin fix/29-w3c-assertions
gh pr create --repo andersoxie/xpact --base student-Mass --head fix/29-w3c-assertions --title "<subject>" --body-file <file>
#   body: "Refs #29", the commit list, a link to the report, the revert command

# merge, after the checks pass
gh pr merge <pr> --repo andersoxie/xpact --squash --subject "<subject> (#<pr>)" --body "Refs #29"
git switch student-Mass
git pull --ff-only
git push origin --delete fix/29-w3c-assertions
git branch -D fix/29-w3c-assertions
```

## Reverting a fix

```powershell
.\student\tools\fix.ps1 revert -Issue 2 -Commit 9eb18bd
# test again, add to reports\issue-0002\report.md why it was reverted, commit
.\student\tools\fix.ps1 finish
.\student\tools\fix.ps1 merge
```

The original commit stays in the history, so the reason for both the fix and
the revert remains visible.

## Finding things later

| Question | Command |
|---|---|
| Every fix merged into `student-Mass`, newest first | `git log --first-parent --oneline student-Mass` |
| Every commit for issue 2 | `git log --oneline --grep "#2\b" -E` |
| What a fix changed | `git show <sha>` |
| Which fix last changed a line | `git blame -L 40,45 scripts\build_native_eiffel.ps1` |
| What changed between two review points | `git diff student-week-03..student-week-04 --stat` |
| Open fix pull requests | `gh pr list --repo andersoxie/xpact --base student-Mass` |

## Review points (tags)

At each milestone, tag the tested state of `student-Mass`, so you can always go
back to a known-good point:

```powershell
git switch student-Mass
git pull --ff-only
git tag -a student-week-03 -m "Week 3 review: <what was tested>"
git push origin student-week-03
```

Tags are only added at review points, not for every fix. The pull request
numbers already identify each fix.

## Setup (once per clone)

```powershell
cd C:\xpact\xpact-student-Mass
git config commit.template "$PWD\student\git\commit-template.txt"
git config pull.ff only           # never create accidental merge commits on pull
git config fetch.prune true       # forget remote branches deleted after merging
git config push.autoSetupRemote true
gh auth status                    # GitHub CLI must be logged in
```

`gh` was installed with `winget install GitHub.cli`; see
[README.md](README.md#tools-on-this-pc-2026-10-21) for where it and Python are
on this PC.

## Already on `student-Mass` before this workflow

These commits were made directly on `student-Mass`. They follow rules 4-5 where
noted and can each be reverted with `fix.ps1 revert`:

| Commit | What | Issue |
|---|---|---|
| `b7181f0`, `5240cfc` | Error report for 2026-10-19 | #2, #3, #4 |
| `9eb18bd` | Fix the Eiffel include fallback path, with fix report | #2 |
| `aa8e0aa`, `1e699a0` | An upload and its revert (no net change) | - |

## Committed without a pull request (2026-10-21)

These four commits were pushed straight to `student-Mass`, against rule 5
(found and recorded in [#34](https://github.com/andersoxie/xpact/issues/34)).
Each one has `Refs #N`, a report with verification and its logs, so it can be
traced and reverted like the others, but nobody reviewed it before it landed.
The history is not rewritten: that would need a force push on a shared branch.

| Commit | What | Issue | Report |
|---|---|---|---|
| `1ea242e` | Regression test for the CR loop variant (pull request #31 was closed instead of merged) | #28 | [issue-0028](../reports/issue-0028/report.md) |
| `492c6eb` | W3C harness tests pass on Python 3.10 | #32 | [issue-0032](../reports/issue-0032/report.md) |
| `1799b35` | `run_baseline.ps1 -LogDir` | #33 | [A02-baseline](results/A02-baseline/README.md) |
| `42d6b40` | A02 baseline rerun and setup guide | #33 | [A02-baseline](results/A02-baseline/README.md) |

**Rule from now on:** even when `fix.ps1` cannot run, every change goes
through a `fix/<issue>-<name>` branch and a pull request (the manual steps
above). `git push origin student-Mass` is never used for new work.
