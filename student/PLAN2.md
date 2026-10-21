# 10-week plan, with the work done so far

> **Snapshot as of 2026-10-15 (week 2), kept as the record of weeks 1-2.** The
> current status is in [PLAN.md](PLAN.md). Since this snapshot, the build fixes
> listed below as blocked or "fixed in patch 01" were brought into git on
> `student-Mass` through issues #2, #4, #7 and #10, and B03 was analysed in #3
> and #13.

This is the plan from [`docs/xpact-student-introduction.md`](../docs/xpact-student-introduction.md)
("A proposed ten week plan", "Suggested student selection" and the task register),
filled in with everything done up to **2026-10-15 (week 2)**: tests run, bugs
found and fixes made. On 2026-10-15, [PLAN.md](PLAN.md) was the empty version of the same plan.

**Status:** ✅ done · 🟡 partly done · ⬜ not started · 🔴 blocked
Week 1 = 2026-10-05. The build troubleshooting began in September.

## 1. Where things stand

| | |
|---|---|
| Current week | 2 – Baseline |
| Done | Native build working (weeks 1–2), first error report, assertions-enabled baseline, event trace, walkthrough, W3C runner with pinned download |
| Found | 12 open bugs and findings (section 3), including **53 W3C cases that crash xpact with contract violations** (new, 2026-10-15) |
| Blocker | The build fixes are not in `main`, and the branches that held them were deleted. They are saved as patches in [`history/patches/`](history/patches/) |
| Next | Apply the patches, rerun the baseline in this repo (A02), then B01/B02 in week 3 |

## 2. The ten weeks

### Week 1 – Setup ✅
**Guide:** Learn basic XML, the project structure and the Git workflow. Build with help.
**Bring to review:** Setup notes and one successful example parse.

| | Task | Evidence |
|---|---|---|
| ✅ | Build environment found: EiffelStudio 25.12 path, `vcvars64.bat`, PowerShell execution policy | [error report §3](history/xpact-error-report.md) |
| ✅ | Native Eiffel-backed DLL builds: `msc_vc140` backend, mingw-only precompile removed, stale `ec.lock`, stderr guards | [BUILD_FIX_NOTES.txt](history/BUILD_FIX_NOTES.txt), [patch 01](history/patches/01-week1-build-fixes.patch) |
| ✅ | Production DLL build + smoke **ok**; assertions DLL builds (`-SkipSmoke`); Windows package builds | [error report §10](history/xpact-error-report.md) |
| ✅ | Native runtime smoke test fixed (MSVC objects vs mingw link) | [patch 01](history/patches/01-week1-build-fixes.patch) |
| ✅ | AutoTest generated tests: **ok** | error report §5.2 |
| ✅ | First error report (2026-10-13), then the consolidated version | [firstReport.odt](history/firstReport.odt), [xpact-error-report.md](history/xpact-error-report.md) |
| 🟡 | [A01](github/issues/01-A01.md) XML events, Git and the layout; one accepted and one rejected document traced | [walkthrough/trace-output.txt](baseline/walkthrough/trace-output.txt). Still to do: link the checking tests, change-and-predict |

### Week 2 – Baseline 🟡
**Guide:** Follow parser events and run the assertions-enabled tests.
**Bring to review:** A baseline log with revision, configuration, commands and known failures.

| | Task | Evidence |
|---|---|---|
| ✅ | Assertions-enabled baseline: 7 steps, every lane logged | [baseline/BASELINE.md](baseline/BASELINE.md), [baseline/logs/](baseline/logs/) |
| ✅ | Parser events followed for 7 inputs (book, empty root, incomplete, mismatched ×2, bad UTF-8, rich document) | [event-trace-output.txt](baseline/logs/event-trace-output.txt) |
| ✅ | W3C runner downloads the pinned suite ZIP and checks its SHA-256; stderr guard in the test matrix | [patch 02](history/patches/02-week2-runner-changes.patch) |
| ✅ | Python vs PowerShell W3C runner compared: the difference is the verdict rules | [issue 12](github/issues/12-xmlconf-verdicts.md) |
| ✅ | Crash analysis of the xmlconf run (2026-10-15) | [results/xmlconf-crashes-2026-10-14/](results/xmlconf-crashes-2026-10-14/) |
| 🟡 | [A02](github/issues/02-A02.md) Reproduce assertions-enabled builds: done outside git; rerun in this repo after the patches | — |
| 🔴 | [Blocker: build fixes not in `main`](github/issues/22-blocker-build-fixes.md) | ask the supervisor: pull request or local only? |
| ⬜ | **Decision:** choose one main improvement and a small input set with the supervisor | — |

### Week 3 – Failure reporting ⬜
**Guide:** Learn how the test runner reports failure. Reproduce a deliberately failing test.
**Bring to review:** A bounded failure-reporting fix, or a precise proposal with evidence.
- ⬜ [B01](github/issues/09-B01.md) Failing tests must return a nonzero exit status
- ⬜ [B02](github/issues/10-B02.md) Deliberately failing meta-tests
- ⬜ [Finding: the runner stops at the first failure](github/issues/06-finding-runner-stops.md), which belongs with B01
- ⬜ [Finding: the finalized lane drops assertions](github/issues/04-finding-finalized-keep.md). Discuss with the supervisor first.
- ⬜ [Finding: Jenkins precompile prompt](github/issues/23-finding-jenkins-precompile.md)

### Week 4 – Input matrix ⬜
**Guide:** Design small regressions and select 50–100 applicable W3C XML cases with the supervisor.
**Bring to review:** An input matrix with reviewed expected outcomes.
- ⬜ [G01](github/issues/11-G01.md) Corpus manifest and 50–100 reviewed W3C cases. Include one case per crash site from the crash finding.
- ⬜ [Fix the xmlconf verdict rules](github/issues/12-xmlconf-verdicts.md): invalid → accept; skip error, external entities and XML 1.1; **report crashes separately**

### Week 5 – Regressions ⬜
**Guide:** Run the selected small inputs with different callbacks and chunk boundaries.
**Bring to review:** Repeatable regressions and small bug reproductions.
- 🟡 [C02](github/issues/13-C02.md) Malformed final-input cases. Valid, incomplete and mismatched cases are already traced in week 2.
- ⬜ [C03](github/issues/14-C03.md) Chunk boundaries
- 🟡 [C10 (part)](github/issues/15-C10.md) Malformed UTF-8: `C3 28` accepted, seen three times
- ⬜ [Finding: 53 W3C cases crash xpact](github/issues/21-finding-xmlconf-crashes.md): minimize one case per crash site
- ⬜ **Decision:** review with the supervisor what can realistically be completed

### Week 6 – One improvement ⬜
**Guide:** Pair on one manageable test-framework or verification-script improvement.
**Bring to review:** Before-and-after results and a reviewed change.
- ⬜ The improvement chosen in week 2. Candidates: B01/B02, the xmlconf runner (verdicts and crash reporting), or the `-keep` lane fix

### Week 7 – Comparison ⬜
**Guide:** Compare xpact and libexpat; add more applicable W3C cases as time permits.
**Bring to review:** A table of matches, differences and untested cases.
- ⬜ [A04](github/issues/16-A04.md) Verify which library is loaded, including the C# P/Invoke rerun against the Eiffel-backed DLL
- ⬜ [G03](github/issues/17-G03.md) xpact vs Expat across chunks

### Week 8 – Consolidate ⬜
**Guide:** Consolidate the results and add selected SVG or libxml2 cases. Core integration stays optional.
**Bring to review:** Shared fixtures and comparison output, or documented integration requirements.
- ⬜ Shared fixtures and comparison output in `results/`
- ⬜ Optional: [F01](github/issues/19-F01.md) Core build, [F02](github/issues/20-F02.md) Core runner

### Week 9 – Analyse and draft ⬜
**Guide:** Analyse the results and draft the report. Try selected PubMed files if the correctness checks permit.
**Bring to review:** A draft report and result tables tied to specific builds.
- ⬜ [Report draft](github/issues/18-report-handover.md) in [`report/`](report/). The [error report](history/xpact-error-report.md) is a good starting point for the background and method sections.

### Week 10 – Handover ⬜
**Guide:** Demonstrate the work, address review comments and hand it over.
**Bring to review:** Final report, tests, code or proposals, setup guide and follow-up list.
- ⬜ [Report, demonstration and handover](github/issues/18-report-handover.md)
- 🟡 [A06](github/issues/03-A06.md) Records and weekly notes: weeks 1–2 are written up in [`notes/weekly/`](notes/weekly/)

## 3. Bugs and findings

Every problem found so far. "§" refers to sections of [the error report](history/xpact-error-report.md).

### Open

| # | Finding | Evidence | Issue | Week |
|---|---|---|---|---|
| 1 | **53 W3C cases crash xpact with contract violations**; 45 are scored as "pass" | [crash folder](results/xmlconf-crashes-2026-10-14/) | [21](github/issues/21-finding-xmlconf-crashes.md) | 4–5 |
| 2 | Postcondition `final_finished_or_suspended` fails in the GC-suspension test (B03) | baseline K1, §5.1 | [05](github/issues/05-finding-b03-postcondition.md) | 3 |
| 3 | The test runner stops at the first failure, so later tests don't run | baseline K1 | [06](github/issues/06-finding-runner-stops.md) | 3 |
| 4 | The "assertions on / finalized" lane is green because `-keep` is missing | baseline K2 | [04](github/issues/04-finding-finalized-keep.md) | 3 |
| 5 | The assertions DLL smoke test crashes (`0xC0000028`, earlier `0xC0000008`); CI hides it with `-SkipSmoke` | baseline K3, §4.8 | [07](github/issues/07-finding-dll-crash.md) | — |
| 6 | Invalid UTF-8 (`C3 28`) is accepted | baseline K4, §6.1 | [15](github/issues/15-C10.md) | 5 |
| 7 | The xmlconf runner's verdict rules are not comparable with the Python runner | baseline K5, §6.3, §7.1 | [12](github/issues/12-xmlconf-verdicts.md) | 4 |
| 8 | A Python harness test fails on Python 3.10 (csv cannot write NUL) | §7.2, root cause found on 2026-10-15 | [08](github/issues/08-finding-python310.md) | 3 |
| 9 | The build fixes are not in `main` (hard-coded EiffelStudio path, mingw vs MSVC backend, stderr) | §3–4, patches | [22](github/issues/22-blocker-build-fixes.md) | 2 |
| 10 | Jenkins stops at an EiffelStudio precompile prompt | §9.1 | [23](github/issues/23-finding-jenkins-precompile.md) | 3 |
| 11 | The bridge-only DLL returns error 44 "Eiffel parser bridge is not installed"; rerun the C# test on the Eiffel DLL | §4.6 | [16](github/issues/16-A04.md) | 7 |
| 12 | Callbacks for rejected documents still need to be checked | §6.4, event trace | [13](github/issues/13-C02.md) | 5 |

### Resolved or explained

| Finding | Outcome |
|---|---|
| Wrong EiffelStudio include path (`C:\El2502E\…`) | Fixed in patch 01 (§3.1) |
| Missing `.lnk` link response file | Fixed: `msc_vc140` backend (§4.1) |
| mingw-only precompiled base blocks the MSVC build | Fixed: precompile removed from two ECFs (§4.2) |
| Stale `ec.lock` | Removed (§4.3) |
| `vswhere.exe` stderr text aborts scripts | Fixed: stderr guards (§4.4) |
| `finish_freezing`, W_code vs F_code | Explained (§4.5) |
| Duplicate ATTLIST token accepted (`rmt-e2e-2a`) | **Not a bug:** it is an *invalid* case, so a non-validating parser should accept it (§6.2, guide) |

### Parked (not part of the selected tasks)

| Finding | Note |
|---|---|
| `cmd.exe: The input line is too long` | Not seen since the fixes (§4.7) |
| Large-file parsing: 1 MB takes 3.4–3.5 s (workbench) | Measure again on a finalized build before drawing conclusions (§8.1, G06/G09) |
| Metrics handler `REAL_64` / `REAL_32` errors | Change reverted (§8.2) |

## 4. Tests run so far

| Date | Test | Result | Evidence |
|---|---|---|---|
| Sep–Oct | Bridge-only DLL + C# P/Invoke `XML_Parse` | error 44: Eiffel bridge not installed | §4.6 |
| Oct | `build_native_eiffel.ps1` (production) | DLL built, smoke **ok** | §10 |
| Oct | `build_native_eiffel.ps1 -BuildTier Assertions -SkipSmoke` | built | §10 |
| Oct | `package_windows_release.ps1` | zip built | §10 |
| Oct | AutoTest generated tests | **ok** | §5.2 |
| Oct | `xpact.exe --parse-file bad-utf8.xml` | **ok** (should reject) | §6.1 |
| Oct | 1 MB `asd.xml` / 53-byte `test.xml` | 3.4–3.5 s / 6 ms (workbench) | §8.1 |
| 2026-10-14 | Event trace, 7 inputs | as expected, except bad UTF-8 accepted | [BASELINE §4](baseline/BASELINE.md) |
| 2026-10-14 | Test matrix, workbench, assertions on | ❌ B03 postcondition | [matrix-workbench.log](baseline/logs/matrix-workbench.log) |
| 2026-10-14 | Test matrix, finalized (no `-keep`) | "ok", but no assertions | [matrix-finalized.log](baseline/logs/matrix-finalized.log) |
| 2026-10-14 | Test matrix, finalized `-keep` | ❌ B03 postcondition | [matrix-finalized-keep.log](baseline/logs/matrix-finalized-keep.log) |
| 2026-10-14 | Native runtime smoke, assertions on | ✅ ok | [native-runtime-smoke.log](baseline/logs/native-runtime-smoke.log) |
| 2026-10-14 | Assertions DLL with smoke | ❌ crash `0xC0000028` | [assertions-dll.log](baseline/logs/assertions-dll.log) |
| 2026-10-14 | xmlconf, 2,168 cases | 1,314 pass, 854 mismatch, **53 crashes** | [xmlconf-summary.txt](baseline/logs/xmlconf-summary.txt), [crashes](results/xmlconf-crashes-2026-10-14/) |
| 2026-10-15 | Walkthrough `ok.xml` / `rejected.xml` | ACCEPT 7 events / REJECT 1:15 mismatched end tag | [trace-output.txt](baseline/walkthrough/trace-output.txt) |
| 2026-10-15 | Python harness tests, Python 3.10.6 | 21 / 22 (csv NUL) | [issue 08](github/issues/08-finding-python310.md) |
| 2026-10-21 | Python harness tests, Python 3.15.0 | ✅ 22 / 22 | [#29](https://github.com/andersoxie/xpact/issues/29) |
| 2026-10-21 | W3C suite, Python runner, 1,727 applicable cases: `Finalized` (assertions off) / `FinalizedAssertions` (on, `-keep`) | off: 1,491 pass, 236 fail · on: 270 pass, 97 fail, **1,360 crashes** (1,357 = [#28](https://github.com/andersoxie/xpact/issues/28)) | [results](results/w3c-conformance-2026-10-21/README.md) |

## 5. Where everything is

| Folder | Content |
|---|---|
| [`history/`](history/) | Weeks 1–2 before git: error reports, build fix notes, both patches |
| [`baseline/`](baseline/) | Week 2 baseline: script, event-trace program, inputs, walkthrough, logs, BASELINE.md |
| [`results/`](results/) | One folder per issue. So far: `xmlconf-crashes-2026-10-14/` |
| [`notes/weekly/`](notes/weekly/) | Weekly notes: weeks 1 and 2 written |
| [`github/issues/`](github/issues/) | 23 issue drafts (20 planned + 3 from the history) |
| [`report/`](report/) | Weeks 8–10 |
