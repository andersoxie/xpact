# Report: issue #124: text after the document element gave error 4, not 9

> **Issue:** [#124](https://github.com/andersoxie/xpact/issues/124) · found by the C# DLL tests against Expat 2.8.1 (#121)
> **Branch:** `fix/124-junk-after-document-element`, from `student-Mass` @ `38aa67a`
> **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e` (2 lines), `tests/xp_test_root.e` (4 new assertions)
> **Status:** ✅ cause confirmed · ✅ fixed · ✅ verified locally, both builds

## In short

Text after the document element (`<root/>junk`) is Expat's error **9, "junk after document element"**. xpact said **4, "invalid token"**. With element callbacks set, the position also moved to the end of the junk, and with them not set it stayed at its start.

**Cause, ✅ confirmed:** xpact raised one message, "character data outside document element", for text **before and after** the root. The DLL had no entry for that message, so it fell through to 4. Two of the four places that raise it noted the position at the first non-space character; the other two noted it only after the whole text was read. `]]>` after the root gave "CDATA close marker", also code 4, where Expat gives 9.

**The fix:** one helper, `set_outside_document_text_error`, used at all four places and at the three `]]>` places when they are after the root. It notes the position at the first non-space character, and gives "junk after document element" (code 9) after the root and the old message (code 4) before it.

| Result | Before | After |
|---|---|---|
| C# DLL tests, error code = Expat (4,308 cases) | 4,236 | ✅ **4,308** (the 72 cases of this issue; 0 worse) |
| C# DLL tests, column and byte index = Expat | 4,251 | ✅ **4,308** (0 worse) |
| C# DLL tests, every field = Expat | 3,423 | ✅ **3,489** |
| Probe, 52 rows (whole and byte by byte, with and without callbacks) | 9 / 52 | ✅ **30 / 52** (22 better, 1 worse, see Limitations) |

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | text after the document element is error 4, not 9; its position depends on whether callbacks are set |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `38aa67a`, EiffelStudio 25.12, Visual Studio 18 Community (MSVC), Python 3.14.0, .NET 10. Before: DLLs of `38aa67a` (`xpact.dll` `fe37de50f7d84611…`, `xpact_assertions.dll` `691131ca94a4e911…`, in `xpactGit\build\fix124\baseline`). After: built in the `w11-plan` worktree with `scripts\build_native_eiffel.ps1 -BuildTier Production` and `-BuildTier Assertions`, smoke ok ([build log](logs/build-after-fix.txt)). Reference: `libexpat.dll` Expat 2.8.1 (`36a2532e2181ab8b…`). |
| **3. Command** | `python -I reports\issue-0124\tools\probe.py <xpact dll> <libexpat dll>`; the C# DLL tests (`XpactDllTests --dll … --out …`, compared with `reports\issue-0172\tools\csharp_vs_expat.py`) |
| **4. Expected** | `<root/>junk`: error 9 at 1:7, with every callback set and every chunking (Expat 2.8.1) |
| **5. Actual (before)** | error 4 at 1:7 without callbacks, at 1:10 with them ([probe before](logs/probe-before-assertions.txt)) |
| **6. Error output** | none; the verdict is right |
| **7. Investigation** | Expat gives 9 for any text or `]]>` after the root (whole, byte by byte, with and without callbacks), and 4 for text before the root. In `xp_native_parser.e`, `error_code_for` maps "multiple document elements" to 9, but not "character data outside document element". In `xp_parser.e`, that message is raised in `parse_character_data`, `parse_character_data_no_events` (2×) and `parse_character_data_prefix`. |
| **8. Cause** | ✅ **confirmed**, see above |
| **9. Fix** | see above |
| **10. Verification** | ✅ see below |

## Verification

| Check | Before | After | Log |
|---|---|---|---|
| ✅ DLL builds and smoke test | ok × 2 | ok × 2 | [build](logs/build-after-fix.txt) |
| ✅ Probe, 52 rows, = Expat | 9 / 52 | **30 / 52**, both builds identical | [before](logs/probe-before-assertions.txt), [after](logs/probe-after-assertions.txt), [normal](logs/probe-after-normal.txt) |
| ✅ C# DLL tests vs Expat 2.8.1 | error code 4,236; column 4,251; all fields 3,423 | **4,308; 4,308; 3,489**, 0 worse in any field, both builds | [normal](logs/csharp-vs-expat-normal.txt), [assertions](logs/csharp-vs-expat-assertions.txt) |
| ✅ G03, 93 cases × 14 ways | 60 match | **60, no case changed** (none has text after the root) | [assertions](logs/g03-after-assertions.txt) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical per case**, both builds | [verdicts](logs/verdicts/) |
| ✅ W3C output test, 432 cases | 399 / 432 | **399 / 432, identical per case** | [after](logs/output-after-assertions/summary.json) |
| ✅ Expat's C tests (`runtests`) | 399 checks, 38 expected failures | **the same**, exit 0 | [log](logs/expat-runtests.txt) |
| ✅ Eiffel test matrix (with the new assertions: `<a/>text` and `<a/> ]]>` give "junk after document element") | 4 / 4 | **4 / 4** | [log](logs/eiffel-matrix.txt) |
| ✅ Python suite | 210 OK | **210 OK** | [log](logs/python-suite.txt) |
| ✅ Test 2, W3C in pieces, 2,585 documents | 2,561 stable | **2,561 stable, no document changed status**, both builds | [assertions](logs/chunked-fix124-assertions-summary.json), [normal](logs/chunked-fix124-normal-summary.json) |
| 🟡 W3C benchmark stage | | run once per batch on `student-Mass` after several fixes are merged (student decision 2026-10-31); recorded in the batch report | |

## Limitations

- **One probe row got worse:** `<root/> a]]>` given whole with callbacks. Expat itself is not consistent there: whole it says 4 at 1:9, byte by byte 9 at 1:8. Before, xpact matched the whole case by accident; now it gives 9 at 1:8 in every mode, as Expat does byte by byte. Of that document's four rows, 2 match now, 1 before.
- **Text before the root:** the code (4) was and is the same as Expat's. The position differs: Expat points at the end of the text, xpact at its first character. With callbacks set it moved from near the end to the first character (both differ from Expat). Matching Expat there needs the parser to wait for the end of the text in pieces; that is position work and belongs to [#171](https://github.com/andersoxie/xpact/issues/171).
- `<r>]]></r>` (inside the root) is not changed: code 4 as Expat, position 1:3 vs Expat 1:5, also #171.
- Jenkins was not run (not needed, student decision 2026-10-31).

## Revert

`student\tools\fix.ps1 revert -Issue 124 -Commit <merged sha>`, or `git revert <sha>`.
