# 10-week plan

> **Last updated:** 2026-10-26 (week 4) · describes `student-Mass` @ `41731c8` (contains `main` @ `64d027f`), checked in full on 2026-10-26 ([#104](https://github.com/andersoxie/xpact/issues/104), [report](../reports/issue-0104/report.md))
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
| 4 Input matrix | ⬜ | G01: 50-100 reviewed W3C cases | |
| 5 Regressions | 🟡 | C02, C03, C10 (part) **run early** through the DLL: 3,360 cases, 3 findings (#38, #39, #40), **all fixed in #80**; rerun 2026-10-26: 3,360/3,360 on both DLLs. Expat comparison still to do | [dll-tests-2026-10-22](results/dll-tests-2026-10-22/README.md), [#104 check](../reports/issue-0104/report.md) |
| 6-10 | ⬜ | One improvement, Expat comparison, consolidate, report, handover | |

## ✅ Merged since 2026-10-22

| What | Pull request | Issue |
|---|---|---|
| A01 evidence: tests linked, change-and-predict | [#69](https://github.com/andersoxie/xpact/pull/69) | [#68](https://github.com/andersoxie/xpact/issues/68) ✅ closed 2026-10-26 |
| Checklist audit, doc gaps | [#71](https://github.com/andersoxie/xpact/pull/71) | [#70](https://github.com/andersoxie/xpact/issues/70) ✅ closed 2026-10-26 |
| Jenkins Eiffel include fallback `C:\El2502E` restored | [#75](https://github.com/andersoxie/xpact/pull/75) | [#73](https://github.com/andersoxie/xpact/issues/73) 🟡 Jenkins rerun |
| Week 3 report | [#77](https://github.com/andersoxie/xpact/pull/77) | - |
| Parser conformance: strict UTF-8, UTF-16, names, DTD declarations; DLL start-tag shortcut and UTF-16 loops | [#80](https://github.com/andersoxie/xpact/pull/80) | [#79](https://github.com/andersoxie/xpact/issues/79) 🟡 Jenkins rerun; fixes [#38](https://github.com/andersoxie/xpact/issues/38), [#39](https://github.com/andersoxie/xpact/issues/39), [#40](https://github.com/andersoxie/xpact/issues/40), K3 |
| `main` brought into `student-Mass` (the supervisor's #82-#100: libexpat lanes, parser handles and chunking #85, faster tag dispatch #87, WSL GCC benchmarks, Jenkins email, Xpact-core next to xpact #94-#98) | [#81](https://github.com/andersoxie/xpact/pull/81), [#103](https://github.com/andersoxie/xpact/pull/103) | [#102](https://github.com/andersoxie/xpact/issues/102) ✅ |
| The supervisor merged `student-Mass` into `main` | #72, #78 (by the supervisor) | - |

Still open: PR [#76](https://github.com/andersoxie/xpact/pull/76) ([#74](https://github.com/andersoxie/xpact/issues/74), keep the machine's MSVC backend), conflict fixed and retested 2026-10-26.

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
| **Jenkins** DLL build: `Cannot find Eiffel runtime include directory`; all later stages skipped | Jenkins on `main` @ `9e1747d`, 2026-10-23 ([log](../reports/issue-0073/jenkins-log-2026-10-23.txt)) | ✔ our #2/#10 fixes replaced the Jenkins fallback `C:\El2502E` | [#73](https://github.com/andersoxie/xpact/issues/73) | fixed on `student-Mass` (both paths searched); **Jenkins rerun by the supervisor** |
| Native build scripts always force `ISE_C_COMPILER=msc_vc140`, overriding a machine's own MSVC backend | check of all student build changes against Jenkins, 2026-10-23 | ✔ in the code · ❔ whether it breaks Jenkins | [#74](https://github.com/andersoxie/xpact/issues/74) | fixed on `student-Mass` (an existing `msc*` value is kept); Jenkins rerun |
| GC-suspended parses swallow exceptions | B03 analysis; crashes without a trace | ✔ (swallowing) · ❓ (lost traces) | [#13](https://github.com/andersoxie/xpact/issues/13) | ⏸ **on hold** (student, 2026-10-22); parser developer |
| Python tests fail with Python 3.10: `hashlib.file_digest` (3.11+) in the supervisor's new scripts; the setup guide says 3.10 works | [#104 check](../reports/issue-0104/report.md): 102 of 178 fail | ✔ | (no issue yet) | decide with the supervisor: require 3.11+ or avoid `file_digest` |
| `test_implementation_builds.py`: 13 tests fail in the deep `xpact3.0` folder, 1 everywhere on the student PC | [#104 check](../reports/issue-0104/report.md) | ✔ path over 260 characters · ❓ the last one needs Windows long paths | (no issue yet) | use the clone, or enable long paths (administrator) |
| Jenkins "Eiffel Tests" turns green without printing a test result | [#73 log](../reports/issue-0073/jenkins-log-2026-10-23.txt); stage unchanged on 2026-10-26 | ✔ on the student PC (stale exe) · ❓ on Jenkins | (no issue yet) | supervisor's pipeline |
| SonarQube `HTTP 401` on Jenkins | [#73 log](../reports/issue-0073/jenkins-log-2026-10-23.txt) | ✔ server token | (no issue yet) | supervisor renews the token |
| `tests/python/run_w3c_conformance.py` is an old copy (361 vs 459 lines), used by nothing | [#104 check](../reports/issue-0104/report.md) | ✔ | (no issue yet) | remove it |
| Error codes differ from libexpat (`<root>` 5 not 3, junk 4 not 9) | DLL tests | ❔ reference values not checked | (G03) | check against Expat 2.8.1 |

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
| Assertions DLL smoke test crashed `0xC0000028` (K3) | PR [#80](https://github.com/andersoxie/xpact/pull/80); smoke ok 2026-10-26 | [#79](https://github.com/andersoxie/xpact/issues/79), draft 07 |
| W3C, assertions on: 47 cases crashed in DTD declaration parsing | PR [#80](https://github.com/andersoxie/xpact/pull/80); W3C 1,727/1,727 on 2026-10-26 | [#79](https://github.com/andersoxie/xpact/issues/79), draft 21 |
| W3C, assertions off: 220 malformed accepted, 16 well-formed rejected | PR [#80](https://github.com/andersoxie/xpact/pull/80); W3C 1,727/1,727 on 2026-10-26 | [#79](https://github.com/andersoxie/xpact/issues/79), [#29](https://github.com/andersoxie/xpact/issues/29) |
| Build fixes were on `student-Mass`, not `main` | the supervisor merged `student-Mass` into `main` (#72, #78) | draft 22 |

</details>

## ➡️ Next

1. ✅ **Full check 2026-10-26** ([#104](https://github.com/andersoxie/xpact/issues/104)): every build and test passes with assertions on; #3, #39, #40, #68, #70 verified and closed.
2. 🟡 **Waiting for a Jenkins rerun** by the supervisor: [#73](https://github.com/andersoxie/xpact/issues/73), [#74](https://github.com/andersoxie/xpact/issues/74) (PR [#76](https://github.com/andersoxie/xpact/pull/76) to merge), [#79](https://github.com/andersoxie/xpact/issues/79).
3. **Ask the supervisor** about the problems without an issue (Python 3.10, long paths, Jenkins "Eiffel Tests", SonarQube, old runner copy) and the questions in [`for superviser.txt`](for%20superviser.txt).
4. **Week 4, G01:** choose 50-100 W3C cases (passes and failures, both builds) with written expected outcomes.
5. **W3C skips:** 247 cases per build need external entities (resolver off in the runner); test them with local-only resolution.
6. **C02/C03/C10, remaining:** compare with Expat 2.8.1 (needs an Expat build); turn the #38-#40 inputs into regression tests.
7. ⏸ Still on hold: [#13](https://github.com/andersoxie/xpact/issues/13) (GC wrapper swallows exceptions), A04.

<details>
<summary>The five tests chosen on 2026-10-21 and where they stand</summary>

From [`notes/next-tests-2026-10-21.txt`](notes/next-tests-2026-10-21.txt):

| | Test | State |
|---|---|---|
| ✅ | 1. CR regression (#28) | Test in `1ea242e`; parser repaired in PR [#59](https://github.com/andersoxie/xpact/pull/59), the test passes |
| ✅ | 2. B02 deliberately failing meta-test | [#46](https://github.com/andersoxie/xpact/issues/46), `XPACT_META_FAIL` |
| ✅ | 3. C02 through the DLL | [#37](https://github.com/andersoxie/xpact/issues/37), found #38 |
| 🟡 | 4. C03 every split position | run in #37 (found #40); the Expat comparison is still to do |
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
- [ ] **Decision:** choose one main improvement and a small input set with the supervisor. *Still open 2026-10-26:* no decision recorded (week 2 and week 3 notes); **needs the supervisor**. Done so far without it: B01/B02 (failure reporting) and the #80 parser repair

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
- [ ] [G01](github/issues/11-G01.md) Corpus manifest and 50–100 reviewed W3C cases
- [ ] [Fix xmlconf verdict rules](github/issues/12-xmlconf-verdicts.md)

## Week 5 – Regressions
**Activity:** Run the selected small inputs with different callbacks and chunk boundaries.
**Bring to review:** Repeatable regressions and small bug reproductions.
Run early (2026-10-22) with the C# DLL test program ([#37](https://github.com/andersoxie/xpact/issues/37), [results](results/dll-tests-2026-10-22/README.md)): 3,360 cases on three DLLs.
- [x] [C02](github/issues/13-C02.md) Malformed final-input cases with all six callback sets: run; found [#38](https://github.com/andersoxie/xpact/issues/38) (C01 shortcut). Regressions in the Eiffel suite still to add once repaired
- [ ] [C03](github/issues/14-C03.md) Chunk boundaries: every split and byte by byte run, found [#40](https://github.com/andersoxie/xpact/issues/40) (fixed in #80, verified 2026-10-26); **comparison with Expat 2.8.1 still to do**
- [x] [C10 (part)](github/issues/15-C10.md) Malformed UTF-8 in six places, whole and split: run; found [#39](https://github.com/andersoxie/xpact/issues/39) (fixed in #80, verified 2026-10-26). Expat comparison still to do
- [ ] **Decision:** review with the supervisor what can realistically be completed

## Week 6 – One improvement
**Activity:** Pair on one manageable test-framework or verification-script improvement.
**Bring to review:** Before-and-after results and a reviewed change.
- [ ] The improvement chosen in week 2 (B01/B02, the xmlconf verdicts or a C-group regression), reviewed and merged

## Week 7 – Comparison
**Activity:** Compare xpact and libexpat; add more applicable W3C cases as time permits.
**Bring to review:** A table of matches, differences and untested cases.
- [ ] [A04](github/issues/16-A04.md) Verify which library the tests load: ⏸ on hold (student, 2026-10-22, [#66](https://github.com/andersoxie/xpact/issues/66))
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
