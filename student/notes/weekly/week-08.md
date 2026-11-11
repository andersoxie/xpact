# Week 8 - Consolidate

> **3-9 November 2026, state on 2026-11-10** · work branch `incremental-test` of andersoxie/xpact
> (since 2026-11-08; `student-Mass` is fully contained in it, `incremental-test` has 153 more commits).
> Week goal (guide): consolidate the results; add selected SVG or libxml2 cases. Core integration stays optional.
> Bring to review: shared fixtures and comparison output.

## Tried
- [x] **Shared fixtures and Expat comparison** (247 fixtures in 9 sets) and the `moreTests.md` sources 1-6
  run against Expat ([mass-xpact#81](https://github.com/CodTanium/mass-xpact/issues/81), [#85](https://github.com/CodTanium/mass-xpact/issues/85)).
- [x] **Speed and fix rounds** (mass-xpact, merged into `student-Mass`, then into `incremental-test`):
  chunked input resumes instead of re-parsing, billion-laughs rule as in Expat (#60), unread external
  entities skipped (#64), acceptance run against `253c81e` (#67), regressions #68, #69, #72 fixed.
- [x] **Full test rerun on `incremental-test` (2026-11-08)** and shown on the website
  ([results](../../results/AlotOfTests-2026-11-08/README.md), PR #239); #209 and #211 rechecked (PR #240).
- [x] **Website:** built; PRs #212, #225, #226 merged; Docker image from GitHub, releases `website-2026-11-09-*`
  (#241, #244, #246, #249); small text changes #243-#248. `testing` is listed in `api.md` and `security.md`.
- [x] **Branches brought together:** PR #251 merged `main` (Gobo and WSL compiler benchmarks, #235) into `incremental-test`.
- [x] **Boogie models** ([#252](https://github.com/andersoxie/xpact/issues/252), PR #253, [report](../../../reports/issue-0252/report.md)):
  `verification/boogie/` checks the #3 loop and the UTF-16 decoder loop.
- [x] **mass-xpact is now a mirror** of andersoxie/xpact (2026-11-09); its 9 open issues were closed as
  "not planned" without verification, so the three that matter were rechecked (below).

## What the evidence shows
**Expected and observed are kept apart: the numbers below are observed.**

| Check | Observed |
|---|---|
| Full rerun 2026-11-08 | no crash in XPact, no regression against 2026-10-28; W3C output 399 / 432 exact; C# DLL tests 4,308 / 4,308; 2,585 W3C cases, 0 failed. Known failures stay open (see its README) |
| Python tests after PR #251 | **226 OK** (212 before) |
| Parser source | unchanged since the 2026-11-08 rerun |
| Boogie (#252) | finds both old loop bugs ([#3](https://github.com/andersoxie/xpact/issues/3), mass-xpact#12) in the pre-fix code; proves the current code. **Open finding:** the proof needs 3 facts that no contract states |
| mass-xpact#84 slow ISO-8859-1 input in 1 KB pieces | 🔴 **still present** (rechecked 2026-11-09): 64/128/256 KB take 0.116 / 0.421 / 1.634 s, UTF-8 0.003 / 0.006 / 0.011 s |
| mass-xpact#73 DLL crash without trace | 🔴 **still present**: code unchanged (`exenv` is local in `dllmain`, no per-entry guard) |
| mass-xpact#20 heap corruption | ❔ **not reproduced, inconclusive**: 72 / 72 normal runs pass; 12 stressed runs all hit the 300 s timeout. Cause unknown |
| mass-xpact#75 thread safety | 🔴 not fixed (`xpact.ecf` has `concurrency none`) |

## 2026-11-10 (launch preparation)

| Check | Result |
|---|---|
| W3C runner, all 2,585 cases, both builds, rebuilt from `68abdcb` | ✅ 0 failed, 0 errors (same as 2026-11-08) |
| [#227](https://github.com/andersoxie/xpact/issues/227) memory cap | ✅ test added: a nested-entity document under a 40 MB cap stops the worker; backend 21/21 three times |
| Website load test | ✅ ~40 requests/s (tiny), ~31/s (100 KB), 0 failures up to 32 at once ([load-test.md](../../../website/docs/load-test.md)) |
| SonarQube local scan (#131) | ⏳ script ready, needs the student's token |

## Blocked
- Website deployment ([#210](https://github.com/andersoxie/xpact/issues/210)), HTTPS and the low-privilege worker account
  are on the supervisor's server.
- SonarQube [#131](https://github.com/andersoxie/xpact/issues/131) (HTTP 401 in Jenkins): the student has a token from
  the supervisor; a local scan is being tried today.
- `main` has 2 commits not in `incremental-test` (PR #254, Jenkins plots, 9 November).

## Next
- [x] Merge `incremental-test` into `main`: `main` contains all of `incremental-test` (checked 2026-11-11).
- [x] Website: [#227](https://github.com/andersoxie/xpact/issues/227) memory-cap test and load test (2026-11-10).
- [x] Website checked and fixed (2026-11-11): Lighthouse accessibility 89-91 → 100, speed 87-94 → 98-100, ZAP 2 medium → 0, W3C HTML 0/0, 27/27 backend tests; Docker checklist passes. PRs #282, #285, #287, #288 ([PLAN](../../PLAN.md#-website-quality-check-2026-11-11)).
- [ ] Website: review findings 1-2; worker under a low-privilege account (code part ours, account on the supervisor's server). HTTPS: the supervisor.
- [ ] Open issues on andersoxie (16 on 2026-11-11): #275, #274, #273, #272, #262, #211, #210, #197, #176, #171, #170, #131, #130, #126, #123, #13. (#227 closed 2026-11-10; #281, #283, #284, #286 closed 2026-11-11.)
- [x] Refile mass-xpact#84, #73, #75 on andersoxie: #272, #273, #274.
- [x] Update [`ActualReport.md`](../../report/ActualReport.md) and `ActualReportShorter.md` with week 8 (PR #269). Hand-in 27 November.
