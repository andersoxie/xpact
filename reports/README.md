# Reports

Every fix on `student-Mass` has one folder here, named after its GitHub issue
and padded to four digits so the folders sort by number. Each folder holds
`report.md` (cause, change, `## Verification`, how to revert) and the logs and
test scripts that back it up. The rules are in
[`student/VERSIONING.md`](../student/VERSIONING.md).

## Fixes

| Issue | Fix | Pull request | Commit on `student-Mass` | Report |
|---|---|---|---|---|
| [#2](https://github.com/andersoxie/xpact/issues/2) | Eiffel runtime include fallback path in `build_native_eiffel.ps1` | - (committed before the workflow) | `9eb18bd` | [issue-0002](issue-0002/report.md) |
| [#4](https://github.com/andersoxie/xpact/issues/4) | Stop repeated MSVC imports from growing PATH past cmd's limit | [#9](https://github.com/andersoxie/xpact/pull/9) | `3b8a205` | [issue-0004](issue-0004/report.md) |
| [#5](https://github.com/andersoxie/xpact/issues/5) | Versioning workflow for fixes | [#6](https://github.com/andersoxie/xpact/pull/6) | `cada501` | [issue-0005](issue-0005/report.md) |
| [#7](https://github.com/andersoxie/xpact/issues/7) | Build the native Eiffel library with the `msc_vc140` C backend | [#8](https://github.com/andersoxie/xpact/pull/8) | `eb6fc5d` | [issue-0007](issue-0007/report.md) |
| [#10](https://github.com/andersoxie/xpact/issues/10) | Build the native runtime smoke test with the `msc_vc140` C backend | [#11](https://github.com/andersoxie/xpact/pull/11) | `20e6bc3` | [issue-0010](issue-0010/report.md) |
| [#14](https://github.com/andersoxie/xpact/issues/14) | One folder per fix under `reports/` | [#15](https://github.com/andersoxie/xpact/pull/15) | `4a957b1` | [issue-0014](issue-0014/report.md) |
| [#16](https://github.com/andersoxie/xpact/issues/16) | Update `student/PLAN.md` with the week 3 work | [#17](https://github.com/andersoxie/xpact/pull/17) | `b631e15` | [issue-0016](issue-0016/report.md) |
| [#18](https://github.com/andersoxie/xpact/issues/18) | Mark A01 as done in `student/PLAN.md` | [#19](https://github.com/andersoxie/xpact/pull/19) | `df189d9` | [issue-0018](issue-0018/report.md) |
| [#20](https://github.com/andersoxie/xpact/issues/20) | Bring the student docs in line with the week 3 workflow; week 3 note | [#21](https://github.com/andersoxie/xpact/pull/21) | `4df05be` | [issue-0020](issue-0020/report.md) |
| [#22](https://github.com/andersoxie/xpact/issues/22) | One-page status summary for the supervisor: `student/for superviser.txt` | [#23](https://github.com/andersoxie/xpact/pull/23) | `384f838` | [issue-0022](issue-0022/report.md) |
| [#24](https://github.com/andersoxie/xpact/issues/24) | Record the GitHub labels in the repository | [#25](https://github.com/andersoxie/xpact/pull/25) | `e6d6732` | [issue-0024](issue-0024/report.md) |
| [#26](https://github.com/andersoxie/xpact/issues/26) | Put the B03 work (#3, #12, #13) on hold | [#27](https://github.com/andersoxie/xpact/pull/27) | `2f0d441` | [issue-0026](issue-0026/report.md) |
| [#28](https://github.com/andersoxie/xpact/issues/28) | Regression test for the CR loop variant in `normalized_input` (test only; repair proposed, not committed) | [#31](https://github.com/andersoxie/xpact/pull/31) | see the pull request | [issue-0028](issue-0028/report.md) |
| [#29](https://github.com/andersoxie/xpact/issues/29) | W3C suite with assertions off and on: results, error report, finding [#28](https://github.com/andersoxie/xpact/issues/28) | [#30](https://github.com/andersoxie/xpact/pull/30) | `8850dab` | [issue-0029](issue-0029/report.md) |

On hold ([#26](https://github.com/andersoxie/xpact/issues/26)):
[#3](https://github.com/andersoxie/xpact/issues/3) (B03 loop variant, fix in
draft pull request [#12](https://github.com/andersoxie/xpact/pull/12)) and
[#13](https://github.com/andersoxie/xpact/issues/13) (GC critical section
swallows exceptions), being checked further before asking for review.

## Error reports

Dated reports of failures seen in one session, before they were split into
issues.

| Date | Report | Issues |
|---|---|---|
| 2026-10-19 | [error-reports/2026-10-19.md](error-reports/2026-10-19.md) | #2, #3, #4 |
| 2026-10-21 | [error-reports/2026-10-21.md](error-reports/2026-10-21.md) | #28, #29 |

Weeks 1-2 (before git) are in [`student/history/`](../student/history/).
