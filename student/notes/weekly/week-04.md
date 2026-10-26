# Week 4 - 26-30 October 2026

> **Status 2026-10-26 (Monday)** · `student-Mass` @ `97795fb`, 0 behind `main`.
> Week goal (guide): design small regressions and select 50-100 W3C cases with
> the supervisor (**G01**). G01 not started yet; Monday went to bringing everything
> level and checked.

## Tried
- [x] Summarised the supervisor's work on `main` (#82-#101) and merged it into
  `student-Mass` twice, without conflicts ([#102](https://github.com/andersoxie/xpact/issues/102), [#110](https://github.com/andersoxie/xpact/issues/110)).
- [x] Full check of the folder and every build and test ([#104](https://github.com/andersoxie/xpact/issues/104)); found that
  the matrix and W3C had been built with MinGW, Python 3.10 broke 102 tests, and
  long paths broke 15.
- [x] Set the PC up like the supervisor's where possible ([#113](https://github.com/andersoxie/xpact/issues/113)).
- [x] Closed out weeks 2-3, created the 6 missing labels, fixed the project
  board ([#106](https://github.com/andersoxie/xpact/issues/106), [#108](https://github.com/andersoxie/xpact/issues/108)).
- [x] Closed #3, #39, #40, #68, #70 with evidence.

## What the evidence shows
- Every build and test passes with assertions on, built with MSVC: matrix 4/4,
  DLL tests 3,360/3,360 on both DLLs, W3C 1,727/1,727 in both builds, 178 Python
  tests ([#110 report](../../../reports/issue-0110/report.md), [#113 report](../../../reports/issue-0113/report.md)).
- No result so far depended on the EiffelStudio or MSVC version; all problems
  were settings (paths, backend, Python minimum, long paths, `-keep`).

## Blocked
- Jenkins rerun for #73, #74, #79, and the PR #76 merge: supervisor.
- Week 2 decision on the main improvement: supervisor.

## Next (rest of week 4)
- [x] G01: 93 W3C cases with source, hash and reviewed expected result
  ([#118](https://github.com/andersoxie/xpact/issues/118), [results](../../results/G01-corpus/README.md)).
- [x] xmlconf verdict rules: 676 of the old 854 "failures" were wrong rules
  ([#117](https://github.com/andersoxie/xpact/issues/117), [results](../../results/xmlconf-verdicts/README.md)).
- [ ] Ask the questions in [`for superviser.txt`](../../for%20superviser.txt).
