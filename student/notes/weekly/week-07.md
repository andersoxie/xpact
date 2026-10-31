# Week 7 - Comparison

> **Done early, 2026-10-31** (the calendar week is 16-20 November) · `student-Mass` @ `c12b705`.
> Week goal (guide): compare xpact and libexpat; add more W3C cases if there is time.
> Bring to review: a table of matches, differences and untested cases.

## Tried
- [x] **G03:** 93 W3C cases through xpact and Expat 2.8.1, fed in 14 different ways (whole and
  in pieces) ([#169](https://github.com/andersoxie/xpact/issues/169), [results](../../results/G03-comparison/README.md)).
- [x] **A04:** checked which DLL each of the 16 test runners really loads, by SHA-256
  ([#168](https://github.com/andersoxie/xpact/issues/168), [results](../../results/A04-loaded-library/README.md)).
- [x] Fixed what the comparisons found, one issue and one pull request each, every fix checked
  on both builds against Expat:
  [#122](https://github.com/andersoxie/xpact/issues/122), [#124](https://github.com/andersoxie/xpact/issues/124),
  [#125](https://github.com/andersoxie/xpact/issues/125), [#172](https://github.com/andersoxie/xpact/issues/172)-[#175](https://github.com/andersoxie/xpact/issues/175),
  [#179](https://github.com/andersoxie/xpact/issues/179), [#180](https://github.com/andersoxie/xpact/issues/180).
- [x] Brought the supervisor's newest `main` into `student-Mass` ([#188](https://github.com/andersoxie/xpact/issues/188)).

## What the evidence shows
- **Same verdict as Expat in all 1,302 G03 pairs**, however the input arrives.
- Where they differed, it was the error code, the error position or the events: 34 cases,
  filed as [#170](https://github.com/andersoxie/xpact/issues/170)-[#176](https://github.com/andersoxie/xpact/issues/176).
  Four of these are fixed now.
- C# DLL tests against Expat (4,308 cases): every field the same in 1,079 cases before,
  3,423 after #172; #124 and #125 each add more (66 and 21, measured one at a time; error codes
  **4,308 / 4,308** with #124). No fix made a case worse. The combined number comes with the rerun below.
- A04: 15 of 16 runners load the right DLL. The one that did not (Expat's C tests) is fixed (#179).
- **Speed:** the DLL is 25-40× slower than Expat on a whole document, and re-parses markup on
  every call when input comes in pieces (8 KB, one byte at a time: 58 s, Expat 5 ms). The
  supervisor's incremental parser exists only as a prototype that the DLL does not use.

## Blocked
- Nothing blocks week 7. The speed design (F05-1), #171 and #13 are questions for the supervisor.

## Next
- [ ] Rerun the G03 and C# comparison tables on the fixed code, for the review.
- [ ] Left to do, saved in [PLAN.md](../../PLAN.md) ("Next", item 12): #197, one batch benchmark run,
  #176 with #123, #170, #126, #171, #13.
- [ ] Week 8: collect the shared fixtures and comparison output under `results/`.
