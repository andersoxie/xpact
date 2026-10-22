# B01: failing tests return a nonzero exit status

Issue [#45](https://github.com/andersoxie/xpact/issues/45), 2026-10-22. The report with the
cause, the change and the verification table is
[reports/issue-0045/report.md](../../../reports/issue-0045/report.md).

| Files | What |
|---|---|
| `before-*.txt` | Before the fix, with a deliberate failure: assertions-off runs exit 0 |
| `after-deliberate-*.txt` | After the fix, with the deliberate failure: every lane exits 1 |
| `after-clean-*.txt` | After the fix, no deliberate failure: only the assertions-on matrix lane fails (B03, #3) |
| `deliberate-failure.diff` | The temporary failing `assert`, applied for the first two groups, not committed |
| `run-lane.ps1`, `run-set.ps1` | How the lanes were run |
