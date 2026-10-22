# B02: deliberately failing meta-tests

Issue [#46](https://github.com/andersoxie/xpact/issues/46), 2026-10-22. Report:
[reports/issue-0046/report.md](../../../reports/issue-0046/report.md).

Set `XPACT_META_FAIL` to make the test runners fail on purpose; unset, nothing changes.

| Value | `xpact_tests.exe` | native runtime smoke |
|---|---|---|
| `assert` or `1` | a failed `assert` in `test_meta_deliberate_failure` | a failed `assert` |
| `exception` | `test_meta_deliberate_failure` raises an exception | a failed `assert` |
| unset | nothing | nothing |

| Files | What |
|---|---|
| `assert-*.txt` | `XPACT_META_FAIL=assert`: all 4 matrix lanes and both native smoke builds exit 1 |
| `exception-*.txt` | `XPACT_META_FAIL=exception`: all 4 matrix lanes exit 1 |
| `unset-*.txt` | unset: assertions-off and native `ok`; assertions-on exits 1 on B03 (#3) |
| `run-lane.ps1`, `run-set.ps1` | How the lanes were run |
