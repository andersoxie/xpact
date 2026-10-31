# Report: issue #172: a whole document gives no events before a forbidden character

> **Issue:** [#172](https://github.com/andersoxie/xpact/issues/172) F02-2 · G03-3 · found by G03 ([#169](https://github.com/andersoxie/xpact/issues/169)) and by the W3C-in-pieces test ([#165 report](../issue-0165/report.md), 139 documents)
> **Branch:** `fix/172-whole-document-events-before-char-error`, from `student-Mass` @ `5af2321`
> **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e` (+56 lines, no line removed)
> **Status:** ✅ cause confirmed · ✅ fixed · ✅ verified locally, both builds

## In short

Before xpact parsed anything, `normalized_input` (`src/xp_parser.e`) checked every character of the **whole** input and stopped at the first one that is not an XML `Char`. A document given whole therefore failed before its first callback. In pieces, the bad character was not in the buffer yet when the start tag was parsed, so `start doc` came first. Expat checks characters as it reads, so it gives the events in front of the character every time.

**The fix:** when that check stops a document parse in the DLL, xpact remembers **where** it stopped. It parses the text in front of the character as an unfinished piece (the same code path a split input uses), then reports the error. A normal document costs nothing extra; only this error path parses a second time.

| Result | Before | After |
|---|---|---|
| Probe, 7 documents: events, whole = split = Expat | ❌ 0 / 7 whole | ✅ **7 / 7** |
| Probe: error position = Expat | ❌ 1 / 7 (always 1:0) | ✅ **6 / 7** (UTF-16 is 1 column off, see Limitations) |
| G03: `o-p02fail15`, `o-p02fail27` | "events differ" | ✅ events match; "error position differs" (the UTF-16 column) |
| G03: xpact the same in all 14 ways of feeding | 90 / 93 | ✅ **92 / 93**, as Expat |
| Test 2, W3C in pieces: documents stable in every split | 2,438 | ✅ **2,561** (+123, 0 worse) |
| C# DLL tests, every field = Expat 2.8.1 (4,308 cases) | 1,079 | ✅ **3,423** (0 worse in any field) |

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | a document parsed whole reports no events before an error for a forbidden character; in pieces it does, as Expat does in every mode |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `5af2321`, EiffelStudio 25.12, Visual Studio 18 Community (MSVC), Python 3.14.0, .NET 10. Before: DLLs built from source identical to `5af2321` (no parser source changed since `f985102`), kept in `build\fix172\baseline`. After: `scripts\build_native_eiffel.ps1 -BuildTier Production` and `-BuildTier Assertions`, finalized, smoke ok ([build log](logs/build-after-fix.txt)). Reference: `libexpat.dll` Expat 2.8.1 (`R_2_8_1`, SHA-256 `36a2532e2181ab8b…`, the same as in G03). |
| **3. Command** | `python -I reports\issue-0172\tools\probe.py <xpact dll> build\libexpat-R_2_8_1\build\libexpat.dll`; `python -I student\results\G03-comparison\compare.py --tag <tag> --xpact-dll <dll>`; the others under Verification |
| **4. Expected** | the events in front of the forbidden character, then error 4, as Expat |
| **5. Actual (before)** | whole: no events, error 4 at 1:0 |
| **6. Error output** | none; the verdict was right ([probe before](logs/probe-baseline-assertions.txt)) |
| **7. Investigation** | see below |
| **8. Cause** | ✅ **confirmed** |
| **9. Fix** | see "The change" |
| **10. Verification** | ✅ see below; both builds give identical results in every check |

## Investigation

1. **Baseline, G03** ([assertions log](logs/baseline-compare-assertions.txt), [normal log](logs/baseline-compare-normal.txt), [runs](logs/g03-baseline/)): `o-p02fail15` and `o-p02fail27` show "events differ". The assertions run has the same 34 differing cases as the committed G03 run.
2. **Where the error comes from:** "invalid XML character" is raised in about 20 places, but only `normalized_input` runs **before** parsing. All 9 parse entry points call it on their whole input. The UTF-16 decoder does not check `Char` at all.
3. **Experiment** ([tools/probe.py](tools/probe.py), [before](logs/probe-baseline-assertions.txt)): 7 small documents with a forbidden character (in content, after a child, in an attribute, in a comment, before and after the root, UTF-16LE). xpact split right before the character gave **exactly Expat's events in all 7**; whole, it gave none.

**Cause, ✅ confirmed:** the whole-input character check raises the error before any callback. The same parser fed the same bytes, cut at the character, delivers Expat's events.

## The change

`src/xp_parser.e`:
- `normalized_input` records where it stopped (`last_invalid_character_index`), but only for input it did not convert, so the index is valid in the caller's input.
- `parse`, `parse_prefix` and the cached-DOCTYPE path of `parse_with_cached_doctype` copy that index into `invalid_input_character_index` right after their own check. Later checks of entity text can therefore not overwrite it. `reset` clears it.
- New, for the native layer only: `parse_prefix_before_invalid_character (input, index)` parses the text in front of the character with `parse_prefix` (non-final), then raises "invalid XML character".

`src/xp_native_parser.e`, document path only:
- If the parse failed (not suspended) and `invalid_input_character_index` is set, it parses again with `parse_prefix_before_invalid_character`.
- Callbacks the failed attempt already delivered are not repeated. The replay suppresses `delivered_callback_count.max (handler.callback_sequence_count)` callbacks, the same rule as #165.

Not changed: external entities, DTD subsets, and the Eiffel API's own `parse` (the probe covers the DLL).

## Verification

Before = `build\fix172\baseline` DLLs; after = the fixed DLLs. Both builds were run in each check, and they agree case by case everywhere.

| Check | Before | After | Log |
|---|---|---|---|
| ✅ DLL builds and smoke test | ok × 2 | ok × 2 | [build](logs/build-after-fix.txt) |
| ✅ Probe, 7 documents (events whole = split = Expat) | 0 / 7 | **7 / 7**; position 6 / 7 | [after, assertions](logs/probe-after-assertions.txt), [normal](logs/probe-after-normal.txt) |
| ✅ G03, 93 cases × 14 ways | 59 match; 90 stable | **59 match** (2 changed: "events differ" → "error position differs"); **92 stable** = Expat; no other case changed status | [assertions](logs/after-compare-assertions.txt), [normal](logs/after-compare-normal.txt), [runs](logs/g03-after-assertions/) |
| ✅ **Test 2, W3C in pieces**, 2,585 documents | 2,438 stable, 142 xpact-only | **2,561 stable, 19 xpact-only**; 123 better, **0 worse** | [assertions](logs/chunked-fix172-assertions-summary.json), [normal](logs/chunked-fix172-normal-summary.json), [per case](logs/chunked-fix172-assertions.tsv); before: [#165 after](../issue-0165/logs/test2/chunked-fix165-assertions-summary.json) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical per case** | [verdicts](logs/verdicts/) |
| ✅ W3C output test, 432 cases | 399 / 432 | **399 / 432, identical per case** | [before](logs/output-baseline-assertions/summary.json), [after](logs/output-after-assertions/summary.json), [normal](logs/output-after-normal/summary.json) |
| ✅ C# DLL tests, 4,308 cases | 4,308 pass | **4,308 pass**; vs Expat, see below | [vs Expat, normal](logs/csharp-vs-expat-normal.txt), [assertions](logs/csharp-vs-expat-assertions.txt) |
| ✅ Expat's C tests (`runtests`) | 399 checks, 38 expected failures | **the same 38**, exit 0 | [log](logs/expat-runtests.txt) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/eiffel-matrix.txt) |
| ✅ Python suite | 210 OK | **210 OK** | [log](logs/python-suite.txt) |
| ✅ W3C benchmark stage, run locally (`run_benchmarks.ps1 -Iterations 1 -Repetitions 1 -SkipWslC -W3cAllCases`; rebuilds every program with the change) | 2,283 + 302, 0 failed | **2,283 checked + 302 no crash only, 0 failed, 0 errors**, both builds, exit 0 | [log](logs/w3c-benchmark-stage.txt) |
| ✅ Final DLLs (rebuilt by the benchmark stage, same source: `xpact.dll` `6c593af8d4ce181c…`, `xpact_assertions.dll` `5488caa40859c94c…`) | | probe and all-W3C DLL verdicts **identical** to the runs above | |

**C# DLL tests against Expat 2.8.1** ([tool](tools/csharp_vs_expat.py)): a case counts as "= Expat" when its field is the same as Expat's run.

| Field | = Expat before | = Expat after | Better | Worse |
|---|---:|---:|---:|---:|
| verdict, error code, line, failed call, calls | unchanged | unchanged | 0 | 0 |
| column, byte index | 1,155 | **4,251** | 3,096 | **0** |
| events | 3,649 | **4,114** | 465 | **0** |
| all fields | 1,079 | **3,423** | | |

## Effect on other issues (kept separate)

The same up-front check also stops malformed UTF-8, so this fix changes two other findings. They stay open; their closing is decided on their own evidence.
- [#122](https://github.com/andersoxie/xpact/issues/122), malformed UTF-8 reported at 1:0: the issue's 3,096 C# cases are **all** at Expat's position now.
- [#123](https://github.com/andersoxie/xpact/issues/123), no events before malformed UTF-8: 598 cases before, **133** now. All 133 are CDATA with the default handler, where Expat delivers `<![CDATA[` before the bad byte and xpact holds the unfinished CDATA opening back.

## Problems met (kept separate)

- **Benchmark stage while test 2 was running:** the first run of the W3C benchmark stage failed with `LNK1104: cannot open file …\xpact_assertions.dll`. The stage rebuilds the DLLs, and test 2 had that DLL loaded. **Cause, ✅ confirmed:** my own scheduling (environment), not the fix. It was rerun after test 2 ([failed run](logs/w3c-benchmark-stage-failed-dll-in-use.txt)). That run had already rebuilt `xpact.dll` from the same source; the later checks used DLLs built from identical source.

## Limitations

- **UTF-16 column:** for `o-p02fail15`-like input, xpact says 1:5 and Expat 1:6; Expat seems to count the byte-order mark. This belongs to [#171](https://github.com/andersoxie/xpact/issues/171) and is not checked here.
- **19 xpact-only documents** remain in test 2 (`not-wf-sa-010`, `not-wf-sa-025`, `pr-xml-*` ×3, `o-p18fail3`, `o-p68fail1-3`, `ibm-not-wf-P14-ibm14n03`, `ibm-not-wf-P68-ibm68n01/03`, `ibm-1-1-valid-P02-ibm02v02/05`, `hst-bh-001…004`, `hst-lhs-009`). Their cause is ❔ **unknown**. They are not forbidden-character errors of the main document, which this fix covers.
- External entities, DTD subsets and the Eiffel `parse` API keep the old behavior.
- Jenkins was not run (not needed, student decision 2026-10-31).

## Revert

`student\tools\fix.ps1 revert -Issue 172 -Commit <merged sha>`, or `git revert <sha>`.
