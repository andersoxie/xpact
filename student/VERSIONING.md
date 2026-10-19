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
5. **Every fix has a report** at `reports/fix-report-issue-<issue>.md` with a
   `## Verification` section: the exact command, the result and the exit status.
   Logs go next to it as `reports/fix-issue-<issue>-<what>.txt`.
6. **Every fix goes through a pull request** into `student-Mass`, and is
   **squash-merged**. So each fix becomes exactly one commit on `student-Mass`,
   with the pull request number in its subject.
7. **Undo with `git revert`, never by rewriting history.** No force pushes and
   no `git reset` on `student-Mass`. A revert is a fix of its own, with its own
   branch, report and pull request.

`student\tools\fix.ps1` runs the steps and checks rules 3-7 for you.

## A fix, step by step

```powershell
cd C:\Users\masou\Desktop\Lia\xpact\xpactGit

# 1. Branch from the latest student-Mass
.\student\tools\fix.ps1 start -Issue 2 -Name include-fallback

# 2. Change the code, then test it and save the log
.\scripts\build_native_eiffel.ps1 *> reports\fix-issue-2-build-log.txt

# 3. Write reports\fix-report-issue-2.md (cause, options, ## Verification)

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

## Reverting a fix

```powershell
.\student\tools\fix.ps1 revert -Issue 2 -Commit 9eb18bd
# test again, add to reports\fix-report-issue-2.md why it was reverted, commit
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
cd C:\Users\masou\Desktop\Lia\xpact\xpactGit
git config commit.template "$PWD\student\git\commit-template.txt"
git config pull.ff only           # never create accidental merge commits on pull
git config fetch.prune true       # forget remote branches deleted after merging
git config push.autoSetupRemote true
gh auth status                    # GitHub CLI must be logged in
```

## Already on `student-Mass` before this workflow

These commits were made directly on `student-Mass`. They follow rules 4-5 where
noted and can each be reverted with `fix.ps1 revert`:

| Commit | What | Issue |
|---|---|---|
| `b7181f0`, `5240cfc` | Error report for 2026-10-19 | #2, #3, #4 |
| `9eb18bd` | Fix the Eiffel include fallback path, with fix report | #2 |
| `aa8e0aa`, `1e699a0` | An upload and its revert (no net change) | - |
