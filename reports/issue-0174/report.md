# Report: issue #174: `#FIXED` attribute default reported with `isrequired = 0`

> **Issue:** [#174](https://github.com/andersoxie/xpact/issues/174) G03-5 · AlotOfTests F04-1 · found by G03 ([#169](https://github.com/andersoxie/xpact/issues/169))
> **Branch:** `fix/174-fixed-default-isrequired`, from `student-Mass` @ `02a6575`
> **Changed:** `src/xp_parser.e` (4 lines), `src/xp_event_handler.e` (1 comment line)
> **Status:** ✅ cause confirmed · ✅ fixed · ✅ verified locally, both builds

## In short

Expat's `expat.h` says of `XML_AttlistDeclHandler`: *"for a `#FIXED` default, the default is passed **and `isrequired` is true**"*. xpact passed `isrequired = 0` for `#FIXED`, because it set the flag only for `#REQUIRED`.

| Default | Before | After | Expat 2.8.1 |
|---|---|---|---|
| `#REQUIRED` | ✅ NULL, 1 | ✅ NULL, 1 | NULL, 1 |
| `#IMPLIED` | ✅ NULL, 0 | ✅ NULL, 0 | NULL, 0 |
| `#FIXED 'v'` (CDATA and enumerated) | ❌ `'v'`, **0** | ✅ `'v'`, **1** | `'v'`, 1 |
| plain `'v'` | ✅ `'v'`, 0 | ✅ `'v'`, 0 | `'v'`, 0 |

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | the attlist declaration event reports `#FIXED` with `isrequired = 0` |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `02a6575`, EiffelStudio 25.12, Visual Studio 18 Community (MSVC), Python 3.14.0, .NET 10. Before: DLLs of `02a6575` (`xpact.dll` `6c593af8d4ce181c…`, `xpact_assertions.dll` `5488caa40859c94c…`). After: built in the `w10-attr-defaults` worktree with `scripts\build_native_eiffel.ps1 -BuildTier Production` and `-BuildTier Assertions`, smoke ok ([build log](logs/build-after-fix.txt)). Reference: `libexpat.dll` Expat 2.8.1 (`36a2532e2181ab8b…`). |
| **3. Command** | `python -I reports\issue-0174\tools\probe.py <xpact dll> <libexpat dll>` |
| **4. Expected** | `#FIXED`: the default and `isrequired = 1` |
| **5. Actual (before)** | `#FIXED`: the default and `isrequired = 0` ([probe before](logs/probe-before-assertions.txt): 3 / 5 the same as Expat) |
| **6. Error output** | none; the documents are accepted |
| **7. Investigation** | `xp_parser.e` (attlist parsing) sets `l_is_required := True` only for `#REQUIRED` and passes it to the event and to `record_attribute_decl`. Nothing in `src`, `tests` or `examples` reads `XP_ATTRIBUTE_DECL.is_required`. The C smoke test checks `#REQUIRED` (1) and a plain default (0), not `#FIXED`. |
| **8. Cause** | ✅ **confirmed**: `#FIXED` never set the flag the event uses |
| **9. Fix** | see "The change" |
| **10. Verification** | ✅ see below |

## The change

- `src/xp_parser.e`: a new local `l_is_fixed` is set for `#FIXED`. The event gets `l_is_required or l_is_fixed`. The parser's own declaration table keeps its meaning (`#REQUIRED` only), so nothing inside the parser changes.
- `src/xp_event_handler.e`: `on_attlist_decl` documents that `a_is_required` is True for `#REQUIRED` and `#FIXED`, as in Expat.

## Verification

| Check | Before | After | Log |
|---|---|---|---|
| ✅ DLL builds and smoke test | ok × 2 | ok × 2 | [build](logs/build-after-fix.txt) |
| ✅ Probe, 5 kinds of default, = Expat | 3 / 5 | **5 / 5**, both builds | [assertions](logs/probe-after-assertions.txt), [normal](logs/probe-after-normal.txt) |
| ✅ G03, 93 cases × 14 ways | 59 match | **60 match**: `valid-sa-079` "events differ" → match; no other case changed status, both builds | [assertions](logs/g03-after-assertions.txt), [runs](logs/g03-after-assertions/) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical per case**, both builds | [verdicts](logs/verdicts/) |
| ✅ W3C output test, 432 cases | 399 / 432 | **399 / 432, identical per case** | [after](logs/output-after-assertions/summary.json) |
| ✅ C# DLL tests vs Expat 2.8.1, 4,308 cases | 3,423 identical | **3,423, no case changed** | [normal](logs/csharp-vs-expat-normal.txt), [assertions](logs/csharp-vs-expat-assertions.txt) |
| ✅ Expat's C tests (`runtests`) | 399 checks, 38 expected failures | **the same**, exit 0 | [log](logs/expat-runtests.txt) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/eiffel-matrix.txt) |
| ✅ Python suite | 210 OK | **210 OK** | [log](logs/python-suite.txt) |
| ✅ Test 2, W3C in pieces, 2,585 documents | 2,561 stable | **2,561 stable, no document changed status**, both builds | [assertions](logs/chunked-fix174-assertions-summary.json), [normal](logs/chunked-fix174-normal-summary.json) |
| ✅ W3C benchmark stage, run locally (`run_benchmarks.ps1 -Iterations 1 -Repetitions 1 -SkipWslC -W3cAllCases`; rebuilds every program) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors**, both builds, exit 0 | [log](logs/w3c-benchmark-stage.txt) |
| ✅ Final DLLs (rebuilt by the benchmark stage, same source: `xpact.dll` `e388d706991f6583…`, `xpact_assertions.dll` `df28a15742d5cd98…`) | | probe **identical** | |

Tested on `02a6575` + this change. `student-Mass` has since gained #175 (`38aa67a`, entity and DOCTYPE system IDs), which touches other features of `xp_parser.e`; the merge combines both.

## Limitations

- `XP_ATTRIBUTE_DECL.is_required` still means `#REQUIRED` only. Nothing reads it today; if something does later, `#FIXED` will need its own flag there.
- Jenkins was not run (not needed, student decision 2026-10-31).

## Revert

`student\tools\fix.ps1 revert -Issue 174 -Commit <merged sha>`, or `git revert <sha>`.
