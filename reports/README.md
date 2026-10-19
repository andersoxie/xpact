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
| [#18](https://github.com/andersoxie/xpact/issues/18) | Mark A01 as done in `student/PLAN.md` | [#19](https://github.com/andersoxie/xpact/pull/19) | see the pull request | [issue-0018](issue-0018/report.md) |

Open: [#3](https://github.com/andersoxie/xpact/issues/3) (B03 loop variant, fix
in pull request [#12](https://github.com/andersoxie/xpact/pull/12) waiting for
review by the parser's developer) and
[#13](https://github.com/andersoxie/xpact/issues/13) (GC critical section
swallows exceptions).

## Error reports

Dated reports of failures seen in one session, before they were split into
issues.

| Date | Report | Issues |
|---|---|---|
| 2026-10-19 | [error-reports/2026-10-19.md](error-reports/2026-10-19.md) | #2, #3, #4 |

Weeks 1-2 (before git) are in [`student/history/`](../student/history/).
