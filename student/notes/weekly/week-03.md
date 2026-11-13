# Week 3 - 2026-10-19 to 2026-10-23: Failure reporting

> **Branch** `student-Mass` @ `63f67f3` · **Written** 2026-10-23 · **Plan** [PLAN.md](../../PLAN.md) · **Board** [project 3](https://github.com/users/CodTanium/projects/3)
>
> ✅ done and verified · 🟡 done, waiting for review or verification · 🔴 open problem · ⏸ on hold

## In one minute

| | |
|---|---|
| ✅ **Week goal met** | Every failure seen so far has one issue, one report and saved logs. Failing tests now **exit nonzero in every build** (B01) and a **switchable meta-test** proves it (B02). |
| ✅ **Biggest result** | The `normalized_input` CR repair ([#28](https://github.com/andersoxie/xpact/issues/28)): W3C with assertions on went from **270 passed / 1,360 crashes** to **1,444 passed / 47 crashes**. |
| 🟡 **Waiting** | B03 fix [#12](https://github.com/andersoxie/xpact/pull/12) merged on 2026-10-23, but [#3](https://github.com/andersoxie/xpact/issues/3) stays open until the matrix is rerun. Jenkins rerun needed for [#73](https://github.com/andersoxie/xpact/issues/73)/[#74](https://github.com/andersoxie/xpact/issues/74) (PR [#76](https://github.com/andersoxie/xpact/pull/76) open). |
| 🔴 **Open parser findings** | [#38](https://github.com/andersoxie/xpact/issues/38) start handler drops the rest of the document · [#39](https://github.com/andersoxie/xpact/issues/39) invalid UTF-8 accepted · [#40](https://github.com/andersoxie/xpact/issues/40) chunk ending in `<` crashes · [#13](https://github.com/andersoxie/xpact/issues/13) swallowed exceptions. All ⏸ for the parser developer. |

**Numbers this week:** 30 pull requests merged into `student-Mass` · 30 issues closed (each with a verification comment) · 7 issues and 1 pull request still open.

## Week 3 goals

- [x] Report each failure the CLAUDE.md way: one issue, exact command, expected vs actual, logs in `reports/issue-NNNN/` ✅
- [x] Bring the week 1 build fixes into git, one tested pull request each ✅ ([#2](https://github.com/andersoxie/xpact/issues/2), [#4](https://github.com/andersoxie/xpact/issues/4), [#7](https://github.com/andersoxie/xpact/issues/7), [#10](https://github.com/andersoxie/xpact/issues/10))
- [x] A02: rerun the assertions-enabled baseline in the git clone ✅ ([#33](https://github.com/andersoxie/xpact/issues/33), [setup guide](../../report/setup-guide.md))
- [x] B01: a failing test makes the run exit nonzero, in every build ✅ ([#45](https://github.com/andersoxie/xpact/issues/45), PR [#62](https://github.com/andersoxie/xpact/pull/62))
- [x] B02: deliberately failing meta-test, switched by `XPACT_META_FAIL` ✅ ([#46](https://github.com/andersoxie/xpact/issues/46), PR [#63](https://github.com/andersoxie/xpact/pull/63))
- [x] GitHub set up: labels, week milestones, project board ✅ ([#35](https://github.com/andersoxie/xpact/issues/35), PR [#47](https://github.com/andersoxie/xpact/pull/47))
- [x] B03 verified after the merge of [#12](https://github.com/andersoxie/xpact/pull/12) ✅ *later: verified and [#3](https://github.com/andersoxie/xpact/issues/3) closed 2026-10-26*
- [x] Jenkins builds the DLL again ✅ *later: verified on Jenkins for [#73](https://github.com/andersoxie/xpact/issues/73) (2026-10-26); [#74](https://github.com/andersoxie/xpact/issues/74) merged in PR [#76](https://github.com/andersoxie/xpact/pull/76), Jenkins passed 2026-10-31*

## What changed in the tests and builds

| Area | Before this week | After this week | Evidence |
|---|---|---|---|
| Finalized lane, assertions on | 🔴 green only because `-keep` was missing (K2) | ✅ compiled with `-keep`, assertions checked | [#48](https://github.com/andersoxie/xpact/issues/48), PR [#49](https://github.com/andersoxie/xpact/pull/49) |
| Test matrix in a fresh shell | 🔴 vswhere error, workbench lanes without MSVC, stale `.exe` when run outside the repo root | ✅ all four lanes build and run from the repo root | [#51](https://github.com/andersoxie/xpact/issues/51), [#53](https://github.com/andersoxie/xpact/issues/53), [#55](https://github.com/andersoxie/xpact/issues/55) |
| A test raises an exception | 🔴 the runner stopped, later tests never ran | ✅ exception recorded, remaining tests run (`42 run, 1 raised an exception`) | [#60](https://github.com/andersoxie/xpact/issues/60), PR [#61](https://github.com/andersoxie/xpact/pull/61) |
| A test fails, assertions off | 🔴 `FAIL:` printed, but **exit 0** | ✅ `FAILED`, exit 1 (12 runs, all as predicted) | [B01 report](../../../reports/issue-0045/report.md) |
| Proof that failures are caught | ⬜ none | ✅ `XPACT_META_FAIL=assert` / `exception` fails every lane | [B02 report](../../../reports/issue-0046/report.md) |
| Any input with a CR, assertions on | 🔴 loop-variant crash | ✅ repaired, regression test added | [#28](https://github.com/andersoxie/xpact/issues/28), PR [#59](https://github.com/andersoxie/xpact/pull/59), [report](../../../reports/issue-0028/report.md) |
| DLL tests from another language | ⬜ none | ✅ C# program, 3,360 cases on 3 DLLs | [#37](https://github.com/andersoxie/xpact/issues/37), [results](../../results/dll-tests-2026-10-22/README.md) |

### W3C conformance suite (1,727 applicable cases)

| Build | Assertions | Passed | Failed | Crashed |
|---|---|---:|---:|---:|
| Finalized, 2026-10-21 | off | 1,491 | 236 | 0 |
| FinalizedAssertions, 2026-10-21 | on | 🔴 270 | 97 | 🔴 1,360 |
| FinalizedAssertions, after the #28 repair | on | ✅ **1,444** | 236 | 🔴 **47** |

- **Observed:** with assertions on, the failures now match the assertions-off build (236). Of those, 220 are malformed documents that xpact accepts.
- **Not yet known:** the cause of the 47 remaining crashes in DTD declaration parsing ([list](../../../reports/issue-0028/w3c-after-fix/crashes-assertions-on.tsv)). They were hidden behind #28 and still need to be filed as findings.

## 🔴 Open problems (living list)

| Problem | Cause | Issue | Status / next step |
|---|---|---|---|
| B03 postcondition `final_finished_or_suspended` | ✔ confirmed: loop variant at `/>` | [#3](https://github.com/andersoxie/xpact/issues/3) | 🟡 fix [#12](https://github.com/andersoxie/xpact/pull/12) merged 2026-10-23; **rerun the matrix and the DLL tests, then close** |
| GC-suspended parses swallow exceptions | ✔ swallowing · ❓ lost traces | [#13](https://github.com/andersoxie/xpact/issues/13) | ⏸ parser developer |
| Start handler: `<root>` accepted, end events lost | ❓ suspected C01 shortcut | [#38](https://github.com/andersoxie/xpact/issues/38) | ⏸ parser developer |
| Invalid UTF-8 accepted in all six places | ❓ suspected: no strict decoder | [#39](https://github.com/andersoxie/xpact/issues/39) | ⏸ parser developer |
| Non-final chunk ending with `<` crashes the assertions DLL | ✔ trigger · ❓ in the code | [#40](https://github.com/andersoxie/xpact/issues/40) | ⏸ parser developer |
| 47 W3C crashes in DTD parsing | ❓ unknown | (to file) | ⬜ file as findings |
| Jenkins cannot find the Eiffel include folder | ✔ confirmed: our #2/#10 fixes replaced the fallback | [#73](https://github.com/andersoxie/xpact/issues/73) | 🟡 fixed in [#75](https://github.com/andersoxie/xpact/pull/75); waits for a Jenkins rerun |
| Build scripts override the Jenkins MSVC backend | ✔ confirmed by a script test · not seen failing | [#74](https://github.com/andersoxie/xpact/issues/74) | 🟡 PR [#76](https://github.com/andersoxie/xpact/pull/76) waits for review |
| Assertions DLL smoke test crashes (K3) | ❓ B03 is not its only cause | [draft 07](../../github/issues/07-finding-dll-crash.md) | ⏸ |

## Blocked / questions for the supervisor

1. **Jenkins rerun** on `main` after [#76](https://github.com/andersoxie/xpact/pull/76) is merged, so [#73](https://github.com/andersoxie/xpact/issues/73) and [#74](https://github.com/andersoxie/xpact/issues/74) can be verified and closed.
2. **Review PR [#76](https://github.com/andersoxie/xpact/pull/76)** (keep the machine's MSVC backend).
3. The parser findings #13, #38, #39, #40: who takes them, and should the student write the regression tests for them first?

## Next week (week 4: input matrix)

- [x] Verify B03 after the merge: assertions-on matrix (workbench and finalized `-keep`) and the C# DLL tests; close [#3](https://github.com/andersoxie/xpact/issues/3) only if they pass. *Done 2026-10-26.*
- [x] Close [#68](https://github.com/andersoxie/xpact/issues/68) (A01) and [#70](https://github.com/andersoxie/xpact/issues/70) (doc gaps) after checking their merged pull requests. *Done 2026-10-26.*
- [x] Update [PLAN.md](../../PLAN.md): it still lists #12 as a draft on hold. *Done.*
- [x] **G01:** choose 50-100 W3C cases from `results.tsv` (passes and failures, both builds), with source and expected result for each. *Done: 93 cases ([#118](https://github.com/andersoxie/xpact/issues/118)).*
- [x] File the 47 remaining W3C crashes as findings, grouped by routine. *Not needed: the parser repair [#80](https://github.com/andersoxie/xpact/pull/80) fixed all 47 (W3C 1,727/1,727, 2026-10-26).*

## Limitations of this week's evidence

- The W3C numbers are from one machine (EiffelStudio 25.12, Windows). Jenkins has not run since the fixes.
- The test matrix after the #12 merge has **not** been rerun. B03 counts as fixed only in the worktree build from 2026-10-22.
- A green run proves only the checks that exist. The parser tests do not cover invalid UTF-8 or chunk splits. Those are only tested through the DLL.

---

## Daily log

The notes written during the week, kept as they were.

### Tried
- Reported three failed runs ([error report](../../../reports/error-reports/2026-10-19.md)), then reran each in the git clone with exact commits and exit codes (#2, #3, #4, #7).
- Brought the week 1 build fixes into git, one issue and one tested pull request each: #2, #7, #10, plus #4 (PATH growth). Set up the versioning workflow (#5, `fix.ps1`) and one report folder per fix (#14): [reports/README.md](../../../reports/README.md).
- Investigated B03 (#3) by letting the swallowed exception through in a throwaway worktree.

### What the evidence shows
- The native DLL, the assertions DLL (`-SkipSmoke`) and the native runtime smoke test now build in a fresh shell (#7, #10). The cause was the default mingw C backend; `msc_vc140` fixes it.
- Repeated MSVC imports grew PATH by 1,432 characters each; the 5th failed. Now PATH stays at 2,657 (#4).
- **B03: the contract is wrong, not the code or the test.** The loop variant in `direct_start_tag_attributes` does not decrease at the `/` of `<root/>`. `MEMORY.execute_without_collection` swallowed that exception, so only `final_finished_or_suspended` showed (fix and report in pull request [#12](https://github.com/andersoxie/xpact/pull/12)). With the fix, all four matrix cells pass.
- New finding: GC-suspended parses silently drop exceptions (#13).

### Blocked
- #12 (parser change) waits for review by the parser's developer.
- The build fixes are on `student-Mass`, not `main` (draft 22): ask the supervisor.

### Next week
- A02: rerun the baseline in the git clone. B01/B02: nonzero exit on failure and meta-tests. Bring in `run_xmlconf_conformance.ps1` and patch 02.

### Update 2026-10-21
- Moved the clone to `C:\xpact\xpact-student-Mass`; installed Python 3.15 (uv) and the GitHub CLI there.
- Ran the W3C suite with the teacher's Python runner for the first time, with assertions off and on (#29, [results](../../results/w3c-conformance-2026-10-21/README.md)): off 1,491 of 1,727 passed, 236 failed (220 malformed documents accepted); on 1,360 crashed.
- 1,357 of those crashes are one new finding (#28): the loop variant in `XP_PARSER.normalized_input` fails on any CR, reproduced with a 9-byte file. Same kind of bug as B03, and it hides the 53 crashes of week 2 (draft 21).
- The Python runner downloads the pinned W3C ZIP itself, so `run_xmlconf_conformance.ps1` and patch 02 are no longer needed for that.
- Chose the next five tests from the guide (PLAN.md, "Next tests"): #28 regression, B02, C02, C03, C10.
- Blocked: `fix.ps1` stops in Windows PowerShell 5.1 (steps done by hand, see VERSIONING.md). Tests C02/C03/C10 through the DLL need a small C program first.

### Update 2026-10-22
- **Repaired the repository** against `CLAUDE.md` ([#34](https://github.com/andersoxie/xpact/issues/34)): the A02 rerun had overwritten a week 2 baseline log in the working copy (restored from git); four commits had gone to `student-Mass` without a pull request (now listed in VERSIONING.md); doc updates had been left uncommitted.
- **GitHub set up per `CLAUDE.md`** ([#35](https://github.com/andersoxie/xpact/issues/35)): labels `test`, `build`, `regression`, `investigation`; milestones Week 1-10 on every issue. The project board still needs `gh auth refresh -s project`.
- **Ran C02, C03 and part of C10 early** with a new C# program that calls the DLL like a C program ([#37](https://github.com/andersoxie/xpact/issues/37), [results](../../results/dll-tests-2026-10-22/README.md)): 3,360 cases on three DLLs. Three new findings: with a start handler `<root>` is accepted and end events are lost ([#38](https://github.com/andersoxie/xpact/issues/38), C01); invalid UTF-8 is accepted in all six places ([#39](https://github.com/andersoxie/xpact/issues/39), K4 is one case); a non-final chunk that ends with `<` crashes the assertions DLL ([#40](https://github.com/andersoxie/xpact/issues/40)).
- **Confirmed B03 through the DLL** with a B03-fixed build in a separate worktree: every `/>` input crashed before, none after (evidence on [#3](https://github.com/andersoxie/xpact/issues/3)). The C smoke test still crashes (K3), so B03 is not its only cause.
- Two problems in the new program itself were found and fixed before committing (cut-off traces; crashes reported as timeouts).
- **Blocked / waiting:** pull requests #36 → #41 → #42 → #44 wait for review and merge, in that order. B01/B02 are still to do this week.
