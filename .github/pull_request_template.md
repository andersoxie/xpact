Refs #
<!-- Student issue-fix workflow: pull requests go into incremental-test;
     never target main. Since incremental-test is not the default branch,
     "Closes #" does not close the issue. Merge with a merge commit,
     never squash. Close the issue by hand after checking the merged commit.
     student/tools/fix.ps1 finish writes this description for you. -->
<!-- For other authorized work, record the agreed target branch and evidence.
     The student-specific checklist below is scoped to that workflow.
     Preserve CLAUDE.md's no-main policy; this template does not authorize a merge. -->

## What changed

## Evidence
- Fix report: `reports/issue-NNNN/report.md` (expected results written before testing, `## Verification`)
- Revision tested: <!-- git rev-parse HEAD -->
- Configuration: <!-- workbench / finalized -keep, assertions, ISE_C_COMPILER -->

| Command | Before (exit) | After (exit) |
|---|---|---|
|  |  |  |

## Student workflow checklist
- [ ] Report, logs and inputs are in `reports/issue-NNNN/`, and `reports/README.md` has a row for it
- [ ] Every commit ends with `Refs #<issue>`
- [ ] Only test, script or documentation changes, or a parser change reviewed with its developer
- [ ] The affected existing checks were run again
