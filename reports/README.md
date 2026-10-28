# Reports

Every fix on `student-Mass` has one folder here, named after its GitHub issue
and padded to four digits so the folders sort by number. Each folder holds
`report.md` (cause, change, `## Verification`, how to revert) and the logs and
test scripts that back it up. The rules are in
[`student/VERSIONING.md`](../student/VERSIONING.md) and [`CLAUDE.md`](../CLAUDE.md).

> **Updated 2026-10-28** (`student-Mass` after PR #152, which brings in `main` @ `1714f31`). Latest W3C result:
> [latest-2026-10-28](latest-2026-10-28/README.md) (2,585 cases, 0 failed, 0 errors, 0 skipped).
> W3C **output** (content, not only the verdict): [issue-0154](issue-0154/report.md), [issue-0156](issue-0156/report.md), [issue-0157](issue-0157/report.md): 395 of 432 right (was 359).
> #74, #79, #142, #146, #148, #151, #153, #154, #155, #156 and #157 wait for a Jenkins run (#73 verified on Jenkins, closed 2026-10-26)
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
| [#74](https://github.com/andersoxie/xpact/issues/74) | `build_native_eiffel.ps1` and `run_native_runtime_smoke.ps1` keep an existing MSVC backend (`msc*`) instead of always forcing `msc_vc140` | [#76](https://github.com/andersoxie/xpact/pull/76) | `7cf5a94` | [issue-0074](issue-0074/report.md) |
| [#79](https://github.com/andersoxie/xpact/issues/79) | Parser conformance: strict UTF-8, UTF-16, names, DTD declarations, loop progress; #38, #39, #40 and K3 in the DLL; W3C known-failures list (empty) | (the pull request) | see `git log --grep "Refs #79"` | [issue-0079](issue-0079/report.md), [Jenkins log before](issue-0079/jenkins-log-cf12dee-before.txt) |
| [#90](https://github.com/andersoxie/xpact/issues/90) | Follow-up: quote the email recipient default so both Jenkinsfiles compile as Declarative Pipeline | (the pull request) | see `git log --grep "Fix Declarative email parameter defaults"` | [issue-0090](issue-0090/report.md) |
| [#104](https://github.com/andersoxie/xpact/issues/104) | Full check of `student-Mass` @ `41731c8` after the sync with `main`: every build and test passes with assertions on; #3, #39, #40 verified; Python test problems traced to Python 3.10 and long paths; `student/PLAN.md` brought up to date | (the pull request) | see `git log --grep "Refs #104"` | [issue-0104](issue-0104/report.md), [logs](issue-0104/logs/) |
| [#106](https://github.com/andersoxie/xpact/issues/106) | Weeks 2-3 in `student/PLAN.md`: K3 and the W3C crashes ticked as fixed (evidence from #104), #46 ticked as dropped; three items left open with the reason (supervisor decision, 6 labels, project board scope) | (the pull request) | see `git log --grep "Refs #106"` | [issue-0106](issue-0106/report.md) |
| [#108](https://github.com/andersoxie/xpact/issues/108) | The 6 missing labels created (#35), all 21 match `labels.json`; project board brought up to date (16 issues added, 9 statuses corrected) | (the pull request) | see `git log --grep "Refs #108"` | [issue-0108](issue-0108/report.md) |
| [#110](https://github.com/andersoxie/xpact/issues/110) | `student-Mass` synced with `main` after the supervisor's #101 (0 behind); tests on the merged code with MSVC: matrix 4/4, DLL tests 3,360/3,360 on both DLLs, W3C 1,727/1,727 in both builds | [#111](https://github.com/andersoxie/xpact/pull/111) (merge commit) | `e8c5cb3` | [issue-0110](issue-0110/report.md), [logs](issue-0110/logs/) |
| [#113](https://github.com/andersoxie/xpact/issues/113) | Student PC brought closer to the supervisor's: MSVC backend, Python 3.14, git and Windows long paths; matrix and W3C with MSVC pass, all 178 Python tests pass; remaining version differences recorded | (the pull request) | see `git log --grep "Refs #113"` | [issue-0113](issue-0113/report.md), [logs](issue-0113/logs/) |
| [#115](https://github.com/andersoxie/xpact/issues/115) | Student docs brought up to 2026-10-26: PLAN.md, README, GUIDE section 6, supervisor page, week 4 note | (the pull request) | see `git log --grep "Refs #115"` | [issue-0115](issue-0115/report.md) |
| [#117](https://github.com/andersoxie/xpact/issues/117) | xmlconf verdict rules (draft 12): old PowerShell runner superseded; 2026-10-14 results re-scored with the runner's rules: 676 of 854 "failures" were wrong rules, the 233 real problems pass today | (the pull request) | see `git log --grep "Refs #117"` | [issue-0117](issue-0117/report.md), [results](../student/results/xmlconf-verdicts/README.md) |
| [#118](https://github.com/andersoxie/xpact/issues/118) | G01: corpus manifest of 93 W3C cases (83 counted, 10 marked) with hashes, dependencies and reviewed expected outcomes; `--check` for other machines; selected by the student, not reviewed by the supervisor | (the pull request) | see `git log --grep "Refs #118"` | [issue-0118](issue-0118/report.md), [results](../student/results/G01-corpus/README.md) |
| [#121](https://github.com/andersoxie/xpact/issues/121) | C03/C10: the DLL tests run on Expat 2.8.1's own `libexpat.dll` and compared case by case: 4,308/4,308 same verdicts; 5 findings (#122-#126); `80` and `FF` inputs added | [#127](https://github.com/andersoxie/xpact/pull/127) | `ed3febc` | [issue-0121](issue-0121/report.md), [results](../student/results/expat-2.8.1/README.md) |
| [#128](https://github.com/andersoxie/xpact/issues/128) | C02: the #38, #39, #40 inputs as permanent tests in the DLL smoke test and the Eiffel suite; with the #38 or #40 fix undone they fail | [#129](https://github.com/andersoxie/xpact/pull/129) | `508d9c5` | [issue-0128](issue-0128/report.md), [results](../student/results/C02-final-input/README.md) |
| [#132](https://github.com/andersoxie/xpact/issues/132) | Removed the unused old copy `tests/python/run_w3c_conformance.py`; Python tests 178 OK before and after | [#133](https://github.com/andersoxie/xpact/pull/133) | `e847813` | [issue-0132](issue-0132/report.md) |
| [#134](https://github.com/andersoxie/xpact/issues/134) | Docs after week 5: merge commits, #130/#131 linked, cause icons corrected (suspected = ❓) | [#135](https://github.com/andersoxie/xpact/pull/135) | `77899f4` | [issue-0134](issue-0134/report.md) |
| [#137](https://github.com/andersoxie/xpact/issues/137) | PR #76 (#74) retested and merged; 11 merged branches deleted on GitHub and on the mass-xpact copy, 20 local | [#138](https://github.com/andersoxie/xpact/pull/138) | `d2f98a9` | [issue-0137](issue-0137/report.md) |
| [#140](https://github.com/andersoxie/xpact/issues/140) | `student/tools/collect-supervisor-info.ps1`: one read-only command for the supervisor that collects tools, Jenkins builds, dual-lane runs, WSL and large-XML information into one .txt | (the pull request) | see `git log --grep "Refs #140"` | [issue-0140](issue-0140/report.md) |
| [#142](https://github.com/andersoxie/xpact/issues/142) | `-SkipSmoke` removed from the assertions DLL build in both Jenkinsfiles and the release script, and from the libexpat stage; all smokes ok locally, Jenkins run pending | (the pull request) | see `git log --grep "Refs #142"` | [issue-0142](issue-0142/report.md) |
| [#143](https://github.com/andersoxie/xpact/issues/143) | The native libexpat Python tests also find the CMake bundled with Visual Studio (via `vswhere`); Python suite 178 run, 0 skipped (before: 7 skipped) | (the pull request) | see `git log --grep "Refs #143"` | [issue-0143](issue-0143/report.md) |
| [#146](https://github.com/andersoxie/xpact/issues/146) | **Option A**: W3C runner `--all-cases` (0 skipped, 4 lanes), DLL checker, and parser fixes F1-F7 found by it; 2,585/2,585 in both builds (30 s), Jenkins pending | [#147](https://github.com/andersoxie/xpact/pull/147) closed, superseded by [#152](https://github.com/andersoxie/xpact/pull/152) | see `git log --grep "Refs #146"` | [issue-0146](issue-0146/report.md) |
| [#148](https://github.com/andersoxie/xpact/issues/148) | Internal entity references no longer cost time proportional to the document: the XML spec 1,100 -> 79 ms (16 s -> 0.2 s with assertions); errors inside entities now at the reference, as in Expat. Code integrated in #151 | [#149](https://github.com/andersoxie/xpact/pull/149) closed, superseded by [#152](https://github.com/andersoxie/xpact/pull/152) | see `git log --grep "Refs #148"` | [issue-0148](issue-0148/report.md) |
| [#151](https://github.com/andersoxie/xpact/issues/151) | **#146 + #148 integrated with `main` (#150)**: teacher's code kept for F2/F4/F5/F6a, student's F1/F3/F7/#148 kept, F6b removed (E38 reversed by E10); `main` DLL crashes (F1, F3) and `pr-xml-*` timeouts (#148) gone; all 2,585 W3C cases and the DLL lane 247/247 pass in both builds | the pull request | 6 commits on `fix/151-integrate-146-148-with-main` | [issue-0151](issue-0151/report.md) |
| [#154](https://github.com/andersoxie/xpact/issues/154), [#155](https://github.com/andersoxie/xpact/issues/155) | **Attribute defaults across external files**: `<!ATTLIST>` from an external DTD / parameter entity now reaches the document, and an external entity sees the document's declarations (`src/xp_parser.e`). New W3C **output** test (432 cases with an expected output file): 359 -> **393**, 0 worse; all old lanes unchanged; Jenkins pending | [#160](https://github.com/andersoxie/xpact/pull/160) | `7028e68` | [issue-0154](issue-0154/report.md) |
| [#156](https://github.com/andersoxie/xpact/issues/156) | The declared default of a tokenized attribute (`NMTOKENS`, `ID`, enumerations …) is normalized like a specified value (XML 1.0 §3.3.3), before it is stored and reported, as Expat does. W3C output test 393 -> **394** (`valid-sa-096`), 0 worse; #156 now 4/4; all old lanes unchanged; Jenkins pending | [#161](https://github.com/andersoxie/xpact/pull/161) | `d0a4e21` | [issue-0156](issue-0156/report.md) |
| [#157](https://github.com/andersoxie/xpact/issues/157) | **Public identifiers normalized** (XML 1.0 §4.2.2) in DOCTYPE, NOTATION, ENTITY and unparsed ENTITY, as Expat does; also what the resolver receives. W3C output test 394 -> **395** (`notation01`), 0 worse; all old lanes unchanged; Jenkins pending | (the pull request) | see `git log --grep "Refs #157"` | [issue-0157](issue-0157/report.md) |
| [#153](https://github.com/andersoxie/xpact/issues/153) | Dual regression lane: 61 small inputs on xpact and Xpact-core, whole, split at every byte and byte by byte, with event traces, plus a 10-step lifecycle; xpact 910/910 in both builds, Xpact-core 887/910 | [#152](https://github.com/andersoxie/xpact/pull/152) | see `git log --grep "mass-xpact#1"` | [dual-regression-2026-10-28](dual-regression-2026-10-28/summary.md) |
| - | **W3C report for the integrated version** (2026-10-28): all 2,585 cases at 10 s, 2,283 checked + 302 no crash only, 0 failed, 0 errors, 0 skipped; DLL entity lane 247/247 | [#152](https://github.com/andersoxie/xpact/pull/152) | - | [latest-2026-10-28](latest-2026-10-28/README.md) |

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
