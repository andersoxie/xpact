# Four-way comparison: xpact vs expat vs Gobo vs xpact-core, plus Gobo's own XML parser (23 November 2026)

**What:** the latest xpact (`main` @ `2862a18`) against libexpat, xpact compiled by the Gobo Eiffel compiler, and the pinned xpact-core, on every available test suite.
**Where:** `reports/four-way-2026-11-23/`. **Final numbers come from the one-command run in [scripted-run/](scripted-run/)** (`benchmarks/four_way/run_four_way.ps1`, 22 minutes); the earlier manual run is kept for history in the sibling folders.
Tables: [W3C four-way](scripted-run/w3c-four-way.md) · [expat lenient cases](scripted-run/w3c/expat-lenient-cases.md) · [steps and exit codes](scripted-run/logs/00-steps.tsv) · [logs](scripted-run/logs/)

## 1. Summary

**Legend:** ✅ passed · ❌ failed · 🚫 no result (not run / not applicable — the footnote says why)

| Test | xpact (EiffelStudio) | xpact (Gobo) | expat | xpact-core | Gobo XML parser ⁴ |
|---|---|---|---|---|---|
| **W3C conformance, profile** (1,974 cases run, same 611 excluded for all) | ✅ **1,974 / 1,974** | ✅ **1,974 / 1,974** | 1,655 (83.8%) | 1,232 (62.4%) + 14 errors | 1,910 (96.8%), 64 failed |
| **W3C conformance, all 2,585 cases** | ✅ **0 failed, 0 errors** | 🚫 not available ³ | 🚫 not available ³ | 🚫 not available ³ | legacy names 9/309 ❌, XML 1.1 274/274, optional errors 28/28 |
| **Regression** (910 runs: whole, every split point, byte by byte) | ✅ **910 / 910** | 909 / 910 + 10/10 lifecycle ¹ | ✅ **910 / 910** ² | 887 / 910 | 🚫 not run (no trace engine) |
| **libexpat 2.8.1 unit suite** through xpact's libexpat ABI | ✅ gate passed (361/399, 38 listed expected failures) | 🚫 not run ⁵ | reference | 🚫 not applicable ⁶ | 🚫 not applicable ⁶ |
| **Speed, same Linux machine** (µs per document, lower is better) | 98.4 | 90.3 | **19.6** | 40.4 | ≈ 4–9× slower than xpact (25–34× on DTD-heavy files) ⁴ |
| **Large file** (whole-file parse) | ✅ all xpact engines at 5 MB; ❌ native C ABI "out of memory" from 10 MB | 🚫 not run ⁵ | ✅ | 🚫 not run ⁷ | ✅ up to 20 MB, but slower (2–8× xpact) ⁴ |
| **xpact's own test sets** | 8 of 9 ✅; test matrix ❌ one doc assertion in all 4 modes | 🚫 not run ⁵ | 🚫 not applicable ⁸ | 🚫 not applicable ⁸ | 🚫 not applicable ⁸ |

¹ The one failure is the **test harness**, not the parser: Gobo's `RAW_FILE.read_stream` refuses an empty file (`is_readable` precondition) before the parser is called.
² expat has no equivalent of the 10 lifecycle steps (their inputs live inside the Eiffel harness).
³ All-cases mode needs an entity checker built against the parser's native DLL; only xpact has one.
⁴ **Gobo XML parser** = Gobo's own Eiffel parser `XM_EIFFEL_PARSER` (Gobo 26.11), not xpact compiled by Gobo. Numbers come from the earlier committed run [reports/gobo-xml-2026-11-18/](../gobo-xml-2026-11-18/results.md) (commit `d3e4b92`, #442), not from today's script; same W3C profile, speed on a separate per-file workload (see §4.7).
⁵ **Not run with the Gobo build:** these scripts (`run_libexpat_adapter`, `run_large_xml_benchmarks`, `run_eiffel_test_matrix` and the other test-set scripts) only build with EiffelStudio on Windows; the repo has no Gobo build for them. Same source code, so the result is expected to match (suspected, not tested).
⁶ **Not applicable:** the libexpat suite calls a libexpat-compatible C interface. Only xpact has one; xpact-core and the Gobo XML parser are Eiffel libraries without it.
⁷ **Not run:** `run_large_xml_benchmarks.ps1` measures only xpact's engines; it has no xpact-core option.
⁸ **Not applicable:** these are xpact's own unit/integration tests, written against xpact's code; they cannot run on another parser.

**Main findings**
1. ✅ **xpact is the only parser with zero conformance failures** — in the profile and in all 2,585 cases — and the Gobo build gives exactly the same verdicts.
2. **expat** is correct on every regression event stream; its 319 W3C failures are 318 XML 1.0 **5th-edition** names it rejects (it uses 4th-edition rules — confirmed) plus 1 accepted case (`hst-lhs-007`, UTF-8 BOM with an ISO-8859-1 declaration).
3. **xpact-core** is the least correct (728 W3C failures + 14 errors, 23 regression verdicts) but **≈ 2.4× faster than xpact** (Linux 40.4 vs 98.4 µs/doc; Windows ratio 2.05).
4. **libexpat C is ≈ 5× faster than xpact**, 2× faster than xpact-core. Gobo-built xpact is ≈ 8% faster than EiffelStudio-built xpact.
5. **Gobo's own XML parser** fails 64 core W3C cases and 300 of 309 legacy-name cases, is ≈ 4–9× slower than xpact, and times out or crashes on 4 attack/limit inputs (billion laughs, quadratic blowup, 100k entity chain, 1M-deep nesting) that xpact rejects safely or handles (§4.7).
6. ❌ Two problems on xpact `main`: the Eiffel test matrix fails one **documentation** assertion in every mode (§4.5), and the **native C ABI cannot parse a whole file of 10 MB or more** (§4.6).

## 2. Environment

| Item | Value |
|---|---|
| Machine | Windows 11 Home 10.0.26300; WSL2 Ubuntu 24.04 (glibc 2.39) on the same machine |
| xpact / xpact-core | `main` @ `2862a1802b11` (branch `work/four-way-compare`) / pinned `6c017fb5b6e0` |
| Windows | EiffelStudio 25.12 Standard, MSVC 19.51 (Visual Studio 2026) and its CMake, Python 3.15 (uv) |
| Linux | EiffelStudio 25.12 rev 98922, Gobo `gec` 26.11.14+55e703f, gcc 13.3.0, Python 3.12 |
| expat | Windows libexpat **2.8.5** (CPython `pyexpat`); Linux libexpat **2.6.1** (`pyexpat` and C) |
| Suites | W3C xmlts 20130923; libexpat tests `R_2_8_1`; regression cases of `scripts/run_dual_regression.py` |
| Assertions | dual W3C full catalog on assertions-off builds with assertions-on directed controls (runner design); regression on both; Gobo W3C/regression binaries assertions on; speed builds assertions off |

## 3. How it was run
One command: `.\benchmarks\four_way\run_four_way.ps1` (Windows lanes, then `benchmarks/four_way/wsl_four_way.sh` in WSL). Every step and its exit code: [00-steps.tsv](scripted-run/logs/00-steps.tsv). Exit 1 of `03-dual-w3c` means "parser gaps recorded" (xpact-core); exit 1 of the test-matrix steps is §4.5.

**Same cases for everyone:** Gobo and expat run the exact case list, expected verdicts and exclusions of the dual-W3C run (`suite-manifest.json`) and the official regression cases and `judge()` rule, through the runners' own protocols. expat reads external entities and the external DTD subset from inside the suite folder (standard `ExternalEntityRefHandler`), like the Eiffel engines under this profile.

## 4. Results in detail

### 4.1 W3C conformance (XML 1.0 5th edition, namespaces unless NAMESPACE=no, non-validating)
| Parser | Passed | Failed | Errors | Too lenient | Too strict |
|---|---:|---:|---:|---:|---:|
| xpact (EiffelStudio) | 1,974 | 0 | 0 | 0 | 0 |
| xpact (Gobo) | 1,974 | 0 | 0 | 0 | 0 |
| expat 2.8.5 / 2.6.1 (identical) | 1,655 | 319 | 0 | 1 | 318 |
| xpact-core | 1,232 | 728 | 14 | 400 | 328 |

| expat problem | Investigation | Cause |
|---|---|---|
| 318 valid documents rejected (`not well-formed (invalid token)`) | re-parsed every case; e.g. `invalid-sa-140` (`&#x309a;` in a name), `ibm-valid-P87-*` | **Confirmed:** 4th-edition name characters vs the 5th-edition profile |
| first run: 60 not-wf documents accepted | grouped by W3C section: 3.4 conditional sections, 4.3 text declarations, parameter entities — all inside external files | **Confirmed:** the first expat engine did not read external files; with external entities enabled 59 disappear |
| 1 not-wf document accepted (`hst-lhs-007`) | UTF-8 BOM followed by an ISO-8859-1 declaration | expat tolerates the conflicting declaration (behaviour, not investigated further) |

### 4.2 Regression
| Parser | Runs | PASS | WRONG-VERDICT | WRONG-EVENTS | CRASH |
|---|---:|---:|---:|---:|---:|
| xpact (EiffelStudio), assertions on and off | 910 | 910 | 0 | 0 | 0 |
| xpact (Gobo) + 10 lifecycle steps | 920 | 919 | 0 | 0 | 1 ¹ |
| expat 2.8.5 and 2.6.1 | 910 | 910 | 0 | 0 | 0 |
| xpact-core, assertions on and off | 910 | 887 | 23 | 0 | 0 |

### 4.3 libexpat 2.8.1 suite through xpact's ABI
399 checks, 38 failures — all listed in `adapters/libexpat/expected-failures.tsv` (custom allocator failure paths). Gate passed.

### 4.4 Speed
**Same Linux machine, same work** — catalog-100-items (2,611 bytes), 16,000 documents, process wall time, median of 5, assertions off:
| Parser | Median ms | µs / document | MiB/s |
|---|---:|---:|---:|
| libexpat C (callbacks, gcc -O2) | 313.7 | 19.6 | 127.0 |
| xpact-core via EiffelStudio | 646.5 | 40.4 | 61.6 |
| xpact via Gobo | 1,445.1 | 90.3 | 27.6 |
| xpact via EiffelStudio | 1,574.1 | 98.4 | 25.3 |
Windows dual catalog (its own harness): xpact 26.2 MiB/s vs xpact-core 53.5 MiB/s, ratio 2.05 (core turns its GC off internally).
Correction: an earlier manual run showed xpact-core at 89.9 µs/doc on Linux; that binary was a stale build (the C include path was missing). The value above is from a clean build.

### 4.5 xpact's own test sets (Windows)
| Test set | Result |
|---|---|
| Eiffel test matrix, 4 modes (assertions off/on × workbench/finalized) | ❌ every mode: only `FAIL: incremental shim audit docs present` |
| Chunked CRC harness · corpus · native ABI (Windows + Linux) · native runtime smoke · contributed examples · shim audit | ✅ all exit 0 |
| Python unit tests | ✅ 257 tests OK |

| Field | Test matrix failure |
|---|---|
| Problem | `tests/xp_test_root.e:2693` expects "accumulated-buffer replay" in `docs/incremental-shim-audit.md`; the doc on `main` lacks it |
| Command | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode Off\|On -BuildMode Workbench\|Finalized` |
| Expected / actual | all assertions pass / one FAIL line, test executable exits non-zero, in all 4 modes |
| Cause | **Confirmed:** test text and documentation drifted apart on `main`; the doc file is unchanged by this run. Not a parser behaviour |
| Fix | none (out of scope) |

### 4.6 Large XML (whole-file parse, generated catalog file, `run_large_xml_benchmarks.ps1`)
5 MB file (5,243,005 bytes), 1 iteration × 3:
| Engine | Median ms | MiB/s |
|---|---:|---:|
| libexpat pyexpat tokenizer | 119.4 | 41.9 |
| xpact native C ABI tokenizer (Windows DLL) | 188.8 | 26.5 |
| libexpat pyexpat callbacks | 198.3 | 25.2 |
| xpact Eiffel finalized | 208.5 | 24.0 |
| libexpat C (WSL) tokenizer / callbacks | 155.7 / 154.0 | 32.1 / 32.5 |
| xpact native C ABI callbacks (Windows DLL) | 421.3 | 11.9 |

| Field | Native ABI large-file failure |
|---|---|
| Problem | `xpact_native_windows_c_benchmark.exe: parse failed: out of memory` |
| Command | `.\scripts\run_large_xml_benchmarks.ps1 -XmlFile build\four-way\large-<N>.xml -NoPublish -SkipBuild` |
| Observed | passes at 5, 7, 8, 9 MB (9,437,220 bytes); fails at 10, 15, 20, 25, 50, 100 MB. The files are valid (expat parses the 25 MB file: 670,643 elements) |
| Cause | **Unknown** — a size limit near 10 MB in the native C ABI whole-file path is suspected; the docs allow up to 512 MB (`MaxFileBytes`) |
| Fix | none; `run_four_way.ps1` uses a 5 MB file by default so the run stays comparable |

### 4.7 Gobo's own XML parser (`XM_EIFFEL_PARSER`), from the 18 November run

Source: [reports/gobo-xml-2026-11-18/results.md](../gobo-xml-2026-11-18/results.md) (commit `d3e4b92`, #442). Not re-run today; xpact numbers in this subsection are from that run too.

| Test | xpact | Gobo XML parser |
|---|---|---|
| W3C core profile (project runner, 1,974) | ✅ 1,974 / 0 | 1,910 / 64 |
| W3C legacy names (309) | ✅ 309 / 0 | 9 / 300 ❌ |
| W3C optional errors (28) / XML 1.1 (274) | ✅ 28/0 · 274/0 | ✅ 28/0 · 274/0 |
| W3C canonical output exact (432) | 375 | 319 |
| Encodings right (146) | 144 | 142 (+3 not supported) |
| libxml2 corpus, same verdict + events as Expat (1,417) | 1,295 | 1,055 |
| Fuzzing, same verdict as Expat | 99.996 % (870k inputs) | 97.642 % (80k inputs) |
| Security/limits as expected (29) | 20 | 21 |
| Crash / timeout on limits | 0 | 4 (billion-laughs, quadratic-blowup timeout; entity-chain-100k exception at 2 GB; deep-nesting-1m timeout) |
| Speed per document vs xpact | 1× | 3.4–8.6× slower; 25–34× slower on DTD-heavy files |
| Large file 20 MB | ❌ REJECT (size limit) | ✅ ACCEPT |

Notes: xpact's 9 "unexpected" limit results there are size limits (huge names/text/attributes, deep nesting) that xpact rejects on purpose; the same size limit shows as the 20 MB REJECT above and matches today's native-ABI failure from 10 MB (§4.6) — link suspected, not confirmed.
## 5. Known failures (observed, not fixed)
- [ ] xpact `main`: test-matrix documentation assertion (§4.5).
- [ ] xpact `main`: native C ABI whole-file parse fails from ~10 MB (§4.6).
- [ ] xpact-core: 728 W3C failures + 14 errors; 23 regression wrong verdicts; 3 failed audit controls.
- [ ] expat: 318 names (profile difference), 1 BOM/encoding case.
- [ ] Gobo: regression harness cannot read an empty file (library precondition).
- [ ] libexpat suite: 38 expected failures (allocator tests), unchanged.

## 6. Limitations
- W3C all-cases ran for xpact only (native-DLL entity checker needed).
- expat was driven through `pyexpat` for conformance and regression; C libexpat for speed.
- One machine, one run per lane; speed medians of 5 runs, no variance study; WSL file I/O adds overhead to the WSL C large-file rows.
- `run_benchmarks.ps1` and the large-XML script can republish files under `docs/`; the orchestrator keeps those versions in `logs/published-*` and restores the tracked files.

## 7. Files added
| File | Job |
|---|---|
| `benchmarks/four_way/run_four_way.ps1` | the whole comparison in one command |
| `benchmarks/four_way/wsl_four_way.sh` | its Linux half (Gobo, Linux EiffelStudio, Linux expat, speed race) |
| `benchmarks/four_way/expat_conformance_engine.py` / `expat_trace_engine.py` | expat as a W3C engine / as a regression engine |
| `benchmarks/four_way/run_manifest_engine.py` / `run_regression_engine.py` | any engine on the exact W3C case list / through the official regression rules |
| `benchmarks/four_way/gobo/{conformance,regression,catalog}_gobo.ecf` | the three harnesses for Gobo `gec` |
| `benchmarks/four_way/summarize_four_way.py` · `expat_lenient_cases.py` · `make_large_xml.py` | tables, expat case analysis, large input file |
| `benchmarks/four_way/README.md` | what each tool in the folder does |
| `reports/four-way-2026-11-23/TEST-SUITES.md` | every test suite: what it proves, size, command, last result (for reviewers who want to re-run) |
| `website/` Comparison page (`pages/Comparison.tsx`, `styles/report.css`, `styles/github-markdown.css`, `data/reports/*.html`) | this report and the suite list on the website, same look as the styled preview |
| `website/scripts/export-report.ps1` | re-renders the report into the website (run after the report changes) |
| `scripts/check_markdown_links.py` | finds broken relative links in Markdown files (exit 1 if any) |

## 8. Audit of scripts and docs (23 November 2026)

Checked locally with scripts: broken links (`scripts/check_markdown_links.py`), duplicate files, garbled UTF-8, large tracked files, stale numbers. Old `reports/` folders are evidence and were not changed.

| # | Finding | Status |
|---|---|---|
| 1 | Living docs (README, `docs/`, `website/`, `benchmarks/`, `tests/`, `scripts/`): **0 broken links**, no garbled text, no tracked file > 1 MB | ✅ checked |
| 2 | Website README + `website/docs/development.md`: the start command `.\website\dist\Xpact.Api.exe` run from the repo root serves **404 for every page** (the API looks for `wwwroot` in the current folder). Confirmed: `/` and `/benchmarks` 404 from the repo root, 200 from `website\dist` | ✅ docs fixed (start from `website\dist`); code fix (content root = exe folder) left to Anders |
| 3 | Website README status said 42 / 42 backend tests; today it is 56 / 56 | ✅ updated |
| 4 | The C# DLL suite `tests/dotnet/XpactDllTests` (4,308 cases) was in no run script | ✅ added to `run_four_way.ps1` (step 17b), passes 4,308 / 4,308 |
| 5 | `NativeSearchPath.cs` is a byte-identical copy in `Xpact.Api` and `Xpact.Worker` | 🚫 not changed: could move to `Xpact.Contracts` or be linked from one file; a small refactor for its own PR |
| 6 | Eiffel test matrix fails one documentation assertion in all 4 modes (§4.5) | 🚫 not changed: test and doc drifted on `main`; one issue for Anders |
| 7 | Native C ABI "out of memory" from 10 MB whole-file (§4.6); the Gobo run of 18 November also shows xpact rejecting 20 MB | 🚫 not changed: issue candidate, cause unknown |
| 8 | Old `reports/` and `student/results/` folders hold 47 broken links (e.g. `summary.md` files pointing at `compare.py` next to them) and many byte-identical log copies | 🚫 not changed: baseline evidence, never edited |
| 9 | Only the W3C and regression lanes run in Jenkins | 🚫 proposal in [TEST-SUITES §5](TEST-SUITES.md#5-in-ci-jenkins) |
| 10 | With `core.autocrlf=true` a Windows clone gets CRLF `.sh` files (seen on 3 example scripts), and bash fails on them; that would also break `wsl_four_way.sh` on a fresh clone | ✅ new `.gitattributes`: `*.sh text eol=lf` |
