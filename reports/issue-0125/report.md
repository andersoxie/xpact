# Report: issue #125: the default handler got a mismatched end tag before the error

> **Issue:** [#125](https://github.com/andersoxie/xpact/issues/125) · found by the C# DLL tests against Expat 2.8.1 (#121)
> **Branch:** `fix/125-default-handler-mismatched-end-tag`, from `student-Mass` @ `38aa67a`
> **Changed:** `src/xp_parser.e` (one condition, 5 lines with its comment)
> **Status:** ✅ cause confirmed · ✅ fixed · ✅ verified locally, both builds

## In short

With only a default handler set, `<root><child></root>` gave `default:<root>`, `default:<child>`, **`default:</root>`**, then error 7 (mismatched tag). Expat gives the first two, then the error: a mismatched end tag is an error before anything is delivered for it. With element handlers set, xpact was already right, because the end tag does not go to the default handler then.

**Cause, ✅ confirmed:** in the end-tag parser (`xp_parser.e`, after the `>` of the end tag), the default text was emitted before `close_element` checked the name. The match is already computed two lines above, for the error position.

**The fix:** the end tag reaches the default handler only when it closes the open element (`open_element_matches_range`) and does not close an element opened outside the current entity (`entity_element_floor`, which raises "asynchronous entity").

| Result | Before | After |
|---|---|---|
| Probe, 4 documents × whole / bytes × default only / with element handlers | 8 / 16 | ✅ **16 / 16** |
| C# DLL tests, events = Expat (4,308 cases) | 4,114 | ✅ **4,135**: the 21 cases of this issue; 0 worse |

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | the default handler receives a mismatched end tag before the error |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `38aa67a`, EiffelStudio 25.12, Visual Studio 18 Community (MSVC), Python 3.14.0, .NET 10. Before: DLLs of `38aa67a` (`xpact.dll` `fe37de50f7d84611…`, `xpact_assertions.dll` `691131ca94a4e911…`, `build\fix124\baseline`). After: `scripts\build_native_eiffel.ps1 -BuildTier Production` and `-BuildTier Assertions`, smoke ok ([build log](logs/build-after-fix.txt)). Reference: `libexpat.dll` Expat 2.8.1 (`36a2532e2181ab8b…`). |
| **3. Command** | `python -I reports\issue-0125\tools\probe.py <xpact dll> build\libexpat-R_2_8_1\build\libexpat.dll` |
| **4. Expected** | `default:<root> · default:<child>`, then error 7 at 1:15 |
| **5. Actual (before)** | `default:<root> · default:<child> · default:</root>`, then error 7 at 1:15 ([probe before](logs/probe-before-assertions.txt)) |
| **6. Error output** | none; the error code and position were right |
| **7. Investigation** | all 4 documents (`<root><child></root>`, `<a></b>`, `<a>t</b>`, `<a><b></a></b>`) differ only with the default handler alone, whole and byte by byte. `wants_end_element_default` is used in one place only. |
| **8. Cause** | ✅ **confirmed** |
| **9. Fix** | see above |
| **10. Verification** | ✅ see below |

## Verification

| Check | Before | After | Log |
|---|---|---|---|
| ✅ DLL builds and smoke test | ok × 2 | ok × 2 | [build](logs/build-after-fix.txt) |
| ✅ Probe, 16 rows, = Expat | 8 / 16 | **16 / 16**, both builds identical | [before](logs/probe-before-assertions.txt), [after](logs/probe-after-assertions.txt), [normal](logs/probe-after-normal.txt) |
| ✅ C# DLL tests vs Expat 2.8.1 | events 4,114; all fields 3,423 | **4,135; 3,444**, 21 changed, 0 worse, both builds | [normal](logs/csharp-vs-expat-normal.txt), [assertions](logs/csharp-vs-expat-assertions.txt) |
| ✅ G03, 93 cases × 14 ways | 60 match | **60, no case changed** | [assertions](logs/g03-after-assertions.txt) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical per case**, both builds | [verdicts](logs/verdicts/) |
| ✅ W3C output test, 432 cases | 399 / 432 | **399 / 432, identical per case** | [after](logs/output-after-assertions/summary.json) |
| ✅ Expat's C tests (`runtests`) | 399 checks, 38 expected failures | **the same**, exit 0 | [log](logs/expat-runtests.txt) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/eiffel-matrix.txt) |
| ✅ Python suite | 210 OK | **210 OK** | [log](logs/python-suite.txt) |
| ✅ Test 2, W3C in pieces, 2,585 documents | 2,561 stable | **2,561 stable, no document changed status**, both builds | [assertions](logs/chunked-fix125-assertions-summary.json), [normal](logs/chunked-fix125-normal-summary.json) |
| 🟡 W3C benchmark stage | | run once per batch on `student-Mass` after several fixes are merged (student decision 2026-10-31); recorded in the batch report | |

## Limitations

- An end tag that closes an element across an entity boundary ("asynchronous entity") is now also kept from the default handler; the probe does not cover that case.
- Jenkins was not run (not needed, student decision 2026-10-31).

## Revert

`student\tools\fix.ps1 revert -Issue 125 -Commit <merged sha>`, or `git revert <sha>`.
