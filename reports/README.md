# Reports

Every fix on `student-Mass` has one folder here, named after its GitHub issue
and padded to four digits so the folders sort by number. Each folder holds
`report.md` (cause, change, `## Verification`, how to revert) and the logs and
test scripts that back it up. The rules are in
[`student/VERSIONING.md`](../student/VERSIONING.md) and [`CLAUDE.md`](../CLAUDE.md).

> **Updated 2026-10-22.** 20 fixes and tasks, all merged (draft #12 for B03 is on hold)
> · open problems are listed in
> [`student/PLAN.md`, Known problems](../student/PLAN.md#-known-problems-living-list).
> Test results that are not a fix are in [`student/results/`](../student/results/README.md).

## Fixes

| Issue | Fix | Pull request | Commit on `student-Mass` | Report |
|---|---|---|---|---|
| [#2](https://github.com/andersoxie/xpact/issues/2) | Eiffel runtime include fallback path in `build_native_eiffel.ps1` | - (committed before the workflow) | `9eb18bd` | [issue-0002](issue-0002/report.md) |
| [#3](https://github.com/andersoxie/xpact/issues/3) | B03: fix the loop variant in `direct_start_tag_attributes` (parser change, reviewed before merging) | [#12](https://github.com/andersoxie/xpact/pull/12) | this pull request's squash commit | [issue-0003](issue-0003/report.md) |
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
| [#28](https://github.com/andersoxie/xpact/issues/28) | Regression test for the CR loop variant in `normalized_input` (test only; repair proposed, not committed) | [#31](https://github.com/andersoxie/xpact/pull/31) (closed: committed on `student-Mass` directly, see #34) | `1ea242e` | [issue-0028](issue-0028/report.md) |
| [#29](https://github.com/andersoxie/xpact/issues/29) | W3C suite with assertions off and on: results, error report, finding [#28](https://github.com/andersoxie/xpact/issues/28) | [#30](https://github.com/andersoxie/xpact/pull/30) | `8850dab` | [issue-0029](issue-0029/report.md) |
| [#32](https://github.com/andersoxie/xpact/issues/32) | Python harness test passes on Python 3.10: NUL becomes `?` in `results.tsv` | - (committed on `student-Mass` directly, see #34) | `492c6eb` | [issue-0032](issue-0032/report.md) |
| [#33](https://github.com/andersoxie/xpact/issues/33) | A02: week 2 baseline rerun in the git clone (`run_baseline.ps1 -LogDir`), setup guide | - (committed on `student-Mass` directly, see #34) | `1799b35`, `42d6b40` | [A02-baseline](../student/results/A02-baseline/README.md) |
| [#34](https://github.com/andersoxie/xpact/issues/34) | Repair the repository state of 2026-10-21: restored baseline log, direct pushes recorded, uncommitted docs committed, stale branch deleted | [#36](https://github.com/andersoxie/xpact/pull/36) | `6e2278e` | [issue-0034](issue-0034/report.md) |
| [#35](https://github.com/andersoxie/xpact/issues/35) | GitHub labels (`test`, `build`, `regression`, `investigation`) and milestones Week 1-10 from `CLAUDE.md`, recorded in `student/github/` | [#42](https://github.com/andersoxie/xpact/pull/42) | `c01f743` | [issue-0035](issue-0035/report.md) |
| [#37](https://github.com/andersoxie/xpact/issues/37) | C# test program for the DLL (C02, C03, C10 part): 3,360 cases on three DLLs, findings #38, #39, #40 | [#41](https://github.com/andersoxie/xpact/pull/41) | `79f2a29` | [issue-0037](issue-0037/report.md), [results](../student/results/dll-tests-2026-10-22/README.md) |
| [#43](https://github.com/andersoxie/xpact/issues/43) | Student docs brought up to date (2026-10-22) in the `CLAUDE.md` layout | [#44](https://github.com/andersoxie/xpact/pull/44) | see `git log --grep "(#44)"` | (the pull request) |
| [#48](https://github.com/andersoxie/xpact/issues/48) | Finalized test lanes compile with `-keep`, so the assertions-on lane checks assertions | [#49](https://github.com/andersoxie/xpact/pull/49) | `ccd30ab` | [issue-0048](issue-0048/report.md) |
| [#51](https://github.com/andersoxie/xpact/issues/51) | `import_msvc_environment.ps1` puts the VS Installer folder (`vswhere.exe`) on `PATH` for `vcvars64.bat` | [#52](https://github.com/andersoxie/xpact/pull/52) | `3076a92` | [issue-0051](issue-0051/report.md) |
| [#53](https://github.com/andersoxie/xpact/issues/53) | `run_eiffel_test_matrix.ps1` loads MSVC for workbench lanes when `ISE_C_COMPILER` is `msc*` | [#54](https://github.com/andersoxie/xpact/pull/54) | `ec3c3e6` | [issue-0053](issue-0053/report.md) |
| [#56](https://github.com/andersoxie/xpact/issues/56) | Jenkins precompile finding dropped; #48, #51, #53 recorded as solved in `student/PLAN.md`; finding #55 added | (the pull request) | see `git log --grep "Refs #56"` | (the pull request) |
| [#28](https://github.com/andersoxie/xpact/issues/28) | Parser repair: `normalized_input` advances past a CR (W3C crashes with assertions on: 1,360 to 47) | [#59](https://github.com/andersoxie/xpact/pull/59) | see `git log --grep "(#59)"` | [issue-0028](issue-0028/report.md#repair-2026-10-22) |
| [#60](https://github.com/andersoxie/xpact/issues/60) | The test runner records an exception in one test and runs the rest (`run_test` with `rescue`/`retry`) | [#61](https://github.com/andersoxie/xpact/pull/61) | see `git log --grep "(#61)"` | [issue-0060](issue-0060/report.md) |
| [#45](https://github.com/andersoxie/xpact/issues/45) | B01: both Eiffel test runners exit 1 when a test failed, in every build (`{EXCEPTIONS}.die (1)` instead of `check`) | [#62](https://github.com/andersoxie/xpact/pull/62) | see `git log --grep "(#62)"` | [issue-0045](issue-0045/report.md), [logs](../student/results/B01-nonzero-exit/README.md) |
| [#46](https://github.com/andersoxie/xpact/issues/46) | B02: `XPACT_META_FAIL=assert\|exception` makes the test runners fail on purpose; every lane exits nonzero | [#63](https://github.com/andersoxie/xpact/pull/63) | see `git log --grep "(#63)"` | [issue-0046](issue-0046/report.md), [results](../student/results/B02-meta-tests/README.md) |
| [#55](https://github.com/andersoxie/xpact/issues/55) | `run_eiffel_test_matrix.ps1` runs every lane from the repository root, wherever it is started | [#58](https://github.com/andersoxie/xpact/pull/58) | see `git log --grep "(#58)"` | [issue-0055](issue-0055/report.md) |
| [#64](https://github.com/andersoxie/xpact/issues/64) | Jenkins check of B02 dropped (not pursued); week 3 marked complete in `student/PLAN.md` | (the pull request) | see `git log --grep "Refs #64"` | (the pull request) |
| [#66](https://github.com/andersoxie/xpact/issues/66) | Items put on hold on 2026-10-22 recorded in `student/PLAN.md` (B03/#12, A04, 47 DTD crashes, #13, #38-#40) | (the pull request) | see `git log --grep "Refs #66"` | (the pull request) |
| [#70](https://github.com/andersoxie/xpact/issues/70) | Checklist audit of every closed issue (2026-10-22): verified items ticked on GitHub; dates/commits on four pages; `student/github/README.md` issue tables to #70 | (the pull request) | see `git log --grep "Refs #70"` | [issue-0070](issue-0070/report.md) |
| [#68](https://github.com/andersoxie/xpact/issues/68) | A01 evidence completed: checking tests linked, change-and-predict (predictions committed before the run), notes in `student/results/A01-orientation/` | (the pull request) | see `git log --grep "Refs #68"` | [issue-0068](issue-0068/report.md), [notes](../student/results/A01-orientation/README.md) |
| [#73](https://github.com/andersoxie/xpact/issues/73) | `build_native_eiffel.ps1` and `run_native_runtime_smoke.ps1` search `ISE_EIFFEL`, `C:\El2502E` (Jenkins), 25.12 Standard (student PC), then `ec` on `PATH` | (the pull request) | see `git log --grep "Refs #73"` | [issue-0073](issue-0073/report.md), [Jenkins log](issue-0073/jenkins-log-2026-10-23.txt) |
| [#74](https://github.com/andersoxie/xpact/issues/74) | `build_native_eiffel.ps1` and `run_native_runtime_smoke.ps1` keep an existing MSVC backend (`msc*`) instead of always forcing `msc_vc140` | (the pull request) | see `git log --grep "Refs #74"` | [issue-0074](issue-0074/report.md) |
| [#79](https://github.com/andersoxie/xpact/issues/79) | Parser conformance: strict UTF-8, UTF-16, names, DTD declarations, loop progress; #38, #39, #40 and K3 in the DLL; W3C known-failures list (empty) | (the pull request) | see `git log --grep "Refs #79"` | [issue-0079](issue-0079/report.md), [Jenkins log before](issue-0079/jenkins-log-cf12dee-before.txt) |
| [#90](https://github.com/andersoxie/xpact/issues/90) | Follow-up: quote the email recipient default so both Jenkinsfiles compile as Declarative Pipeline | (the pull request) | see `git log --grep "Fix Declarative email parameter defaults"` | [issue-0090](issue-0090/report.md) |

#36, #41, #42 and #44 were stacked pull requests, merged in that order on 2026-10-22.

Open: [#13](https://github.com/andersoxie/xpact/issues/13) (GC critical section
swallows exceptions).
On hold ([#26](https://github.com/andersoxie/xpact/issues/26)):
[#3](https://github.com/andersoxie/xpact/issues/3) (B03 loop variant, fix in
draft pull request [#12](https://github.com/andersoxie/xpact/pull/12)) and
[#13](https://github.com/andersoxie/xpact/issues/13) (GC critical section
swallows exceptions), being checked further before asking for review.
*2026-10-22:* new evidence for both from the DLL tests (#37), in comments on
[#3](https://github.com/andersoxie/xpact/issues/3) and
[#13](https://github.com/andersoxie/xpact/issues/13): with only the B03 change,
no `/>` input crashes the assertions DLL any more.

## Error reports

Dated reports of failures seen in one session, before they were split into
issues.

| Date | Report | Issues |
|---|---|---|
| 2026-10-19 | [error-reports/2026-10-19.md](error-reports/2026-10-19.md) | #2, #3, #4 |
| 2026-10-21 | [error-reports/2026-10-21.md](error-reports/2026-10-21.md) | #28, #29 |

Weeks 1-2 (before git) are in [`student/history/`](../student/history/).
