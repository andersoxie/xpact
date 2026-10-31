# Week 6 - One improvement

> **Done early, 2026-10-27 to 2026-10-30** (the calendar week is 9-13 November).
> Week goal (guide): one test-framework or verification-script improvement.
> Bring to review: before-and-after results and a reviewed change.

## Tried
- [x] Ran **all 2,585 W3C cases**, with none skipped ("Option A"), and fixed the 7 parser bugs
  this showed ([#146](https://github.com/andersoxie/xpact/issues/146)).
- [x] Fixed a slow spot: each internal entity reference took longer the longer the document
  was ([#148](https://github.com/andersoxie/xpact/issues/148)).
- [x] Joined both fixes with the supervisor's work on `main`
  ([#151](https://github.com/andersoxie/xpact/issues/151), PR [#152](https://github.com/andersoxie/xpact/pull/152)).
- [x] Added a small regression lane that runs on xpact and on Xpact-core, whole and in pieces
  ([#153](https://github.com/andersoxie/xpact/issues/153)).
- [x] Started the W3C **output** test: xpact's output compared with the expected files
  ([#154](https://github.com/andersoxie/xpact/issues/154)-[#159](https://github.com/andersoxie/xpact/issues/159)), and the
  "W3C in pieces" test ([#165](https://github.com/andersoxie/xpact/issues/165)).

## What the evidence shows
- **2,585 W3C cases: 2,283 checked + 302 "no crash only", 0 failed, 0 errors, 0 skipped**, in both
  builds ([report](../../../reports/latest-2026-10-28/README.md)).
- W3C output: 359 → **399 / 432** right; every xpact-only difference of that test is fixed
  ([report](../../../reports/issue-0154/report.md)).
- W3C in pieces: callbacks were sent twice when the input came in pieces; fixed in #165
  (1,995 → 2,438 documents the same however they are split).
- ✅ The supervisor merged it all into `main` (PR [#177](https://github.com/andersoxie/xpact/pull/177)),
  and **Jenkins passed** (2026-10-31).

## Blocked
- Nothing. (The supervisor's review and Jenkins run came on 2026-10-31.)

## Next week
- [x] Week 7: compare xpact with Expat 2.8.1 across chunks (G03) and check which library each test loads (A04).
