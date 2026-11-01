# 10-week plan

> **Last updated:** 2026-10-31 (week 7, night) · `student-Mass` @ `32bc80a` · today: [#122](https://github.com/andersoxie/xpact/issues/122), [#124](https://github.com/andersoxie/xpact/issues/124), [#125](https://github.com/andersoxie/xpact/issues/125), [#172](https://github.com/andersoxie/xpact/issues/172), [#173](https://github.com/andersoxie/xpact/issues/173), [#174](https://github.com/andersoxie/xpact/issues/174), [#175](https://github.com/andersoxie/xpact/issues/175) fixed and closed; [#88](https://github.com/andersoxie/xpact/issues/88), [#90](https://github.com/andersoxie/xpact/issues/90), [#93](https://github.com/andersoxie/xpact/issues/93) closed (already done on `main`) · **issues close after a local check on `student-Mass`; no Jenkins run is needed** (student, 2026-10-31) · earlier: the supervisor merged `student-Mass` into `main` ([#177](https://github.com/andersoxie/xpact/pull/177), `733688e`) and the Jenkins run on it passed
> · earlier: 2026-10-28 (week 6) · describes `student-Mass` after PR [#152](https://github.com/andersoxie/xpact/pull/152) (includes `main` @ `1714f31` with the supervisor's [#150](https://github.com/andersoxie/xpact/pull/150)); full W3C report: [latest-2026-10-28](../reports/latest-2026-10-28/README.md); W3C output test and its fixes: [issue-0154](../reports/issue-0154/report.md), [issue-0156](../reports/issue-0156/report.md), [issue-0157](../reports/issue-0157/report.md), [issue-0158](../reports/issue-0158/report.md), [issue-0159](../reports/issue-0159/report.md); W3C in pieces: [issue-0165](../reports/issue-0165/report.md); `main` @ `2488f44` (PR #139, merged by the supervisor 2026-10-29) = `student-Mass` @ `e5d59e2`
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
| 3 Failure reporting | ✅ | Build fixes in git ✅, W3C run ✅, #28 test and repair ✅, repair and GitHub setup ✅ · **B01 ✅, B02 ✅, runner continues after a failure (#60) ✅** (2026-10-22); Jenkins check of B02 dropped (2026-10-22, not pursued) | [week-03](notes/weekly/week-03.md) |
| 4 Input matrix | 🟡 | Started 2026-10-26: full check of the merged code ✅, `main` synced (#110) ✅, PC set up like the supervisor's (#113) ✅, weeks 2-3 closed out ✅ · **G01 ✅** 93 reviewed W3C cases ([#118](https://github.com/andersoxie/xpact/issues/118)) · xmlconf verdicts ✅ ([#117](https://github.com/andersoxie/xpact/issues/117)) | [week-04](notes/weekly/week-04.md) |
| 5 Regressions | ✅ | C02, C03, C10 (part) run through the DLL (3 findings #38-#40, fixed in #80) · **C03 ✅, C10 ✅ compared with Expat 2.8.1** ([#121](https://github.com/andersoxie/xpact/issues/121)): 4,308/4,308 same verdicts, 5 findings (#122-#126) · **C02 ✅ regressions in the smoke test and the Eiffel suite** ([#128](https://github.com/andersoxie/xpact/issues/128)) · review with the supervisor skipped by the student | [expat-2.8.1](results/expat-2.8.1/README.md), [C02-final-input](results/C02-final-input/README.md), [week-05](notes/weekly/week-05.md) |
| 6 One improvement | ✅ | Option A all W3C cases (#146), entity speed (#148), **integrated with `main` (#150)** ([#151](https://github.com/andersoxie/xpact/issues/151), PR #152), dual regression lane ([#153](https://github.com/andersoxie/xpact/issues/153)): **2,585 W3C cases, 0 failed, 0 errors, 0 skipped** (2026-10-28) · XML version recommendation: XML 1.0 5th edition · ✅ Jenkins passed on `main` @ `733688e` (PR #177, 2026-10-31) | [latest-2026-10-28](../reports/latest-2026-10-28/README.md), [issue-0151](../reports/issue-0151/summary.md) |
| 7 Comparison | 🟡 | **G03 ✅** xpact vs Expat across chunks, same verdict in 1,302/1,302 pairs ([#169](https://github.com/andersoxie/xpact/issues/169), PR #178), 7 findings #170-#176 · **A04 ✅** which library each runner loads ([#168](https://github.com/andersoxie/xpact/issues/168), PR #181), findings #179, #180 · W3C output ✅ 399/432 · **follow-up fixes ✅** #122, #124, #125, #172-#175 (2026-10-31) · ⬜ G03 table rerun on the fixed code, weekly notes 6-7 | [G03-comparison](results/G03-comparison/README.md) |
| 8-10 | ⬜ | Consolidate, report, handover | |

## 🧪 Latest W3C result (2026-10-28)

Jenkins Benchmarks stage run locally on the integrated code (PR #152), default 10 s per case, both builds
(assertions off and on). Details: [reports/latest-2026-10-28](../reports/latest-2026-10-28/README.md).

| Group | Tests | How judged | Result |
|---|---:|---|---|
| Normal XML 1.0 tests (5th edition, including external files) | 1,974 | W3C answer | ✅ all pass |
| Old-edition name tests, with the old rules the DLL uses | 309 | W3C answer | ✅ all pass |
| Optional errors | 28 | either answer is allowed | ✅ no crash |
| XML 1.1 | 274 | no XML 1.0 answer exists | ✅ no crash |
| **Total** | **2,585** | | **0 failed, 0 errors, 0 skipped** |

Jenkins would show **2,283 checked plus 302 "no crash only"**. We started at **1,727 passed and 858 skipped per build** (Jenkins #70).

**External files through the DLL** (the way Expat programs load them): **247 of 247** in both builds.
The supervisor's `main` alone still has crashes and timeouts there (1 crash off; 4 crashes + 3 timeouts on).

**Nothing else broke:**
- [x] DLL smoke tests: ok in both builds
- [x] Eiffel test matrix: 4 of 4
- [x] Python: 206 tests OK
- [x] Native tests (runtime smoke, Windows ABI, chunked CRC 7/7, shim audit): all ok
- [x] Same answers as Expat on 4,308 inputs (difference table unchanged)
- [x] Dual regression lane: 910 of 910 (xpact, both builds), lifecycle 10/10
- [x] Jenkins run: passed on `main` @ `733688e` after PR #177 (2026-10-31)

## ✅ Merged since 2026-10-22

| What | Pull request | Issue |
|---|---|---|
| A01 evidence: tests linked, change-and-predict | [#69](https://github.com/andersoxie/xpact/pull/69) | [#68](https://github.com/andersoxie/xpact/issues/68) ✅ closed 2026-10-26 |
| Checklist audit, doc gaps | [#71](https://github.com/andersoxie/xpact/pull/71) | [#70](https://github.com/andersoxie/xpact/issues/70) ✅ closed 2026-10-26 |
| Jenkins Eiffel include fallback `C:\El2502E` restored | [#75](https://github.com/andersoxie/xpact/pull/75) | [#73](https://github.com/andersoxie/xpact/issues/73) ✅ verified on Jenkins |
| Week 3 report | [#77](https://github.com/andersoxie/xpact/pull/77) | - |
| Parser conformance: strict UTF-8, UTF-16, names, DTD declarations; DLL start-tag shortcut and UTF-16 loops | [#80](https://github.com/andersoxie/xpact/pull/80) | [#79](https://github.com/andersoxie/xpact/issues/79) 🟡 Jenkins rerun; fixes [#38](https://github.com/andersoxie/xpact/issues/38), [#39](https://github.com/andersoxie/xpact/issues/39), [#40](https://github.com/andersoxie/xpact/issues/40), K3 |
| `main` brought into `student-Mass` (the supervisor's #82-#100: libexpat lanes, parser handles and chunking #85, faster tag dispatch #87, WSL GCC benchmarks, Jenkins email, Xpact-core next to xpact #94-#98) | [#81](https://github.com/andersoxie/xpact/pull/81), [#103](https://github.com/andersoxie/xpact/pull/103) | [#102](https://github.com/andersoxie/xpact/issues/102) ✅ |
| The supervisor merged `student-Mass` into `main` | #72, #78 (by the supervisor) | - |
| Full check of `student-Mass` after the sync: every build and test passes with assertions on | [#105](https://github.com/andersoxie/xpact/pull/105) | [#104](https://github.com/andersoxie/xpact/issues/104) ✅ |
| Weeks 2-3: K3 and the W3C crashes ticked as fixed, #46 as dropped | [#107](https://github.com/andersoxie/xpact/pull/107) | [#106](https://github.com/andersoxie/xpact/issues/106) ✅ |
| The 6 missing labels created (#35); project board brought up to date | [#109](https://github.com/andersoxie/xpact/pull/109) | [#108](https://github.com/andersoxie/xpact/issues/108) ✅ |
| `main` brought into `student-Mass` again (the supervisor's #101, parser performance); tests on the merged code | [#111](https://github.com/andersoxie/xpact/pull/111) (merge commit), [#112](https://github.com/andersoxie/xpact/pull/112) | [#110](https://github.com/andersoxie/xpact/issues/110) ✅ |
| Student PC: MSVC backend, Python 3.14, git and Windows long paths; all 178 Python tests pass | [#114](https://github.com/andersoxie/xpact/pull/114) | [#113](https://github.com/andersoxie/xpact/issues/113) ✅ |
| Student docs up to date (2026-10-26) | [#116](https://github.com/andersoxie/xpact/pull/116) | [#115](https://github.com/andersoxie/xpact/issues/115) ✅ |
| xmlconf verdict rules: 2026-10-14 results re-scored | [#119](https://github.com/andersoxie/xpact/pull/119) | [#117](https://github.com/andersoxie/xpact/issues/117) ✅ |
| G01: corpus manifest, 93 reviewed W3C cases | [#120](https://github.com/andersoxie/xpact/pull/120) | [#118](https://github.com/andersoxie/xpact/issues/118) ✅ |
| C03/C10 compared with Expat 2.8.1; findings #122-#126 | [#127](https://github.com/andersoxie/xpact/pull/127) | [#121](https://github.com/andersoxie/xpact/issues/121) ✅ |
| C02 regression tests for #38, #39, #40 | [#129](https://github.com/andersoxie/xpact/pull/129) | [#128](https://github.com/andersoxie/xpact/issues/128) ✅ |
| Old runner copy `tests/python/run_w3c_conformance.py` removed | [#133](https://github.com/andersoxie/xpact/pull/133) | [#132](https://github.com/andersoxie/xpact/issues/132) ✅ |
| Student docs after week 5 | [#135](https://github.com/andersoxie/xpact/pull/135) | [#134](https://github.com/andersoxie/xpact/issues/134) ✅ |
| #73 verified on Jenkins (log of `cf12dee`), closed | [#136](https://github.com/andersoxie/xpact/pull/136) | [#73](https://github.com/andersoxie/xpact/issues/73) ✅ |
| `-SkipSmoke` removed: assertions DLL smoke back on in both Jenkinsfiles and the release script | [#144](https://github.com/andersoxie/xpact/pull/144) | [#142](https://github.com/andersoxie/xpact/issues/142) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| 7 skipped native Python tests now run (CMake bundled with Visual Studio found); 178 run, 0 skipped | the pull request | [#143](https://github.com/andersoxie/xpact/issues/143) |
| **Option A**: all 2,585 W3C cases run (`--all-cases`, 0 skipped); parser fixes F1-F7 | [#147](https://github.com/andersoxie/xpact/pull/147) closed, superseded by #152 | [#146](https://github.com/andersoxie/xpact/issues/146) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| Internal entity references fast again (position bookkeeping); the XML spec 16 s -> 0.2 s with assertions | [#149](https://github.com/andersoxie/xpact/pull/149) closed, superseded by #152 | [#148](https://github.com/andersoxie/xpact/issues/148) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| Dual regression lane: 61 inputs whole and chunked on xpact and Xpact-core, lifecycle; 910/910 | [#152](https://github.com/andersoxie/xpact/pull/152) | [#153](https://github.com/andersoxie/xpact/issues/153) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| **#146 + #148 integrated with `main` (#150)**: answers the supervisor's 2026-10-27 requests (reproduce and fix failures, more XML 1.0 cases, XML version); all 2,585 W3C cases pass, DLL 247/247 ([summary](../reports/issue-0151/summary.md)) | the pull request | [#151](https://github.com/andersoxie/xpact/issues/151) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| **W3C output test** (432 cases with an expected output file) and the fix it led to: attribute defaults across external files; 359 -> 393 right, 0 worse, all old lanes unchanged ([report](../reports/issue-0154/report.md)) | [#160](https://github.com/andersoxie/xpact/pull/160) (`7028e68`) | [#154](https://github.com/andersoxie/xpact/issues/154), [#155](https://github.com/andersoxie/xpact/issues/155) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| Declared defaults of tokenized attributes normalized (`valid-sa-096`); W3C output 393 -> 394, 0 worse ([report](../reports/issue-0156/report.md)) | [#161](https://github.com/andersoxie/xpact/pull/161) (`d0a4e21`) | [#156](https://github.com/andersoxie/xpact/issues/156) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| Public identifiers normalized everywhere (DOCTYPE, NOTATION, ENTITY), as Expat; W3C output 394 -> 395, 0 worse ([report](../reports/issue-0157/report.md)) | [#162](https://github.com/andersoxie/xpact/pull/162) (`133ae01`) | [#157](https://github.com/andersoxie/xpact/issues/157) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| A second byte order mark after UTF-16 decoding is kept (it was removed twice; two-BOM UTF-16 documents were also accepted); W3C output 395 -> 398, 0 worse ([report](../reports/issue-0158/report.md)) | [#163](https://github.com/andersoxie/xpact/pull/163) (`82c82b5`) | [#158](https://github.com/andersoxie/xpact/issues/158) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| An external parameter entity included in an entity literal: its text goes into the value, its declarations are no longer used; W3C output 398 -> 399, 0 worse, Expat's C tests unchanged ([report](../reports/issue-0159/report.md)) | [#164](https://github.com/andersoxie/xpact/pull/164) (`e5d59e2`) | [#159](https://github.com/andersoxie/xpact/issues/159) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| Callbacks no longer delivered twice when the input arrives in pieces; W3C in pieces 1,995 -> 2,438 of 2,585 stable, 0 worse ([report](../reports/issue-0165/report.md)) | [#166](https://github.com/andersoxie/xpact/pull/166) (`f985102`, merged by the supervisor) | [#165](https://github.com/andersoxie/xpact/issues/165) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| Keep the machine's MSVC backend in the native build scripts; retested 2026-10-26 | [#76](https://github.com/andersoxie/xpact/pull/76) (`7cf5a94`) | [#74](https://github.com/andersoxie/xpact/issues/74) ✅ closed 2026-10-31 (Jenkins on PR #177) |
| Merged branches deleted (11 on GitHub, 20 local), PR #76 finished | [#138](https://github.com/andersoxie/xpact/pull/138) | [#137](https://github.com/andersoxie/xpact/issues/137) ✅ |
| Script for the supervisor: collects the information for the open dual-implementation steps and #74/#79 | (the pull request) | [#140](https://github.com/andersoxie/xpact/issues/140) |
| The supervisor merged `student-Mass` into `main` (weeks 4-6) | [#139](https://github.com/andersoxie/xpact/pull/139) (`2488f44`, 2026-10-29) | - |
| **G03**: xpact vs Expat 2.8.1 across 14 ways of feeding the 93 G01 cases; same verdict in all 1,302 pairs; findings #170-#176 | [#178](https://github.com/andersoxie/xpact/pull/178) (`9fc6f85`) | [#169](https://github.com/andersoxie/xpact/issues/169) ✅ closed 2026-10-31 |
| **A04**: which library each of the 16 runners loads (SHA-256 per DLL); findings #179, #180 | [#181](https://github.com/andersoxie/xpact/pull/181) (`3032770`) | [#168](https://github.com/andersoxie/xpact/issues/168) ✅ closed 2026-10-31 |
| The supervisor merged `student-Mass` into `main` again; **Jenkins passed** | [#177](https://github.com/andersoxie/xpact/pull/177) (`733688e`, 2026-10-31) | #74, #79, #142, #146, #148, #151, #153-#159, #165 ✅ closed |
| #179: Expat's C tests use the Eiffel-backed library by default; plan row | [#182](https://github.com/andersoxie/xpact/pull/182) (`8ee95b8`), [#185](https://github.com/andersoxie/xpact/pull/185) | [#179](https://github.com/andersoxie/xpact/issues/179) ✅ closed |
| Plan and reports after the Jenkins approval of #177 | [#184](https://github.com/andersoxie/xpact/pull/184) (`f5c7f6c`) | [#183](https://github.com/andersoxie/xpact/issues/183) ✅ closed |
| #180: `run_benchmarks.ps1 -Repetitions 1`; plan row | [#186](https://github.com/andersoxie/xpact/pull/186) (`647b99c`), [#187](https://github.com/andersoxie/xpact/pull/187) | [#180](https://github.com/andersoxie/xpact/issues/180) ✅ closed |
| `main` (supervisor's PR #167) brought into `student-Mass`, merge commit | [#189](https://github.com/andersoxie/xpact/pull/189) (`48f8c6f`) | [#188](https://github.com/andersoxie/xpact/issues/188) ✅ closed |
| #179 and #180 moved to Solved | [#190](https://github.com/andersoxie/xpact/pull/190) (`5af2321`) | - |
| #172: events in front of a forbidden character in a whole document (squash title "Record the #172 baseline…"; contains the fix) | [#192](https://github.com/andersoxie/xpact/pull/192) (`b069ffb`) | [#172](https://github.com/andersoxie/xpact/issues/172) ✅ closed |
| #175: an empty system literal passed as `""` | [#194](https://github.com/andersoxie/xpact/pull/194) (`38aa67a`) | [#175](https://github.com/andersoxie/xpact/issues/175) ✅ closed |
| #174: `#FIXED` reported with `isrequired = 1` | [#195](https://github.com/andersoxie/xpact/pull/195) (`2ed37c5`) | [#174](https://github.com/andersoxie/xpact/issues/174) ✅ closed |
| #173: subset declarations before a stray `]` error | [#196](https://github.com/andersoxie/xpact/pull/196) (`391df71`) | [#173](https://github.com/andersoxie/xpact/issues/173) ✅ closed |
| #124: text after the document element is code 9 | [#198](https://github.com/andersoxie/xpact/pull/198) (`b7b6f69`) | [#124](https://github.com/andersoxie/xpact/issues/124) ✅ closed |
| #125: a mismatched end tag kept from the default handler | [#199](https://github.com/andersoxie/xpact/pull/199) (`32bc80a`) | [#125](https://github.com/andersoxie/xpact/issues/125) ✅ closed |
| #88, #90, #93 (WSL defaults, email, Xpact-core pin): already done by the supervisor on `main` (#89, #91/#92, #94-#98) | checked against the code | [#88](https://github.com/andersoxie/xpact/issues/88), [#90](https://github.com/andersoxie/xpact/issues/90), [#93](https://github.com/andersoxie/xpact/issues/93) ✅ closed |

No pull request of ours is open (2026-10-31, evening). `student-Mass` includes all of `main` (PR [#189](https://github.com/andersoxie/xpact/pull/189)). Branches left on andersoxie/xpact: `main`, `student-Mass`, `fix/172-whole-document-events-before-char-error` (merged in #192), and the supervisor's `codex/*`.

<details>
<summary>Merged on 2026-10-22</summary>

Four stacked pull requests, merged in order at the student's request:

| # | Pull request | Commit | Issue |
|---|---|---|---|
| 1 | [#36](https://github.com/andersoxie/xpact/pull/36) Repair the repository state left on 2026-10-21 | `6e2278e` | [#34](https://github.com/andersoxie/xpact/issues/34) ✅ closed |
| 2 | [#41](https://github.com/andersoxie/xpact/pull/41) C# test program for the xpact DLL | `79f2a29` | [#37](https://github.com/andersoxie/xpact/issues/37) ✅ closed |
| 3 | [#42](https://github.com/andersoxie/xpact/pull/42) Record the GitHub labels and week milestones | `c01f743` | [#35](https://github.com/andersoxie/xpact/issues/35) ✅ closed |
| 4 | [#44](https://github.com/andersoxie/xpact/pull/44) These doc updates | this one | [#43](https://github.com/andersoxie/xpact/issues/43) ✅ closed |

</details>

After a pull request is merged: check the result, then close its issue
by hand with "Fixed in `<sha>` (PR #N)" (merging into `student-Mass` does not close it).

## 🔴 Known problems (living list)

Every open problem, with its status. **Cause:** ✔ confirmed · ❓ suspected · ❔ unknown.
Update a row when its status changes; move it to "Solved" below, never delete it.

| Problem | Seen in | Cause | Issue | Next step |
|---|---|---|---|---|
| GC-suspended parses swallow exceptions | B03 analysis; crashes without a trace | ✔ (swallowing) · ❓ (lost traces) | [#13](https://github.com/andersoxie/xpact/issues/13) | ⏸ **on hold** (student, 2026-10-22); parser developer |
| Jenkins "Eiffel Tests" turns green without printing a test result | [#73 log](../reports/issue-0073/jenkins-log-2026-10-23.txt); stage unchanged on 2026-10-26 | ✔ on the student PC (stale exe) · ❔ on Jenkins | [#130](https://github.com/andersoxie/xpact/issues/130) | supervisor's pipeline |
| SonarQube `HTTP 401` on Jenkins | [#73 log](../reports/issue-0073/jenkins-log-2026-10-23.txt) | ❓ suspected: server token | [#131](https://github.com/andersoxie/xpact/issues/131) | supervisor renews the token |
| Malformed UTF-8: no events before the error | Expat comparison | ✔ same check as #122 (confirmed in #172) | [#123](https://github.com/andersoxie/xpact/issues/123) | 🟡 598 → 133 cases with the #172 fix; left: CDATA with the default handler (Expat delivers `<![CDATA[` first); planned together with #176 |
| Default handler gets LF instead of the raw CR | Expat comparison | ❓ suspected: fed from the normalized input | [#126](https://github.com/andersoxie/xpact/issues/126) | investigate |
| Error code differs from Expat on 14 W3C cases (verdict right) | G03 comparison, 2026-10-31 | ❔ unknown, probably several code paths | [#170](https://github.com/andersoxie/xpact/issues/170) | investigate |
| Error column 0 (start of the line) where Expat points at the token: 22 of 32 rejections | G03 comparison, 2026-10-31 | ❓ suspected: position taken from the line or token group | [#171](https://github.com/andersoxie/xpact/issues/171) | investigate (with #122) |
| In pieces, `]]` of a forbidden `]]>` delivered as text before the error | G03 comparison, 2026-10-31 | ❓ suspected: text flushed at a chunk boundary | [#176](https://github.com/andersoxie/xpact/issues/176) | investigate |

**Workarounds in use (not fixes):** `fix.ps1` stops in Windows PowerShell 5.1,
so its steps are done by hand ([VERSIONING.md](VERSIONING.md#fixps1-in-windows-powershell-51)).
(`vcvars64.bat` needing the Visual Studio Installer folder on `PATH` is fixed in [#51](https://github.com/andersoxie/xpact/issues/51).)

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
| Finalized test lane had no `-keep`, so assertions were off (K2) | `ccd30ab` | [#48](https://github.com/andersoxie/xpact/issues/48) |
| `vcvars64.bat` needed the Visual Studio Installer folder on `PATH` | `3076a92` | [#51](https://github.com/andersoxie/xpact/issues/51) |
| Workbench lane did not load MSVC, `finish_freezing` failed with `msc_vc140` | `ec3c3e6` | [#53](https://github.com/andersoxie/xpact/issues/53) |
| CR in the input: `normalized_input` loop variant failed (assertions on); W3C crashes 1,360 to 47 | PR [#59](https://github.com/andersoxie/xpact/pull/59) | [#28](https://github.com/andersoxie/xpact/issues/28) |
| The test program stopped at the first contract failure; later tests did not run | PR [#61](https://github.com/andersoxie/xpact/pull/61) | [#60](https://github.com/andersoxie/xpact/issues/60) (draft 06) |
| Failing tests exited 0 with assertions off (`check` only), so the matrix and native smoke said ok | PR [#62](https://github.com/andersoxie/xpact/pull/62) | [#45](https://github.com/andersoxie/xpact/issues/45) (B01) |
| No way to check that a failure still reaches the exit status (B02) | PR [#63](https://github.com/andersoxie/xpact/pull/63) | [#46](https://github.com/andersoxie/xpact/issues/46) |
| Test matrix started outside the repository root ran a stale `xpact_tests.exe` and reported ok | PR [#58](https://github.com/andersoxie/xpact/pull/58) | [#55](https://github.com/andersoxie/xpact/issues/55) |
| Jenkins precompile prompt: **dropped** 2026-10-22, the student decided not to pursue it | - | [draft 23](github/issues/23-finding-jenkins-precompile.md), [#56](https://github.com/andersoxie/xpact/issues/56) |
| B03: `direct_start_tag_attributes` loop variant at `/>` | PR [#12](https://github.com/andersoxie/xpact/pull/12); verified 2026-10-26 ([check](../reports/issue-0104/report.md)) | [#3](https://github.com/andersoxie/xpact/issues/3) |
| Start handler: rest of the document not parsed (C01) | PR [#80](https://github.com/andersoxie/xpact/pull/80) | [#38](https://github.com/andersoxie/xpact/issues/38) |
| Invalid UTF-8 accepted in all six places (K4) | PR [#80](https://github.com/andersoxie/xpact/pull/80); verified 2026-10-26: 2,658 UTF-8 DLL cases pass ([check](../reports/issue-0104/report.md)) | [#39](https://github.com/andersoxie/xpact/issues/39) |
| Non-final chunk ending with `<` crashed the assertions DLL | PR [#80](https://github.com/andersoxie/xpact/pull/80); verified 2026-10-26: 0 crashes (was 644) ([check](../reports/issue-0104/report.md)) | [#40](https://github.com/andersoxie/xpact/issues/40) |
| Assertions DLL smoke test crashed `0xC0000028` (K3) | PR [#80](https://github.com/andersoxie/xpact/pull/80); smoke ok 2026-10-26; `-SkipSmoke` removed from CI and the release script in [#142](https://github.com/andersoxie/xpact/issues/142); Jenkins passed on `733688e` (2026-10-31) | [#79](https://github.com/andersoxie/xpact/issues/79), draft 07 |
| W3C, assertions on: 47 cases crashed in DTD declaration parsing | PR [#80](https://github.com/andersoxie/xpact/pull/80); W3C 1,727/1,727 on 2026-10-26 | [#79](https://github.com/andersoxie/xpact/issues/79), draft 21 |
| W3C, assertions off: 220 malformed accepted, 16 well-formed rejected | PR [#80](https://github.com/andersoxie/xpact/pull/80); W3C 1,727/1,727 on 2026-10-26 | [#79](https://github.com/andersoxie/xpact/issues/79), [#29](https://github.com/andersoxie/xpact/issues/29) |
| Build fixes were on `student-Mass`, not `main` | the supervisor merged `student-Mass` into `main` (#72, #78) | draft 22 |
| Python tests failed with Python 3.10 (`hashlib.file_digest` is 3.11+) | Python 3.14.0 installed and made the default; setup guide says 3.11+ ([report](../reports/issue-0113/report.md)) | [#113](https://github.com/andersoxie/xpact/issues/113) |
| `test_implementation_builds.py`: 15 problems from paths over 260 characters | Windows `LongPathsEnabled = 1` and git `core.longpaths true`; all 178 Python tests pass ([report](../reports/issue-0113/report.md)) | [#113](https://github.com/andersoxie/xpact/issues/113) |
| Test matrix and W3C built with MinGW gcc because `ISE_C_COMPILER` had disappeared | `ISE_C_COMPILER=msc_vc140` set again; matrix 4/4 and W3C 1,727/1,727 with MSVC ([report](../reports/issue-0113/report.md)) | [#113](https://github.com/andersoxie/xpact/issues/113) |
| `tests/python/run_w3c_conformance.py`: an old copy of the runner (361 vs 459 lines), used by nothing | Removed; Python tests 178 OK before and after ([report](../reports/issue-0132/report.md)) | [#132](https://github.com/andersoxie/xpact/issues/132) |
| **Jenkins** DLL build: `Cannot find Eiffel runtime include directory` (2026-10-23) | Fixed in #75 (`63f67f3`), in `main` since `cf12dee` (#78). **Verified on Jenkins**: the run on `main` @ `cf12dee` found `C:\El2502E` and built both DLLs, `xpact Eiffel DLL smoke: ok` ([log](../reports/issue-0079/jenkins-log-cf12dee-before.txt), lines 135-292); found 2026-10-26 | [#73](https://github.com/andersoxie/xpact/issues/73) |
| Native build scripts always force `ISE_C_COMPILER=msc_vc140`, overriding a machine's own MSVC backend | PR [#76](https://github.com/andersoxie/xpact/pull/76) (`7cf5a94`); Jenkins passed on `733688e` (PR #177) | [#74](https://github.com/andersoxie/xpact/issues/74) |
| W3C output: the declared default of a tokenized attribute (`NMTOKENS` …) is not normalized (`valid-sa-096`); 3 other cases fixed with #154 | PR [#161](https://github.com/andersoxie/xpact/pull/161) (`d0a4e21`); Jenkins passed on `733688e` | [#156](https://github.com/andersoxie/xpact/issues/156) |
| W3C output: a notation's public ID is not normalized (`notation01`); in fact no public ID was | PR [#162](https://github.com/andersoxie/xpact/pull/162) (`133ae01`); Jenkins passed on `733688e` | [#157](https://github.com/andersoxie/xpact/issues/157) |
| W3C output: a second byte order mark at the start of an external entity is dropped (3 cases); two-BOM UTF-16 documents were also accepted | PR [#163](https://github.com/andersoxie/xpact/pull/163) (`82c82b5`); Jenkins passed on `733688e` | [#158](https://github.com/andersoxie/xpact/issues/158) |
| W3C output: an external parameter entity inside an entity value is parsed as declarations (`valid-not-sa-031`) | PR [#164](https://github.com/andersoxie/xpact/pull/164) (`e5d59e2`); Jenkins passed on `733688e` | [#159](https://github.com/andersoxie/xpact/issues/159) |
| W3C in pieces: DTD callbacks (`startdoctype`, `entitydecl`) delivered twice when the input arrives in several calls (481 documents) | PR [#166](https://github.com/andersoxie/xpact/pull/166) (`f985102`); Jenkins passed on `733688e` | [#165](https://github.com/andersoxie/xpact/issues/165) |
| Expat's C tests without `-XpactLibrary` linked the bridge-only `build\native\xpact.lib` (error 44 on every parse) | PR [#182](https://github.com/andersoxie/xpact/pull/182) (`8ee95b8`); verified locally 2026-10-31: 399 checks / 38 expected failures, 208 of 208 test processes load the Eiffel DLL ([report](../reports/issue-0179/report.md)); no Jenkins run needed (student, 2026-10-31) | [#179](https://github.com/andersoxie/xpact/issues/179) |
| `run_benchmarks.ps1 -Repetitions 1` stopped in `AddRange` | PR [#186](https://github.com/andersoxie/xpact/pull/186) (`647b99c`); verified locally 2026-10-31: `-Repetitions 1` and `3` exit 0, W3C 2585 / 2585 for both builds ([report](../reports/issue-0180/report.md)); no Jenkins run needed (student, 2026-10-31) | [#180](https://github.com/andersoxie/xpact/issues/180) |
| A whole document gave no events before a forbidden character (in pieces it did, as Expat; 139 W3C documents, F02-2) | PR [#192](https://github.com/andersoxie/xpact/pull/192) (`b069ffb`); verified locally 2026-10-31: W3C in pieces 2,438 → 2,561 stable, 0 worse; C# vs Expat 1,079 → 3,423 identical, 0 worse ([report](../reports/issue-0172/report.md)) | [#172](https://github.com/andersoxie/xpact/issues/172) |
| Malformed UTF-8 reported at 1:0, not at the bad byte | fixed by the #172 change ([#192](https://github.com/andersoxie/xpact/pull/192), `b069ffb`); all 3,096 C# cases at Expat's position | [#122](https://github.com/andersoxie/xpact/issues/122) |
| `SYSTEM ''` passed as NULL (entities and DOCTYPE) | [#194](https://github.com/andersoxie/xpact/pull/194) (`38aa67a`); probe 7/7 = Expat ([report](../reports/issue-0175/report.md)) | [#175](https://github.com/andersoxie/xpact/issues/175) |
| `#FIXED` default reported with `isrequired = 0` | [#195](https://github.com/andersoxie/xpact/pull/195) (`2ed37c5`); probe 5/5 = Expat ([report](../reports/issue-0174/report.md)) | [#174](https://github.com/andersoxie/xpact/issues/174) |
| Error in the internal subset reported at the DOCTYPE line, before the declarations in front of it | [#196](https://github.com/andersoxie/xpact/pull/196) (`391df71`); probe 10/10 = Expat ([report](../reports/issue-0173/report.md)) | [#173](https://github.com/andersoxie/xpact/issues/173) |
| `<root/>junk`: error 4, not 9; position moved with callbacks | [#198](https://github.com/andersoxie/xpact/pull/198) (`b7b6f69`); C# error codes 4,308/4,308 = Expat ([report](../reports/issue-0124/report.md)) | [#124](https://github.com/andersoxie/xpact/issues/124) |
| Default handler got a mismatched end tag before the error | [#199](https://github.com/andersoxie/xpact/pull/199) (`32bc80a`); probe 16/16, the 21 C# cases fixed ([report](../reports/issue-0125/report.md)) | [#125](https://github.com/andersoxie/xpact/issues/125) |

</details>

## ➡️ Next

1. ✅ **Done 2026-10-26:** full check ([#104](https://github.com/andersoxie/xpact/issues/104)), weeks 2-3 closed out ([#106](https://github.com/andersoxie/xpact/issues/106), [#108](https://github.com/andersoxie/xpact/issues/108)), `main` synced ([#110](https://github.com/andersoxie/xpact/issues/110)), PC set up like the supervisor's ([#113](https://github.com/andersoxie/xpact/issues/113)). Every build and test passes with assertions on, with MSVC.
2. 🟡 **Waiting for the supervisor:** ~~a Jenkins run for [#74](https://github.com/andersoxie/xpact/issues/74) (PR #76 merged 2026-10-26) and [#79](https://github.com/andersoxie/xpact/issues/79)~~ ✅ passed 2026-10-31 (PR #177); still open: the week 2 decision (main improvement and input set); the questions in [`for superviser.txt`](for%20superviser.txt).
3. ✅ **Week 4, G01** ([#118](https://github.com/andersoxie/xpact/issues/118)): 93 W3C cases in [`results/G01-corpus/`](results/G01-corpus/README.md); the xmlconf verdict rules done too ([#117](https://github.com/andersoxie/xpact/issues/117)).
4. ✅ **W3C skips (2026-10-28):** none left. All 2,585 cases run: 2,283 checked + 302 "no crash only", 0 failed, 0 errors ([#151](https://github.com/andersoxie/xpact/issues/151), PR #152). ✅ Jenkins passed on `main` @ `733688e` (PR #177); #142, #146, #148, #151 and #153 closed 2026-10-31.
5. ✅ **Week 5 done 2026-10-26:** C03/C10 compared with Expat 2.8.1 ([#121](https://github.com/andersoxie/xpact/issues/121)); C02 regressions ([#128](https://github.com/andersoxie/xpact/issues/128)). Open from it: findings [#122](https://github.com/andersoxie/xpact/issues/122)-[#126](https://github.com/andersoxie/xpact/issues/126) (parser work).
6. ✅ Every known problem has an issue now (2026-10-26): Jenkins "Eiffel Tests" without output [#130](https://github.com/andersoxie/xpact/issues/130), SonarQube 401 [#131](https://github.com/andersoxie/xpact/issues/131) (both need the supervisor); the old runner copy removed ([#132](https://github.com/andersoxie/xpact/issues/132)).
7. 🟡 **Supervisor's dual-implementation plan** (`newUpdates.txt`): steps 1-2 and the catalog and W3C lanes are done on `main`. For steps 3-9, Jenkins, #74 and #79, the supervisor can run `student\tools\collect-supervisor-info.ps1` ([#140](https://github.com/andersoxie/xpact/issues/140)) and send back the `.txt`.
8. ✅ **W3C output test (2026-10-28):** the content, not only the verdict, of the 432 W3C cases that have an expected output file. 359 right at first; the fix for [#154](https://github.com/andersoxie/xpact/issues/154)/[#155](https://github.com/andersoxie/xpact/issues/155) brings it to **393** (PR #160), [#156](https://github.com/andersoxie/xpact/issues/156) to **394** (PR #161) [#157](https://github.com/andersoxie/xpact/issues/157) to **395** (PR #162) [#158](https://github.com/andersoxie/xpact/issues/158) to **398** (PR #163) and [#159](https://github.com/andersoxie/xpact/issues/159) to **399**, 0 worse ([#154](../reports/issue-0154/report.md), [#156](../reports/issue-0156/report.md), [#157](../reports/issue-0157/report.md), [#158](../reports/issue-0158/report.md), [#159](../reports/issue-0159/report.md) reports). **Every xpact-only difference of this test is fixed**; left: 29 XML 1.1 files and 4 optional errors. ✅ Jenkins passed (PR #177); #154-#159 closed 2026-10-31.
9. ⏸ Still on hold: [#13](https://github.com/andersoxie/xpact/issues/13) (GC wrapper swallows exceptions). A04 done 2026-10-31 ([#168](https://github.com/andersoxie/xpact/issues/168)): every report now records the DLL path and SHA-256.
10. ✅ **Done 2026-10-31:** `main` (supervisor's PR #167) brought into `student-Mass` ([#188](https://github.com/andersoxie/xpact/issues/188), PR #189, `48f8c6f`); [#179](https://github.com/andersoxie/xpact/issues/179) and [#180](https://github.com/andersoxie/xpact/issues/180) fixed, verified and closed (PR #182, #186); their merged branches deleted.
11. 🟡 **G03 and C03/C10 findings (2026-10-31):** ✅ fixed and closed: [#122](https://github.com/andersoxie/xpact/issues/122), [#124](https://github.com/andersoxie/xpact/issues/124), [#125](https://github.com/andersoxie/xpact/issues/125), [#172](https://github.com/andersoxie/xpact/issues/172), [#173](https://github.com/andersoxie/xpact/issues/173), [#174](https://github.com/andersoxie/xpact/issues/174), [#175](https://github.com/andersoxie/xpact/issues/175). Each fix was checked on both builds against Expat 2.8.1 (probe, G03, C# DLL tests, W3C verdicts and output test, Expat's C tests, Eiffel matrix, Python suite); reports under `reports/issue-NNNN/`.
12. ⬜ **Left to do (saved 2026-10-31, paused by the student):**
    - [ ] [#197](https://github.com/andersoxie/xpact/issues/197) test 2 on several cores: `--jobs N` written on branch `fix/197-parallel-test2` (WIP), not verified yet
    - [ ] one W3C benchmark stage on `student-Mass` for the fixes since #172 (agreed: once per batch, both builds)
    - [ ] [#176](https://github.com/andersoxie/xpact/issues/176) `]]>` in pieces and the rest of [#123](https://github.com/andersoxie/xpact/issues/123) (133 CDATA cases), together
    - [ ] [#170](https://github.com/andersoxie/xpact/issues/170) error codes (14 W3C cases), then [#126](https://github.com/andersoxie/xpact/issues/126) raw CR to the default handler (large: about 41 call sites)
    - [ ] [#171](https://github.com/andersoxie/xpact/issues/171) error columns and [#13](https://github.com/andersoxie/xpact/issues/13) GC exceptions: ask the supervisor first (large or design questions)
    - [ ] ask the supervisor about F05-1: the DLL still re-parses markup on every call (8 KB byte by byte: 58 s, Expat 5 ms); `XP_INCREMENTAL_PARSE_SESSION` is a prototype the DLL does not use
    - [ ] delete the merged branches `fix/124-…`, `fix/125-…`, `fix/173-…`, `fix/174-…`, `fix/175-…` (needs the student's OK)

<details>
<summary>The five tests chosen on 2026-10-21 and where they stand</summary>

From [`notes/next-tests-2026-10-21.txt`](notes/next-tests-2026-10-21.txt):

| | Test | State |
|---|---|---|
| ✅ | 1. CR regression (#28) | Test in `1ea242e`; parser repaired in PR [#59](https://github.com/andersoxie/xpact/pull/59), the test passes |
| ✅ | 2. B02 deliberately failing meta-test | [#46](https://github.com/andersoxie/xpact/issues/46), `XPACT_META_FAIL` |
| ✅ | 3. C02 through the DLL | [#37](https://github.com/andersoxie/xpact/issues/37), found #38 |
| ✅ | 4. C03 every split position | run in #37 (found #40); compared with Expat 2.8.1 in [#121](https://github.com/andersoxie/xpact/issues/121) |
| ✅ | 5. C10 (part) malformed UTF-8 | run in #37, found #39 |

</details>


## Week 1 – Setup
**Activity:** Learn basic XML, the project structure and the Git workflow. Build with help.
**Bring to review:** Setup notes and one successful example parse.
- [x] Native build working (done outside git in weeks 1-2, see [PLAN2.md](PLAN2.md) week 1; brought into git in week 3, see [Build fixes in git](#build-fixes-and-workflow-in-git-week-3))
- [x] First error report ([history/](history/)) and setup notes ([week-01.md](notes/weekly/week-01.md))
- [x] [A01](github/issues/01-A01.md) Learn XML events, contracts, Git and the layout; trace one accepted and one rejected document. Done 2026-10-20 ([#18](https://github.com/andersoxie/xpact/issues/18)). Traces: [walkthrough/trace-output.txt](baseline/walkthrough/trace-output.txt). Checking tests linked and change-and-predict done 2026-10-22 ([#68](https://github.com/andersoxie/xpact/issues/68)): [results/A01-orientation/](results/A01-orientation/README.md), 2 of 3 predictions right

## Week 2 – Baseline
**Activity:** Follow parser events and run the assertions-enabled tests.
**Bring to review:** A baseline log with revision, configuration, commands and known failures.
- [x] Assertions-enabled baseline with every lane logged: [baseline/BASELINE.md](baseline/BASELINE.md)
- [x] [A02](github/issues/02-A02.md) Reproduce assertions-enabled workbench and finalized builds: rerun in the git clone on 2026-10-22 at `1799b35`, every step as expected ([#33](https://github.com/andersoxie/xpact/issues/33), [A02-baseline](results/A02-baseline/README.md), [setup guide](report/setup-guide.md))
- [x] Report the baseline findings (each one's state is in [Known problems](#-known-problems-living-list)); all resolved or filed, last two closed 2026-10-26 ([#106](https://github.com/andersoxie/xpact/issues/106)):
  - [x] [Finalized lane drops assertions (missing `-keep`)](github/issues/04-finding-finalized-keep.md): filed as [#48](https://github.com/andersoxie/xpact/issues/48), fixed in [reports/issue-0048](../reports/issue-0048/report.md)
  - [x] Postcondition `final_finished_or_suspended` fails (B03): [#3](https://github.com/andersoxie/xpact/issues/3). Fixed in [#12](https://github.com/andersoxie/xpact/pull/12) (merged by the supervisor); verified 2026-10-26 in [#104](https://github.com/andersoxie/xpact/issues/104). *2026-10-22:* also the cause of every `/>` crash through the DLL (confirmed with a B03-fixed build, #37)
  - [x] New, found while analysing B03: `XP_GC_CRITICAL_SECTION.execute` swallows exceptions: [#13](https://github.com/andersoxie/xpact/issues/13)
  - [x] [Test runner stops at the first failure](github/issues/06-finding-runner-stops.md): filed as [#60](https://github.com/andersoxie/xpact/issues/60), fixed in [reports/issue-0060](../reports/issue-0060/report.md)
  - [x] [Assertions DLL smoke test crashes](github/issues/07-finding-dll-crash.md) (K3): fixed in PR [#80](https://github.com/andersoxie/xpact/pull/80) ([#79](https://github.com/andersoxie/xpact/issues/79)); verified 2026-10-26: `build_native_eiffel.ps1 -BuildTier Assertions` → `xpact Eiffel DLL smoke: ok` ([#104 check](../reports/issue-0104/report.md))
  - [x] Python harness fails on Python 3.10: fixed in `492c6eb` ([#32](https://github.com/andersoxie/xpact/issues/32))
  - [x] [53 W3C cases crash xpact](github/issues/21-finding-xmlconf-crashes.md) (47 after #28): fixed in PR [#80](https://github.com/andersoxie/xpact/pull/80) ([#79](https://github.com/andersoxie/xpact/issues/79)); verified 2026-10-26: W3C `FinalizedAssertions` 1,727 passed, 0 failed, 0 errors, no crash ([#104 check](../reports/issue-0104/report.md)), with the current runner `run_w3c_conformance.py` (the original `run_xmlconf_conformance.ps1` is no longer in the repository)
  - [x] New, found in the W3C run with assertions on: the loop variant in `XP_PARSER.normalized_input` fails on every input with a CR: [#28](https://github.com/andersoxie/xpact/issues/28), regression test `1ea242e`
  - [x] [Jenkins precompile prompt](github/issues/23-finding-jenkins-precompile.md): dropped on 2026-10-22, not pursued ([#56](https://github.com/andersoxie/xpact/issues/56))
- [x] **Decision:** choose one main improvement and a small input set with the supervisor. *Still open 2026-10-26:* no decision recorded (week 2 and week 3 notes); **needs the supervisor**. Done so far without it: B01/B02 (failure reporting) and the #80 parser repair. ✅ *Settled in practice: the week 6 improvement (all W3C cases, #146/#148/#151) was reviewed and merged into `main` by the supervisor (PR #177, 2026-10-31); the input set is G01 (93 cases, #118). No separate written decision exists.*

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
| ✅ | [#3](https://github.com/andersoxie/xpact/issues/3) | B03 loop variant | [#12](https://github.com/andersoxie/xpact/pull/12) merged; verified 2026-10-26 ([#104](https://github.com/andersoxie/xpact/issues/104)) | | |

Together, #2, #7 and #10 bring in the week 1 build fixes from
[patch 01](history/patches/01-week1-build-fixes.patch), except its
`run_xmlconf_conformance.ps1` part. [Patch 02](history/patches/02-week2-runner-changes.patch)
(pinned W3C download, test-matrix stderr guard) is not applied yet.
The 2026-10-19 error report is [reports/error-reports/2026-10-19.md](../reports/error-reports/2026-10-19.md).

## Week 3 – Failure reporting
**Activity:** Learn how the test runner reports failure. Reproduce a deliberately failing test.
**Bring to review:** A bounded failure-reporting fix, or a precise proposal with evidence.
- [x] [B01](https://github.com/andersoxie/xpact/issues/45) Failing tests must return a nonzero exit status: done 2026-10-22, PR [#62](https://github.com/andersoxie/xpact/pull/62) ([report](../reports/issue-0045/report.md), [logs](results/B01-nonzero-exit/README.md))
- [x] [B02](https://github.com/andersoxie/xpact/issues/46) Deliberately failing meta-tests: done 2026-10-22, PR [#63](https://github.com/andersoxie/xpact/pull/63), `XPACT_META_FAIL` ([report](../reports/issue-0046/report.md), [results](results/B02-meta-tests/README.md)); Jenkins check dropped on 2026-10-22, not pursued
- [x] Week 3 note: [week-03.md](notes/weekly/week-03.md) (written 2026-10-20, updated 2026-10-21 and 2026-10-22)
- [x] W3C suite with the Python runner, assertions off and on: [#29](https://github.com/andersoxie/xpact/issues/29), [results/w3c-conformance-2026-10-21/](results/w3c-conformance-2026-10-21/README.md), [error report](../reports/error-reports/2026-10-21.md)
- [x] Regression test for the CR crash: [#28](https://github.com/andersoxie/xpact/issues/28), `1ea242e`; parser repaired 2026-10-22 (PR [#59](https://github.com/andersoxie/xpact/pull/59))
- [x] Repository repair and GitHub setup per `CLAUDE.md`: [#34](https://github.com/andersoxie/xpact/issues/34), [#35](https://github.com/andersoxie/xpact/issues/35), [#43](https://github.com/andersoxie/xpact/issues/43) (merged 2026-10-22)
- [x] Checklist audit (2026-10-22, [#70](https://github.com/andersoxie/xpact/issues/70)): every closed issue's "Done when" list compared with the repository at `76ac272`. 12 issues had unticked boxes; the items that are really done are now ticked on GitHub, each marked "verified 2026-10-22" ([report](../reports/issue-0070/report.md)). Still open from the audit:
  - [x] [#35](https://github.com/andersoxie/xpact/issues/35): 6 labels in `labels.json` were not on GitHub: **created 2026-10-26** with the student's authorization ([#108](https://github.com/andersoxie/xpact/issues/108)); all 21 now match `labels.json`
  - [x] [#46](https://github.com/andersoxie/xpact/issues/46): Jenkins stage turns red: **dropped** 2026-10-22 by the student ([#64](https://github.com/andersoxie/xpact/issues/64)), not checked; B02 is verified on the student PC only
  - [x] Project board: `gh` has the `project` scope since 2026-10-26; the board was read and brought up to date ([#108](https://github.com/andersoxie/xpact/issues/108)): 16 missing student issues added, 7 closed issues and 2 merged PRs moved to Done
  - [x] A01's last three items had no evidence: done in [#68](https://github.com/andersoxie/xpact/issues/68) (PR [#69](https://github.com/andersoxie/xpact/pull/69))
  - [x] #43 dates on every page and the #35 issue tables: done in [#70](https://github.com/andersoxie/xpact/issues/70)

## Week 4 – Input matrix
**Activity:** Design small regressions and select 50–100 applicable W3C XML cases with the supervisor.
**Bring to review:** An input matrix with reviewed expected outcomes.
- [x] [G01](github/issues/11-G01.md) Corpus manifest and 50–100 reviewed W3C cases: done 2026-10-26 ([#118](https://github.com/andersoxie/xpact/issues/118)): 93 cases, 83 counted (46 accept, 37 reject), 10 marked; all pass today in both builds; selected by the student, not reviewed by the supervisor ([results](results/G01-corpus/README.md))
- [x] [Fix xmlconf verdict rules](github/issues/12-xmlconf-verdicts.md): done 2026-10-26 ([#117](https://github.com/andersoxie/xpact/issues/117)): the old PowerShell runner (never in git) is superseded by `run_w3c_conformance.py`; its 2026-10-14 results re-scored: 676 of 854 "failures" were wrong rules, the 233 real problems all pass today ([results](results/xmlconf-verdicts/README.md))

## Week 5 – Regressions
**Activity:** Run the selected small inputs with different callbacks and chunk boundaries.
**Bring to review:** Repeatable regressions and small bug reproductions.
Run early (2026-10-22) with the C# DLL test program ([#37](https://github.com/andersoxie/xpact/issues/37), [results](results/dll-tests-2026-10-22/README.md)): 3,360 cases on three DLLs.
- [x] [C02](github/issues/13-C02.md) Malformed final-input cases with all six callback sets: run; found [#38](https://github.com/andersoxie/xpact/issues/38) (C01 shortcut). **Regressions added** 2026-10-26 ([#128](https://github.com/andersoxie/xpact/issues/128), [results](results/C02-final-input/README.md)): DLL smoke test + Eiffel suite; with the #38 or #40 fix undone they fail
- [x] [C03](github/issues/14-C03.md) Chunk boundaries: every split and byte by byte run, found [#40](https://github.com/andersoxie/xpact/issues/40) (fixed in #80, verified 2026-10-26); **compared with Expat 2.8.1** 2026-10-26 ([#121](https://github.com/andersoxie/xpact/issues/121), [results](results/C03-chunks/README.md)): same verdicts and codes at every split; xpact's position moves for `<root/>junk` only ([#124](https://github.com/andersoxie/xpact/issues/124))
- [x] [C10 (part)](github/issues/15-C10.md) Malformed UTF-8 in six places, whole and split: run; found [#39](https://github.com/andersoxie/xpact/issues/39) (fixed in #80, verified 2026-10-26). **Compared with Expat 2.8.1** 2026-10-26, `80` and `FF` added ([#121](https://github.com/andersoxie/xpact/issues/121), [results](results/C10-utf8/README.md)): all 3,606 verdicts agree; position and events differ ([#122](https://github.com/andersoxie/xpact/issues/122), [#123](https://github.com/andersoxie/xpact/issues/123))
- [x] **Decision:** review with the supervisor what can realistically be completed: **skipped by the student** (2026-10-26); everything planned for week 5 was completed

## Week 6 – One improvement
**Activity:** Pair on one manageable test-framework or verification-script improvement.
**Bring to review:** Before-and-after results and a reviewed change.
- [x] Improvement: all W3C cases run without skips, the bugs this exposed fixed, and the entity-reference speed fixed (#146, #148, #151, merged with PR #152 on 2026-10-28)
- [x] Before-and-after results: [latest-2026-10-28](../reports/latest-2026-10-28/README.md), [#151 report](../reports/issue-0151/report.md)
- [x] Reviewed by the supervisor, and a Jenkins run: merged into `main` by the supervisor (PR #177), Jenkins passed (2026-10-31)

## Week 7 – Comparison
**Activity:** Compare xpact and libexpat; add more applicable W3C cases as time permits.
**Bring to review:** A table of matches, differences and untested cases.
- [x] [A04](github/issues/16-A04.md) Verify which library the tests load: done 2026-10-31 ([#168](https://github.com/andersoxie/xpact/issues/168)): 16 runners, every loaded DLL identified by SHA-256; **15 load the expected library**, no stale copy; Expat's C tests without `-XpactLibrary` use the bridge-only DLL ([#179](https://github.com/andersoxie/xpact/issues/179), ✅ fixed in [#182](https://github.com/andersoxie/xpact/pull/182)) ([results](results/A04-loaded-library/README.md))
- [x] [G03](github/issues/17-G03.md) xpact vs Expat comparison across chunks: done 2026-10-31 ([#169](https://github.com/andersoxie/xpact/issues/169)): 93 G01 cases × 14 ways of feeding, **the same verdict as Expat 2.8.1 in all 1,302 pairs**; 59 cases identical; 34 differ in error code, position or events, filed as [#170](https://github.com/andersoxie/xpact/issues/170)-[#176](https://github.com/andersoxie/xpact/issues/176) ([results](results/G03-comparison/README.md))
- [x] W3C **output** compared with the expected output files and with Expat (432 cases): done 2026-10-28, 399 right after [#154](https://github.com/andersoxie/xpact/issues/154), [#156](https://github.com/andersoxie/xpact/issues/156), [#157](https://github.com/andersoxie/xpact/issues/157), [#158](https://github.com/andersoxie/xpact/issues/158) and [#159](https://github.com/andersoxie/xpact/issues/159); no xpact-only difference left ([report](../reports/issue-0154/report.md))
- [x] Follow-up fixes of the comparison findings, 2026-10-31: [#122](https://github.com/andersoxie/xpact/issues/122), [#124](https://github.com/andersoxie/xpact/issues/124), [#125](https://github.com/andersoxie/xpact/issues/125), [#172](https://github.com/andersoxie/xpact/issues/172), [#173](https://github.com/andersoxie/xpact/issues/173), [#174](https://github.com/andersoxie/xpact/issues/174), [#175](https://github.com/andersoxie/xpact/issues/175) (see Next, item 11)
- [ ] The comparison table rerun on the fixed code (G03 and the C# DLL tests), for the review
- [x] Weekly notes for weeks 6 and 7 (`notes/weekly/`) ✅ ([week 6](notes/weekly/week-06.md), [week 7](notes/weekly/week-07.md))

## Week 8 – Consolidate
**Activity:** Consolidate the results and add selected SVG or libxml2 cases. Core integration stays optional.
**Bring to review:** Shared fixtures and comparison output, or documented integration requirements.
- [ ] Shared fixtures and comparison output committed under `results/`
- [ ] More test sources found online (SVG, libxml2 and others), ranked, with a suggested order: [`notes/moreTests.md`](notes/moreTests.md) (2026-11-01)
- [ ] Optional: [F01](github/issues/19-F01.md) Core build, [F02](github/issues/20-F02.md) Core runner

## Week 9 – Analyse and draft
**Activity:** Analyse the results and draft the report. Try selected PubMed files if the correctness checks permit.
**Bring to review:** A draft report and result tables tied to specific builds.
- [x] [Report draft](github/issues/18-report-handover.md) in [`report/`](report/) ✅ [`ActualReport.md`](report/ActualReport.md) (2026-11-01); ✏️ the student completes the personal details and the reflection

## Week 10 – Handover
**Activity:** Demonstrate the work, address review comments and hand it over.
**Bring to review:** Final report, tests, code or proposals, setup guide and follow-up list.
- [ ] [Report, demonstration and handover](github/issues/18-report-handover.md)
- [ ] [A06](github/issues/03-A06.md) All weekly notes and result records complete. Weeks 1-7 written (2026-10-31)

## Not in the plan (unless the supervisor asks)
The other tasks in the register (A03, A05, B03–B07, C01, C04–C09, D, E, F03–F09,
G02, G04–G10, H) are context, or work owned by experienced developers. B04 or
B05 is an alternative to B01/B02 if failure accounting turns out to be more useful.
