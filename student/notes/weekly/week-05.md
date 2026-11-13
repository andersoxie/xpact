# Week 5 - Regressions

> **Started early, 2026-10-26** (the calendar week is 2-6 November) · `student-Mass` @ `e30f0e6`.
> Week goal (guide): run the selected small inputs with different callbacks and
> chunk boundaries. Bring to review: repeatable regressions and small bug reproductions.

## Tried
- [x] Built **Expat 2.8.1** (`R_2_8_1`) from source as `libexpat.dll` with MSVC and
  ran the C# DLL test program on it, next to both xpact DLLs
  ([#121](https://github.com/andersoxie/xpact/issues/121)).
- [x] Added the two missing C10 inputs, a lone `80` and `FF`: 4,308 cases now.
- [x] Compared every case: verdict, error code, position, failing call, events
  ([results](../../results/expat-2.8.1/README.md)).
- [x] Added the C02 inputs as tests in the DLL smoke test and the Eiffel suite ([#128](https://github.com/andersoxie/xpact/issues/128)).

## What the evidence shows
- **xpact and Expat agree on every verdict**: 4,308 / 4,308, whole and at every
  split. Chunking never changes xpact's verdict or error code.
- **Five differences**, each reported on its own, none fixed (parser work):
  [#122](https://github.com/andersoxie/xpact/issues/122) UTF-8 error position 1:0,
  [#123](https://github.com/andersoxie/xpact/issues/123) no events before a UTF-8 error,
  [#124](https://github.com/andersoxie/xpact/issues/124) `<root/>junk` error 4 not 9,
  [#125](https://github.com/andersoxie/xpact/issues/125) default handler gets the bad end tag,
  [#126](https://github.com/andersoxie/xpact/issues/126) default handler gets LF not CR.
  ✅ *Later (2026-10-31): #122, #124 and #125 fixed and closed; #123 mostly fixed (598 → 133 cases); #126 still open.*
- The libexpat error codes written in the test catalog on 2026-10-22 are all
  what Expat 2.8.1 really returns.

- [x] Gave the last three problems without an issue their own issue:
  [#130](https://github.com/andersoxie/xpact/issues/130) (Jenkins "Eiffel Tests" prints no result), [#131](https://github.com/andersoxie/xpact/issues/131) (SonarQube 401);
  [#132](https://github.com/andersoxie/xpact/issues/132) removed the old runner copy (Python tests 178 OK before and after).

## Blocked
- Nothing for C03 and C10. The supervisor review of what is realistic: the
  student decided to skip it.

## Next
- [x] C03 compared with Expat ([results](../../results/C03-chunks/README.md)).
- [x] C10 (part) compared with Expat ([results](../../results/C10-utf8/README.md)).
- [x] C02: the #38, #39, #40 reproductions are permanent regression tests ([#128](https://github.com/andersoxie/xpact/issues/128), [results](../../results/C02-final-input/README.md)); they fail when the fixes are undone.
