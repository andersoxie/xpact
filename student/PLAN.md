# 10-week plan

Based on [`docs/xpact-student-introduction.md`](../docs/xpact-student-introduction.md):
"A proposed ten week plan" and "Suggested student selection". Tasks link to
their GitHub issue once it exists, otherwise to the draft in
[`github/issues/`](github/issues/). Every fix follows
[`VERSIONING.md`](VERSIONING.md), and its report is indexed in
[`reports/README.md`](../reports/README.md).

Week 1 = 2026-10-05. Review with the supervisor at the end of every week, and
write the weekly note in [`notes/weekly/`](notes/weekly/).

**Last updated:** 2026-10-21 (week 3), `student-Mass` @ `8850dab`.
[PLAN2.md](PLAN2.md) has the detailed record of weeks 1-2 (evidence, tests run, findings) as of 2026-10-15.

## Where things stand

| | |
|---|---|
| Current week | 3 – Failure reporting |
| Done in week 3 | The week 1 build fixes are now commits on `student-Mass`, each with an issue, a report with verification and a pull request: [#2](https://github.com/andersoxie/xpact/issues/2), [#4](https://github.com/andersoxie/xpact/issues/4), [#7](https://github.com/andersoxie/xpact/issues/7), [#10](https://github.com/andersoxie/xpact/issues/10). Versioning workflow ([#5](https://github.com/andersoxie/xpact/issues/5)) and one report folder per fix ([#14](https://github.com/andersoxie/xpact/issues/14)). B03 root cause found ([#3](https://github.com/andersoxie/xpact/issues/3)) and a new finding behind it ([#13](https://github.com/andersoxie/xpact/issues/13)) |
| On hold | B03 ([#3](https://github.com/andersoxie/xpact/issues/3), draft pull request [#12](https://github.com/andersoxie/xpact/pull/12)) and [#13](https://github.com/andersoxie/xpact/issues/13): being checked further before asking for review ([#26](https://github.com/andersoxie/xpact/issues/26)) |
| Still blocked | The build fixes are on `student-Mass`, not on `main` ([draft 22](github/issues/22-blocker-build-fixes.md)). Ask the supervisor whether to open a pull request into `main` |
| Also done | A01 orientation ([#18](https://github.com/andersoxie/xpact/issues/18)). W3C suite with the Python runner, assertions off and on ([#29](https://github.com/andersoxie/xpact/issues/29), [results](results/w3c-conformance-2026-10-21/README.md)): off 1,491/1,727 passed; on 1,360 crashes, 1,357 of them a new finding ([#28](https://github.com/andersoxie/xpact/issues/28)) |
| Next | The five tests below, in this order. Also A02: rerun the baseline in the git clone. Patch 02 (see [history/README.md](history/README.md)) is no longer needed for the W3C download: the Python runner does it |

### Next tests (chosen 2026-10-21)

From the guide's plan and task register, compared with what has been run so far:

1. **CR regression ([#28](https://github.com/andersoxie/xpact/issues/28))**: the 9-byte [`cr-lf.xml`](results/w3c-conformance-2026-10-21/cr-lf.xml) must be accepted with assertions on. It blocks every other assertion result in the W3C suite.
2. **B02**: a deliberately failing test must make every lane of `run_eiffel_test_matrix.ps1` exit nonzero (also covers the missing `-keep`, draft 04).
3. **C02**: the guide's first test matrix (`<root/>`, `<root>`, `<root><child></root>`, trailing junk) through the native API (`XML_Parse`), with no callbacks, start, end, start+end, character data and default handler.
4. **C03**: the same inputs split at every byte position, final and non-final, compared with Expat 2.8.1 (start from `scripts/run_chunked_crc_harness.ps1`).
5. **C10 (part)**: malformed UTF-8 (`C3 28`, `C0 AF`, `ED A0 80`, `F4 90 80 80`) in text, attribute, name, comment, PI and CDATA, whole and split. Expected: always REJECT.

Tests 3-5 go through the DLL, which the W3C lane does not test: they need a small C program linked to `xpact_assertions.dll`.

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
- [ ] [A02](github/issues/02-A02.md) Reproduce assertions-enabled workbench and finalized builds. Done outside git in week 2; **rerun in the git clone** is next, now that the build fixes are on `student-Mass`
- [ ] Report the baseline findings:
  - [ ] [Finalized lane drops assertions (missing `-keep`)](github/issues/04-finding-finalized-keep.md)
  - [x] Postcondition `final_finished_or_suspended` fails (B03): reported as [#3](https://github.com/andersoxie/xpact/issues/3). Root cause: the loop variant in `direct_start_tag_attributes` is wrong; fix proposed in draft [#12](https://github.com/andersoxie/xpact/pull/12), on hold
  - [x] New, found while analysing B03: `XP_GC_CRITICAL_SECTION.execute` swallows exceptions, which hid the real B03 failure: [#13](https://github.com/andersoxie/xpact/issues/13)
  - [ ] [Test runner stops at the first failure](github/issues/06-finding-runner-stops.md)
  - [ ] [Assertions DLL smoke test crashes](github/issues/07-finding-dll-crash.md)
  - [ ] [Python harness fails on Python 3.10](github/issues/08-finding-python310.md)
  - [ ] [53 W3C cases crash xpact](github/issues/21-finding-xmlconf-crashes.md). Can't be rechecked until #28 is fixed
  - [x] New, found in the W3C run with assertions on: the loop variant in `XP_PARSER.normalized_input` fails on every input with a CR (1,357 W3C cases): reported as [#28](https://github.com/andersoxie/xpact/issues/28)
  - [ ] [Jenkins precompile prompt](github/issues/23-finding-jenkins-precompile.md)
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
| 🟡 | [#3](https://github.com/andersoxie/xpact/issues/3) | B03 loop variant | [#12](https://github.com/andersoxie/xpact/pull/12) (draft, on hold) | | |

Together, #2, #7 and #10 bring in the week 1 build fixes from
[patch 01](history/patches/01-week1-build-fixes.patch), except its
`run_xmlconf_conformance.ps1` part. [Patch 02](history/patches/02-week2-runner-changes.patch)
(pinned W3C download, test-matrix stderr guard) is not applied yet.
The 2026-10-19 error report is [reports/error-reports/2026-10-19.md](../reports/error-reports/2026-10-19.md).

## Week 3 – Failure reporting
**Activity:** Learn how the test runner reports failure. Reproduce a deliberately failing test.
**Bring to review:** A bounded failure-reporting fix, or a precise proposal with evidence.
- [ ] [B01](github/issues/09-B01.md) Failing tests must return a nonzero exit status
- [ ] [B02](github/issues/10-B02.md) Deliberately failing meta-tests
- [x] Week 3 note: [week-03.md](notes/weekly/week-03.md) (written 2026-10-20, mid-week)
- [x] W3C suite with the Python runner, assertions off and on: [#29](https://github.com/andersoxie/xpact/issues/29), [results/w3c-conformance-2026-10-21/](results/w3c-conformance-2026-10-21/README.md), [error report](../reports/error-reports/2026-10-21.md)

## Week 4 – Input matrix
**Activity:** Design small regressions and select 50–100 applicable W3C XML cases with the supervisor.
**Bring to review:** An input matrix with reviewed expected outcomes.
- [ ] [G01](github/issues/11-G01.md) Corpus manifest and 50–100 reviewed W3C cases
- [ ] [Fix xmlconf verdict rules](github/issues/12-xmlconf-verdicts.md)

## Week 5 – Regressions
**Activity:** Run the selected small inputs with different callbacks and chunk boundaries.
**Bring to review:** Repeatable regressions and small bug reproductions.
- [ ] [C02](github/issues/13-C02.md) Malformed final-input cases
- [ ] [C03](github/issues/14-C03.md) Chunk boundaries
- [ ] [C10 (part)](github/issues/15-C10.md) Malformed UTF-8
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
