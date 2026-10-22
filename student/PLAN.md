# 10-week plan

> **Last updated:** 2026-10-22 (week 3) · describes `student-Mass` after #36, #41, #42 and #44 were merged
> · ✅ done · 🟡 in progress / waiting · ⬜ not started · 🔴 open problem

The plan comes from [`docs/xpact-student-introduction.md`](../docs/xpact-student-introduction.md)
("A proposed ten week plan", "Suggested student selection"). The rules for
issues, reports and pull requests are in [`CLAUDE.md`](../CLAUDE.md) and
[`VERSIONING.md`](VERSIONING.md). Week 1 = 2026-10-05; review with the
supervisor at the end of every week. [PLAN2.md](PLAN2.md) is the frozen
record of weeks 1-2. Day-to-day status of every issue: the
[project board](https://github.com/users/CodTanium/projects/3).

## At a glance

| Week | | What | Evidence |
|---|---|---|---|
| 1 Setup | ✅ | Build working, A01 | [week-01](notes/weekly/week-01.md), [#18](https://github.com/andersoxie/xpact/issues/18) |
| 2 Baseline | ✅ | Assertions baseline (2026-10-14) and its rerun in git, A02 | [BASELINE.md](baseline/BASELINE.md), [A02-baseline](results/A02-baseline/README.md) |
| 3 Failure reporting | 🟡 | Build fixes in git ✅, W3C run ✅, #28 test ✅, repair and GitHub setup ✅ · **B01, B02 ⬜ (due Fri 2026-10-23)** | [week-03](notes/weekly/week-03.md) |
| 4 Input matrix | ⬜ | G01: 50-100 reviewed W3C cases | |
| 5 Regressions | 🟡 | C02, C03, C10 (part) **run early** through the DLL: 3,360 cases, 3 new findings | [dll-tests-2026-10-22](results/dll-tests-2026-10-22/README.md) |
| 6-10 | ⬜ | One improvement, Expat comparison, consolidate, report, handover | |

## ✅ Merged on 2026-10-22

Four stacked pull requests, merged in order at the student's request:

| # | Pull request | Commit | Issue |
|---|---|---|---|
| 1 | [#36](https://github.com/andersoxie/xpact/pull/36) Repair the repository state left on 2026-10-21 | `6e2278e` | [#34](https://github.com/andersoxie/xpact/issues/34) ✅ closed |
| 2 | [#41](https://github.com/andersoxie/xpact/pull/41) C# test program for the xpact DLL | `79f2a29` | [#37](https://github.com/andersoxie/xpact/issues/37) ✅ closed |
| 3 | [#42](https://github.com/andersoxie/xpact/pull/42) Record the GitHub labels and week milestones | `c01f743` | [#35](https://github.com/andersoxie/xpact/issues/35) ✅ closed |
| 4 | [#44](https://github.com/andersoxie/xpact/pull/44) These doc updates | this one | [#43](https://github.com/andersoxie/xpact/issues/43) ✅ closed |

Next time a pull request is merged: check the result, then close its issue
by hand with "Fixed in `<sha>` (PR #N)" (merging into `student-Mass` does not close it).

## 🔴 Known problems (living list)

Every open problem, with its status. **Cause:** ✔ confirmed · ❓ suspected · ❔ unknown.
Update a row when its status changes; move it to "Solved" below, never delete it.

| Problem | Seen in | Cause | Issue | Next step |
|---|---|---|---|---|
| CR in the input: `normalized_input` loop variant fails (assertions on) | W3C 1,357 crashes; DLL; [regression test](../reports/issue-0028/report.md) | ✔ one line, repair proposed | [#28](https://github.com/andersoxie/xpact/issues/28) | parser developer repairs; then rerun W3C |
| B03: `direct_start_tag_attributes` loop variant at `/>` | test matrix (K1); **every `/>` input through the DLL** | ✔ fix in draft [#12](https://github.com/andersoxie/xpact/pull/12), confirmed with a DLL build | [#3](https://github.com/andersoxie/xpact/issues/3) | review #12 |
| GC-suspended parses swallow exceptions | B03 analysis; crashes without a trace | ✔ (swallowing) · ❓ (lost traces) | [#13](https://github.com/andersoxie/xpact/issues/13) | parser developer |
| Start handler: rest of the document not parsed, `<root>` accepted, end events lost (C01) | DLL tests, all DLLs | ❓ C01 shortcut | [#38](https://github.com/andersoxie/xpact/issues/38) | parser developer |
| Invalid UTF-8 accepted in all six places (K4) | DLL tests: 2,106 of 2,148 | ❓ no strict decoder (C08) | [#39](https://github.com/andersoxie/xpact/issues/39) | parser developer |
| Non-final chunk ending with `<` crashes the assertions DLL | DLL tests: 644 crashes | ✔ trigger · ❓ in the code | [#40](https://github.com/andersoxie/xpact/issues/40) | parser developer |
| Finalized test lane has no `-keep`, so assertions are off (K2) | baseline step 3 | ✔ | [draft 04](github/issues/04-finding-finalized-keep.md) | B02 shows it; ask the supervisor before changing CI |
| The test program stops at the first contract failure | baseline K1 | ✔ | [draft 06](github/issues/06-finding-runner-stops.md) | part of B01 |
| Assertions DLL smoke test crashes `0xC0000028` (K3) | baseline; A02; still with the B03 fix | ❔ (B03 is not the only cause) | [draft 07](github/issues/07-finding-dll-crash.md) | after #28 and #40 are repaired, rerun |
| 53 W3C cases crash (week 2) | xmlconf 2026-10-14 | ❔ hidden behind #28 | [draft 21](github/issues/21-finding-xmlconf-crashes.md) | recheck after #28 |
| W3C, assertions off: 220 malformed documents accepted, 16 well-formed rejected | [W3C 2026-10-21](results/w3c-conformance-2026-10-21/README.md) | ❔ (partly #39?) | [#29](https://github.com/andersoxie/xpact/issues/29) | sort them in G01 |
| `run_eiffel_test_matrix.ps1 -BuildMode Workbench` does not load MSVC, `finish_freezing` fails | [#28 report](../reports/issue-0028/report.md#how-the-lanes-were-run) | ✔ | not filed yet | file as a finding |
| Error codes differ from libexpat (`<root>` 5 not 3, junk 4 not 9) | DLL tests | ❔ reference values not checked | (G03) | check against Expat 2.8.1 |
| Jenkins precompile prompt | weeks 1-2 history | ❔ | [draft 23](github/issues/23-finding-jenkins-precompile.md) | |
| Build fixes are on `student-Mass`, not `main` | | (decision) | [draft 22](github/issues/22-blocker-build-fixes.md) | **supervisor decides; never merge into `main` ourselves** |

**Workarounds in use (not fixes):** `fix.ps1` stops in Windows PowerShell 5.1,
so its steps are done by hand ([VERSIONING.md](VERSIONING.md#fixps1-in-windows-powershell-51));
`vcvars64.bat` needs the Visual Studio Installer folder on `PATH` ([setup guide](report/setup-guide.md)).

<details>
<summary>✅ Solved</summary>

| Problem | Fixed in | Issue |
|---|---|---|
| Eiffel runtime include path | `9eb18bd` | [#2](https://github.com/andersoxie/xpact/issues/2) |
| MSVC imports grew `PATH` past cmd's limit | `3b8a205` | [#4](https://github.com/andersoxie/xpact/issues/4) |
| Native library needs the `msc_vc140` backend | `eb6fc5d` | [#7](https://github.com/andersoxie/xpact/issues/7) |
| Native runtime smoke test build | `20e6bc3` | [#10](https://github.com/andersoxie/xpact/issues/10) |
| W3C harness tests fail on Python 3.10 | `492c6eb` | [#32](https://github.com/andersoxie/xpact/issues/32) |
| Repository state of 2026-10-21 (overwritten baseline log, direct pushes, uncommitted docs) | `6e2278e` | [#34](https://github.com/andersoxie/xpact/issues/34) |

</details>

## ➡️ Next

1. **B02** ([#46](https://github.com/andersoxie/xpact/issues/46), week 3, due Friday): one deliberately failing test; every lane of `run_eiffel_test_matrix.ps1` must exit nonzero. Expected to show K2.
2. **B01** ([#45](https://github.com/andersoxie/xpact/issues/45)): accumulated failures give a nonzero exit code; the runner does not stop at the first failure (draft 06).
3. **Ask the supervisor** the questions in [`for superviser.txt`](for%20superviser.txt).
4. **Week 4, G01:** choose 50-100 W3C cases from `results.tsv` (passes and failures, both builds).
5. **C02/C03/C10, remaining:** compare with Expat 2.8.1 (needs an Expat build); turn the findings into regression tests once the parser is repaired.

<details>
<summary>The five tests chosen on 2026-10-21 and where they stand</summary>

From [`notes/next-tests-2026-10-21.txt`](notes/next-tests-2026-10-21.txt):

| | Test | State |
|---|---|---|
| ✅ | 1. CR regression (#28) | Test in `1ea242e`; fails with assertions on until the parser is repaired |
| ⬜ | 2. B02 deliberately failing meta-test | next |
| ✅ | 3. C02 through the DLL | [#37](https://github.com/andersoxie/xpact/issues/37), found #38 |
| 🟡 | 4. C03 every split position | run in #37 (found #40); the Expat comparison is still to do |
| ✅ | 5. C10 (part) malformed UTF-8 | run in #37, found #39 |

</details>


## Week 1 – Setup
**Activity:** Learn basic XML, the project structure and the Git workflow. Build with help.
**Bring to review:** Setup notes and one successful example parse.
- [x] Native build working (done outside git in weeks 1-2, see [PLAN2.md](PLAN2.md) week 1; brought into git in week 3, see [Build fixes in git](#build-fixes-and-workflow-in-git-week-3))
- [x] First error report ([history/](history/)) and setup notes ([week-01.md](notes/weekly/week-01.md))
- [x] [A01](github/issues/01-A01.md) Learn XML events, contracts, Git and the layout; trace one accepted and one rejected document. Done 2026-10-20 ([#18](https://github.com/andersoxie/xpact/issues/18)). Traces: [walkthrough/trace-output.txt](baseline/walkthrough/trace-output.txt). The notes on the checking tests and the change-and-predict exercise go in `results/A01-orientation/`

## Week 2 – Baseline
**Activity:** Follow parser events and run the assertions-enabled tests.
**Bring to review:** A baseline log with revision, configuration, commands and known failures.
- [x] Assertions-enabled baseline with every lane logged: [baseline/BASELINE.md](baseline/BASELINE.md)
- [x] [A02](github/issues/02-A02.md) Reproduce assertions-enabled workbench and finalized builds: rerun in the git clone on 2026-10-22 at `1799b35`, every step as expected ([#33](https://github.com/andersoxie/xpact/issues/33), [A02-baseline](results/A02-baseline/README.md), [setup guide](report/setup-guide.md))
- [ ] Report the baseline findings (each one's state is in [Known problems](#-known-problems-living-list)):
  - [ ] [Finalized lane drops assertions (missing `-keep`)](github/issues/04-finding-finalized-keep.md): still a draft
  - [x] Postcondition `final_finished_or_suspended` fails (B03): [#3](https://github.com/andersoxie/xpact/issues/3). Fix in draft [#12](https://github.com/andersoxie/xpact/pull/12), on hold. *2026-10-22:* also the cause of every `/>` crash through the DLL (confirmed with a B03-fixed build, #37)
  - [x] New, found while analysing B03: `XP_GC_CRITICAL_SECTION.execute` swallows exceptions: [#13](https://github.com/andersoxie/xpact/issues/13)
  - [ ] [Test runner stops at the first failure](github/issues/06-finding-runner-stops.md): still a draft
  - [ ] [Assertions DLL smoke test crashes](github/issues/07-finding-dll-crash.md): still a draft; *2026-10-22:* still crashes with the B03 fix
  - [x] Python harness fails on Python 3.10: fixed in `492c6eb` ([#32](https://github.com/andersoxie/xpact/issues/32))
  - [ ] [53 W3C cases crash xpact](github/issues/21-finding-xmlconf-crashes.md): can't be rechecked until #28 is repaired
  - [x] New, found in the W3C run with assertions on: the loop variant in `XP_PARSER.normalized_input` fails on every input with a CR: [#28](https://github.com/andersoxie/xpact/issues/28), regression test `1ea242e`
  - [ ] [Jenkins precompile prompt](github/issues/23-finding-jenkins-precompile.md): still a draft
- [ ] **Decision:** choose one main improvement and a small input set with the supervisor

## Build fixes and workflow in git (week 3)
Not a week of the guide's plan: the week 2 blocker ("build fixes not in `main`,
branches deleted") had to be solved before the baseline could be rerun in git.
Each item is one issue, one report and one squashed commit on `student-Mass`.

| | Issue | What | Pull request | Commit | Report |
|---|---|---|---|---|---|
| ✅ | [#2](https://github.com/andersoxie/xpact/issues/2) | Eiffel runtime include fallback path (`build_native_eiffel.ps1`) | - (before the workflow) | `9eb18bd` | [issue-0002](../reports/issue-0002/report.md) |
| ✅ | [#5](https://github.com/andersoxie/xpact/issues/5) | Versioning workflow: [`VERSIONING.md`](VERSIONING.md), [`tools/fix.ps1`](tools/fix.ps1) | [#6](https://github.com/andersoxie/xpact/pull/6) | `cada501` | [issue-0005](../reports/issue-0005/report.md) |
| ✅ | [#7](https://github.com/andersoxie/xpact/issues/7) | Missing `.lnk`: build the native library with the `msc_vc140` backend | [#8](https://github.com/andersoxie/xpact/pull/8) | `eb6fc5d` | [issue-0007](../reports/issue-0007/report.md) |
| ✅ | [#4](https://github.com/andersoxie/xpact/issues/4) | "The input line is too long": stop repeated MSVC imports growing PATH | [#9](https://github.com/andersoxie/xpact/pull/9) | `3b8a205` | [issue-0004](../reports/issue-0004/report.md) |
| ✅ | [#10](https://github.com/andersoxie/xpact/issues/10) | Native runtime smoke test: include fallback and `msc_vc140` backend | [#11](https://github.com/andersoxie/xpact/pull/11) | `20e6bc3` | [issue-0010](../reports/issue-0010/report.md) |
| ✅ | [#14](https://github.com/andersoxie/xpact/issues/14) | One folder per fix under `reports/` | [#15](https://github.com/andersoxie/xpact/pull/15) | `4a957b1` | [issue-0014](../reports/issue-0014/report.md) |
| ✅ | [#20](https://github.com/andersoxie/xpact/issues/20) | Docs in line with the week 3 workflow; week 3 note | [#21](https://github.com/andersoxie/xpact/pull/21) | | [issue-0020](../reports/issue-0020/report.md) |
| ✅ | [#22](https://github.com/andersoxie/xpact/issues/22), [#24](https://github.com/andersoxie/xpact/issues/24), [#26](https://github.com/andersoxie/xpact/issues/26) | Supervisor page, labels recorded, B03 on hold | [#23](https://github.com/andersoxie/xpact/pull/23), [#25](https://github.com/andersoxie/xpact/pull/25), [#27](https://github.com/andersoxie/xpact/pull/27) | `384f838`, `e6d6732`, `2f0d441` | [reports/](../reports/README.md) |
| ✅ | [#28](https://github.com/andersoxie/xpact/issues/28), [#32](https://github.com/andersoxie/xpact/issues/32), [#33](https://github.com/andersoxie/xpact/issues/33) | CR regression test, Python 3.10, A02 rerun (**pushed without a pull request**, see #34) | - | `1ea242e`, `492c6eb`, `1799b35`, `42d6b40` | [issue-0028](../reports/issue-0028/report.md), [issue-0032](../reports/issue-0032/report.md) |
| ✅ | [#34](https://github.com/andersoxie/xpact/issues/34) | Repair of the repository state of 2026-10-21 | [#36](https://github.com/andersoxie/xpact/pull/36) | `6e2278e` | [issue-0034](../reports/issue-0034/report.md) |
| ✅ | [#35](https://github.com/andersoxie/xpact/issues/35) | GitHub labels and week milestones (`CLAUDE.md`) | [#42](https://github.com/andersoxie/xpact/pull/42) | `c01f743` | [issue-0035](../reports/issue-0035/report.md) |
| ✅ | [#43](https://github.com/andersoxie/xpact/issues/43) | All student docs brought up to date | [#44](https://github.com/andersoxie/xpact/pull/44) | | |
| 🟡 | [#3](https://github.com/andersoxie/xpact/issues/3) | B03 loop variant | [#12](https://github.com/andersoxie/xpact/pull/12) (draft, on hold) | | |

Together, #2, #7 and #10 bring in the week 1 build fixes from
[patch 01](history/patches/01-week1-build-fixes.patch), except its
`run_xmlconf_conformance.ps1` part. [Patch 02](history/patches/02-week2-runner-changes.patch)
(pinned W3C download, test-matrix stderr guard) is not applied yet.
The 2026-10-19 error report is [reports/error-reports/2026-10-19.md](../reports/error-reports/2026-10-19.md).

## Week 3 – Failure reporting
**Activity:** Learn how the test runner reports failure. Reproduce a deliberately failing test.
**Bring to review:** A bounded failure-reporting fix, or a precise proposal with evidence.
- [ ] [B01](https://github.com/andersoxie/xpact/issues/45) Failing tests must return a nonzero exit status
- [ ] [B02](https://github.com/andersoxie/xpact/issues/46) Deliberately failing meta-tests
- [x] Week 3 note: [week-03.md](notes/weekly/week-03.md) (written 2026-10-20, updated 2026-10-21 and 2026-10-22)
- [x] W3C suite with the Python runner, assertions off and on: [#29](https://github.com/andersoxie/xpact/issues/29), [results/w3c-conformance-2026-10-21/](results/w3c-conformance-2026-10-21/README.md), [error report](../reports/error-reports/2026-10-21.md)
- [x] Regression test for the CR crash: [#28](https://github.com/andersoxie/xpact/issues/28), `1ea242e` (fails with assertions on until the parser is repaired)
- [x] Repository repair and GitHub setup per `CLAUDE.md`: [#34](https://github.com/andersoxie/xpact/issues/34), [#35](https://github.com/andersoxie/xpact/issues/35), [#43](https://github.com/andersoxie/xpact/issues/43) (merged 2026-10-22)

## Week 4 – Input matrix
**Activity:** Design small regressions and select 50–100 applicable W3C XML cases with the supervisor.
**Bring to review:** An input matrix with reviewed expected outcomes.
- [ ] [G01](github/issues/11-G01.md) Corpus manifest and 50–100 reviewed W3C cases
- [ ] [Fix xmlconf verdict rules](github/issues/12-xmlconf-verdicts.md)

## Week 5 – Regressions
**Activity:** Run the selected small inputs with different callbacks and chunk boundaries.
**Bring to review:** Repeatable regressions and small bug reproductions.
Run early (2026-10-22) with the C# DLL test program ([#37](https://github.com/andersoxie/xpact/issues/37), [results](results/dll-tests-2026-10-22/README.md)): 3,360 cases on three DLLs.
- [x] [C02](github/issues/13-C02.md) Malformed final-input cases with all six callback sets: run; found [#38](https://github.com/andersoxie/xpact/issues/38) (C01 shortcut). Regressions in the Eiffel suite still to add once repaired
- [ ] [C03](github/issues/14-C03.md) Chunk boundaries: every split and byte by byte run, found [#40](https://github.com/andersoxie/xpact/issues/40); **comparison with Expat 2.8.1 still to do**
- [x] [C10 (part)](github/issues/15-C10.md) Malformed UTF-8 in six places, whole and split: run; found [#39](https://github.com/andersoxie/xpact/issues/39). Expat comparison still to do
- [ ] **Decision:** review with the supervisor what can realistically be completed

## Week 6 – One improvement
**Activity:** Pair on one manageable test-framework or verification-script improvement.
**Bring to review:** Before-and-after results and a reviewed change.
- [ ] The improvement chosen in week 2 (B01/B02, the xmlconf verdicts or a C-group regression), reviewed and merged

## Week 7 – Comparison
**Activity:** Compare xpact and libexpat; add more applicable W3C cases as time permits.
**Bring to review:** A table of matches, differences and untested cases.
- [ ] [A04](github/issues/16-A04.md) Verify which library the tests load
- [ ] [G03](github/issues/17-G03.md) xpact vs Expat comparison across chunks

## Week 8 – Consolidate
**Activity:** Consolidate the results and add selected SVG or libxml2 cases. Core integration stays optional.
**Bring to review:** Shared fixtures and comparison output, or documented integration requirements.
- [ ] Shared fixtures and comparison output committed under `results/`
- [ ] Optional: [F01](github/issues/19-F01.md) Core build, [F02](github/issues/20-F02.md) Core runner

## Week 9 – Analyse and draft
**Activity:** Analyse the results and draft the report. Try selected PubMed files if the correctness checks permit.
**Bring to review:** A draft report and result tables tied to specific builds.
- [ ] [Report draft](github/issues/18-report-handover.md) in [`report/`](report/)

## Week 10 – Handover
**Activity:** Demonstrate the work, address review comments and hand it over.
**Bring to review:** Final report, tests, code or proposals, setup guide and follow-up list.
- [ ] [Report, demonstration and handover](github/issues/18-report-handover.md)
- [ ] [A06](github/issues/03-A06.md) All weekly notes and result records complete. Weeks 1-2 written

## Not in the plan (unless the supervisor asks)
The other tasks in the register (A03, A05, B03–B07, C01, C04–C09, D, E, F03–F09,
G02, G04–G10, H) are context, or work owned by experienced developers. B04 or
B05 is an alternative to B01/B02 if failure accounting turns out to be more useful.
