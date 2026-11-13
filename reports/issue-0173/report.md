# Report: issue #173: an error in the internal subset was reported before the declarations in front of it

> **Issue:** [#173](https://github.com/andersoxie/xpact/issues/173) G03-4 · found by G03 ([#169](https://github.com/andersoxie/xpact/issues/169))
> **Branch:** `fix/173-internal-subset-error-after-declarations`, from `student-Mass` @ `2ed37c5`
> **Changed:** `src/xp_parser.e` (the "unexpected content after internal subset" case, +17 lines)
> **Status:** ✅ cause confirmed · ✅ fixed · ✅ verified locally, both builds

## In short

`ibm51n06.xml` has a stray `]` inside an element declaration (`( #PCDATA | a ]* >`). Expat delivers the declarations in front of it (three `elementdecl`s and a comment), then error 2 at **7:33**, the `]`. xpact delivered none of them, and reported the error at **2:0**, the DOCTYPE line.

**Cause, ✅ confirmed:** `find_subset_end` takes the first `]` it finds outside literals and comments as the end of the internal subset. When the DOCTYPE's `>` does not follow it, xpact raised "unexpected content after internal subset" right there, before `process_internal_subset` ran on any declaration, and at the DOCTYPE's position.

**The fix:** in that case, the complete declarations in front of that `]` are processed first with `process_internal_subset_prefix` (already used for an unfinished DOCTYPE), then the error is raised. The position is the one Expat uses:
- if everything in front of the `]` was complete declarations, the `]` ends the subset, and the error is at the content after it (`] junk` → the `j`);
- otherwise the `]` is inside a declaration, and the error is at the `]` itself.

| Probe document (whole and byte by byte) | Before | After |
|---|---|---|
| `ibm51n06.xml` | ❌ no declarations, 2:0 | ✅ = Expat: declarations, then 2 at 7:33 |
| stray `]` inside an element declaration | ❌ | ✅ = Expat |
| `] junk ]>` (`]` between declarations, then junk) | ❌ | ✅ = Expat (position at the junk) |
| `]x>` | ❌ | ✅ = Expat |
| valid subset (control) | ✅ | ✅ |
| **total** | **2 / 10** | ✅ **10 / 10** |

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | an error inside the internal subset is reported at the DOCTYPE line, before the declarations in front of it |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `2ed37c5`, EiffelStudio 25.12, Visual Studio 18 Community (MSVC), Python 3.14.0, .NET 10. Before: DLLs of `02a6575` + #174 (`xpact.dll` `e388d706991f6583…`, `xpact_assertions.dll` `df28a15742d5cd98…`, in `xpactGit\build\fix173\baseline`); they do not have #175, see below. After: built in the `w10-attr-defaults` worktree from `2ed37c5` + this change, `scripts\build_native_eiffel.ps1 -BuildTier Production` and `-BuildTier Assertions`, smoke ok ([build log](logs/build-after-fix.txt)). Reference: `libexpat.dll` Expat 2.8.1 (`36a2532e2181ab8b…`). |
| **3. Command** | `python -I reports\issue-0173\tools\probe.py <xpact dll> <libexpat dll> <path to ibm51n06.xml>` |
| **4. Expected** | `xmldecl, startdoctype, elementdecl root, elementdecl a, elementdecl b, comment`, then error 2 at 7:33 |
| **5. Actual (before)** | `xmldecl, startdoctype`, then error 2 at 2:0 ([probe before](logs/probe-before-assertions.txt)) |
| **6. Error output** | none; the verdict and the error code were right |
| **7. Investigation** | `xp_parser.e`, DOCTYPE parsing: `find_subset_end`; when the DOCTYPE's `>` does not follow it, `set_error ("unexpected content after internal subset")` is raised before any subset processing. The first fix build matched Expat on 6 / 10 probe rows; the two `]`-then-junk documents showed Expat points at the content after a `]` that ends the subset, which gave the position rule above. |
| **8. Cause** | ✅ **confirmed** |
| **9. Fix** | see above |
| **10. Verification** | ✅ see below |

## Verification

| Check | Before | After | Log |
|---|---|---|---|
| ✅ DLL builds and smoke test | ok × 2 | ok × 2 | [build](logs/build-after-fix.txt) |
| ✅ Probe, 10 rows, = Expat | 2 / 10 | **10 / 10**, both builds identical | [before](logs/probe-before-assertions.txt), [after](logs/probe-after-assertions.txt), [normal](logs/probe-after-normal.txt) |
| ✅ G03, 93 cases × 14 ways | 60 match | **62 match**: `ibm-not-wf-P51-ibm51n06.xml` "events differ" → match (this fix); `ibm-valid-P11-ibm11v02.xml` "events differ" → match (from #175, which the baseline DLLs do not have); no other case changed, both builds | [assertions](logs/g03-after-assertions.txt), [runs](logs/g03-after-assertions/) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical per case**, both builds | [verdicts](logs/verdicts/) |
| ✅ W3C output test, 432 cases | 399 / 432 | **399 / 432, identical per case** | [after](logs/output-after-assertions/summary.json) |
| ✅ C# DLL tests vs Expat 2.8.1, 4,308 cases | 3,423 identical | **3,423, no case changed** | [normal](logs/csharp-vs-expat-normal.txt), [assertions](logs/csharp-vs-expat-assertions.txt) |
| ✅ Expat's C tests (`runtests`) | 399 checks, 38 expected failures | **the same**, exit 0 | [log](logs/expat-runtests.txt) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/eiffel-matrix.txt) |
| ✅ Python suite | 210 OK | **210 OK** | [log](logs/python-suite.txt) |
| ⏭️ Test 2, W3C in pieces | | **skipped** (student decision 2026-10-31: not run for fixes that do not change how input arrives in pieces). Pieces are covered by the probe (byte by byte, 10 / 10) and by G03 (every case in 14 ways of feeding) | |
| ✅ W3C benchmark stage, run locally (`run_benchmarks.ps1 -Iterations 1 -Repetitions 1 -SkipWslC -W3cAllCases`; rebuilds every program) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors**, both builds, exit 0 | [log](logs/w3c-benchmark-stage.txt) |
| ✅ Final DLLs (rebuilt by the benchmark stage, same source: `xpact.dll` `a4318f448d613b1d…`, `xpact_assertions.dll` `a317701c3565cac4…`) | | probe **identical** | |

## Limitations

- The "unterminated internal subset" case (no `]` at all) is not changed.
- The probe records entity declarations and comments; element declarations are checked by G03 (`ibm51n06.xml` matches there).
- Jenkins was not run (not needed, student decision 2026-10-31).

## Revert

`student\tools\fix.ps1 revert -Issue 173 -Commit <merged sha>`, or `git revert <sha>`.
