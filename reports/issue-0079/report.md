# Fix report: issue #79, parser conformance (W3C, #38, #39, #40, K3)

Issue: [#79](https://github.com/andersoxie/xpact/issues/79)   Branch: `fix/w3c-known-failures`   Base: `student-Mass` @ `63f67f3` (same code as `main` @ `cf12dee`)   Date: 2026-10-23

## In short

| | |
|---|---|
| 🔴 Problem | Jenkins on `main` ended in FAILURE at the W3C check: 236 wrong verdicts per build, 47 crashes with assertions on. The DLL tests (#37) showed #38, #39, #40; the assertions DLL smoke test crashed (K3) |
| ✔ Cause (confirmed) | No UTF-8 decoding; no UTF-16; DTD declarations not checked strictly; loops whose error branches do not advance; the #38 start-tag shortcut ran on the final call |
| 🔧 Fix | Parser fixes in `src/`, an empty-file fix in the benchmark harness, and a known-failures list for the W3C runner (now empty) |
| ✅ Verified | W3C 1,727/1,727 in both finalized builds; DLL tests 3,360/3,360 on both DLLs; every local Jenkins stage passes, including the assertions DLL smoke test |
| ⏳ Not verified | A Jenkins run (supervisor); the libexpat suite (no libexpat source here) |

## 1. Problem (error report)

- **Command:** `scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions`, the Jenkins "Benchmarks" stage.
- **Expected:** every applicable W3C case passes (1,727 per build).
- **Actual:** see [w3c-before-summary.md](w3c-before-summary.md) and the Jenkins log [jenkins-log-cf12dee-before.txt](jenkins-log-cf12dee-before.txt) (`Finished: FAILURE`).

| Build | Passed | Failed | Errors | Skipped |
|---|---:|---:|---:|---:|
| Finalized | 1,491 | 236 | 0 | 858 |
| FinalizedAssertions | 1,444 | 236 | 47 | 858 |

Of the 236: 220 accepted input that must be rejected, 16 rejected input that must be accepted. Jenkins and the student PC gave the same totals.

## 2. Causes and fixes

All parser changes are in `src/xp_parser.e` unless noted.

| # | Cause (confirmed by the fix) | Fix | Cases |
|---|---|---|---|
| 1 | Characters were checked byte by byte: invalid UTF-8, U+FFFE/FFFF and surrogates passed (#39) | `utf8_character_length` decodes strictly in `normalized_input`; a sequence cut off at the end of a prefix is kept for chunked parsing | ~20 W3C, 2,106 DLL |
| 2 | Names accepted every byte above 127 | `scan_name` decodes and applies the XML 1.0 fifth-edition NameStartChar/NameChar ranges | ~65 |
| 3 | UTF-16 with a byte-order mark was not supported; encoding declarations not checked | `decoded_input` converts UTF-16 (BOM) and declared ISO-8859-1/US-ASCII; BOM vs declaration and `EncName` are checked. The DLL layer converts itself, so it sets `set_input_is_utf8 (True)` | ~25 |
| 4 | DTD declarations: required spaces, attribute types, enumeration separators, mixed content, extra content after entity values were not checked | `skip_required_spaces`; strict `parse_attlist_type`, `append_attlist_group`, `parse_content_particle`; checks in entity, notation and DOCTYPE parsing | ~110 |
| 5 | Loops in DTD parsing set an error without advancing, which breaks the loop variant under assertions (47 crashes) | Error branches move the index to the end of the range | 47 |
| 6 | `SYSTEM ""` is valid, but contracts required a non-empty system id | `system_id_not_empty` removed in 6 places | 2 |
| 7 | DOCTYPE end scanning treated quotes in comments as literals ("can't" in a comment) | Comments and PIs are skipped in `find_doctype_end` and `find_subset_end` | 7 |
| 8 | Smaller rules: comments ending in `-`, `<?XML`, PI target spacing, `&#X..;`, space between attributes, `version="1.7"`, root-name check (a validity rule), PEs in internal subset declarations, content after `]` in DOCTYPE, unbound/`xmlns` element prefix without element events, colons in entity/notation/PI names, non-CDATA attribute normalization, entity that closes an element opened outside it, undeclared entity after a PE reference | One check each | ~25 |
| 9 | Empty files made the benchmark harness exit 2 | `benchmarks/xp_benchmark_root.e` reads 0 bytes as an empty document | 2 |
| 10 | #40: `find_markup_declaration_end` started past the end for the prefix `<` | Start index clamped | DLL |
| 11 | #38: the direct start-tag shortcut in `XP_NATIVE_PARSER` also ran on the final call, so the rest was never parsed | Shortcut only for non-final calls (`src/xp_native_parser.e`) | 24 + 30 DLL |
| 12 | K3: the DLL UTF-16 decoders set `Result := Void` without advancing; under assertions the loop variant failed at the "UTF-16BE bad surrogate" smoke case | Error branches advance (`src/xp_native_parser.e`) | smoke |

K3 was found by tracing every `XML_Parse` call of the smoke test ([k3-trace.h](k3-trace.h)): the original code crashes with `0xC0000028` ([k3-before-assertions-build.txt](k3-before-assertions-build.txt)), the first fixes moved the crash to `0xC00000FF` in the UTF-16 loop, and fix 12 removed it.

**W3C runner:** `scripts/run_w3c_conformance.py` gained `--known-failures` / `--write-known-failures`, and `run_benchmarks.ps1` passes `benchmarks/w3c-known-failures.tsv`. The list is **empty**: every failure fails the build, and a listed case that passes would too. See `docs/w3c-xml-conformance.md`.

**Existing tests kept:** messages and positions checked by `tests/xp_test_root.e` are unchanged (the "missing space" error is only used when a literal follows directly; asynchronous entities are reported at the entity reference).

## 3. Expected results (written before the final run)

| # | Check | Expected |
|---|---|---|
| 1 | W3C, both finalized builds | 1,727 passed, 0 failed, 0 errors |
| 2 | Eiffel test matrix, 4 lanes | `xpact Phase 1 tests: ok` |
| 3 | Both DLLs with smoke tests | `xpact Eiffel DLL smoke: ok` twice |
| 4 | DLL tests (#37), both DLLs | 3,360 pass, 0 crash |
| 5 | ABI, runtime smoke, chunked CRC, shim audit, contributed examples, Python tests | exit 0 |

## 4. Verification

Student PC: Windows 11, EiffelStudio 25.12.9.8922 Standard, VS 18 (MSVC 14.51), Python 3.10.6 and 3.13.14, .NET 10.0.302. One script ran every stage in order after the last code change: [final-steps.txt](final-steps.txt) (exit code per step), full output [final-run.txt](final-run.txt).

| # | Result | Evidence |
|---|---|---|
| 1 | Finalized and FinalizedAssertions: 1,727 passed, 0 failed, 0 errors, 858 skipped | [w3c-after-summary.md](w3c-after-summary.md) |
| 2 | all 4 lanes `ok` | final-run.txt |
| 3 | both smoke tests `ok` (the assertions one for the first time) | final-run.txt |
| 4 | 3,360 / 3,360 on each DLL, 0 crashes | [dll-tests-assertions-summary.txt](dll-tests-assertions-summary.txt), [dll-tests-production-summary.txt](dll-tests-production-summary.txt) |
| 5 | all exit 0; 28 Python tests | final-steps.txt |

All five expectations were met.

## 5. Limitations

- ⏳ Not run on Jenkins yet; the Jenkins machine uses EiffelStudio 25.02 Enterprise.
- Not run: the libexpat native suite and manifest (no libexpat 2.8.1 source on this PC), WSL rows of the benchmarks.
- Benchmark timings are from a different machine than Jenkins and cannot be compared with its earlier rows.
- Encodings other than UTF-8, UTF-16 (with BOM), ISO-8859-1 and US-ASCII are still read as UTF-8 by `XP_PARSER.parse` (unchanged behaviour).
- Separate open items: "Eiffel Tests" on Jenkins prints no test output; `tests/python/run_w3c_conformance.py` is an old copy of the runner; the C# DLL test README gives `bin\Release` instead of `bin\x64\Release`.

## How to revert

Revert the commits of this PR (`git revert <sha>` for each, newest first). The W3C check then fails again as on `cf12dee`.
