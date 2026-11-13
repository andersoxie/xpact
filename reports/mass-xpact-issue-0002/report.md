# Report: mass-xpact #2: chunked parsing re-parsed the whole buffer on every call

> **Issue:** [CodTanium/mass-xpact#2](https://github.com/CodTanium/mass-xpact/issues/2) · **Branch:** `perf/incremental-parsing`, from `student-Mass` @ `253c81e`
> **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e`, `src/xp_native_callback_handler.e`, `src/xp_event_handler.e`; docs [incremental-resume.md](../../docs/incremental-resume.md)
> **Status:** ✅ fixed · ✅ verified locally, both DLL tiers · ✅ Expat's own C tests: 38 known failures, as before (one bug found and fixed, section 4.2) · ✅ closed after local verification; PR #4 waits for the merge

## 1. In short

When a document arrives in several `XML_Parse` calls, the native parser now **continues from
where the previous call stopped** instead of parsing the whole buffer again. Everything the
application sees stays the same: every callback, its text, its position, when it arrives, and
every error. Only the time changes.

| ✅ Result | Before (`253c81e`) | After |
|---|---:|---:|
| 131 KB document in 16-byte pieces | 214.5 s | **0.16 s** |
| 43 KB document in 16-byte pieces | 22.8 s | **0.04 s** |
| Test 2 (all W3C documents whole, byte by byte, split at every point), production DLL | 20 min 45 s | **15 min 30 s** |
| Test 2, assertions DLL | 23 min 28 s | **21 min 16 s** |
| Chunked CRC harness run | 3 min 11 s | **1.2 s** |
| Anything the application can observe | | **identical** (section 4) |

## 2. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | Input in *n* pieces cost about *n* × its size: every `XML_Parse` call parsed the whole buffer again. Tests that feed documents in pieces took very long. |
| **2. Environment** | Windows 11 (student PC2); EiffelStudio 25.12 (`msc_vc140`); MSVC (VS 18); .NET 10; Python 3.15 (uv). DLL tiers: `xpact.dll` (Production) and `xpact_assertions.dll` (Assertions), built with `scripts\build_native_eiffel.ps1`. |
| **3. Command** | `python -I reports\issue-0165\tools\run.py --dll <dll> --tag <tag>` (Test 2); `tools\run-tools.ps1 -DllDir <dir> -OutputDir <dir>` (timing, traces, CRC). |
| **4. Expected** | Each call costs about its new bytes; same callbacks, positions and errors. |
| **5. Actual (before)** | 131 KB in 16-byte pieces: 214.5 s (whole: 0.11 s). Test 2: 20 min 45 s. |
| **6. Error output** | None: results were correct, only slow. |
| **7. Investigation** | `XP_NATIVE_PARSER.parse_with_current_gc_policy` appended each call to `input_buffer`, decoded the whole buffer and called `parser.parse_prefix`, which starts with `reset`. Delivered callbacks were hidden by count. The scans for unfinished markup (`incomplete_markup_prefix_start`, also inside the reparse-deferral check) started at byte 1 on every call. The supervisor's `XP_INCREMENTAL_PARSE_SESSION` prototype is not wired in and covers only tags and text; it was read for ideas but not used. |
| **8. Cause** | ✅ **Confirmed**: the fix removes the square growth (section 3). |
| **9. Fix** | Resume from a checkpoint; the old full replay remains the fallback. Design: [docs/incremental-resume.md](../../docs/incremental-resume.md). |
| **10. Verification** | ✅ Section 4. |

## 3. Timing

Tool: [`tools/chunk_time.c`](tools/chunk_time.c) through [`tools/run-tools.ps1`](tools/run-tools.ps1)
(`-Run Timing`). Documents from [`tools/gen.py`](tools/gen.py): **rich** (XML declaration,
DOCTYPE with an entity, CRLF, UTF-8 text, character and entity references, CDATA, comments)
and **plain**. Production DLL, one process per run, nothing else running. The checksum
column (all events) is the same in every row: the events are identical.

| Document | Pieces | Before (ms) | After (ms) | Faster |
|---|---|---:|---:|---:|
| rich, 131 KB | 1 byte | not run (hours) | 1,213 | |
| rich | 16 bytes | 214,516 | **155** | 1,384× |
| rich | 256 bytes | 12,932 | **74** | 175× |
| rich | 4 KB | 1,044 | **67** | 16× |
| rich | whole (one call + empty final call) | 110 | **71** | 1.5× |
| plain, 43 KB | 1 byte | not run | 200 | |
| plain | 16 bytes | 22,792 | **40** | 566× |
| plain | 256 bytes | 1,544 | **26** | 60× |
| plain | 4 KB | 143 | **25** | 5.8× |
| plain | whole (one call + empty final call) | 40 | **24** | 1.7× |

"Whole" is faster too: the old final call parsed the document a second time.

Raw rows: [baseline](logs/baseline/timing.tsv), [after](logs/after/timing.tsv).

## 4. Verification

✅ = same result as the baseline on the same tier.

| Check | Baseline `253c81e` | After | Logs |
|---|---|---|---|
| ✅ DLL build + smoke test (`tests/native/xpact_eiffel_dll_smoke.c`) | ok ×2 | **ok ×2** | |
| ✅ `XpactDllTests` (C#, 4,308 cases: whole, split at every byte, byte by byte) | 4,308 / 4,308 ×2 | **4,308 / 4,308 ×2** | [baseline](logs/baseline/), [after](logs/after/) |
| ✅ Chunked CRC harness, direct + buffer modes, chunk 1 … whole | 54 rows | **54 rows identical in every column** (status, error, byte index, line, column, semantic and trace CRC) ×2 | [baseline](logs/baseline/chunked-crc.tsv), [after](logs/after/chunked-crc.tsv) |
| ✅ Chunked CRC corpus gate (7 documents × 13 chunk sizes × 2 modes) | 196 rows | **196 rows identical** ×2; one semantic CRC per document | [after](logs/after/crc-corpus.tsv) |
| ✅ Incremental shim audit (6 cases) | 6 passes | **identical** | [after](logs/after/incremental-shim-audit.tsv) |
| ✅ **Differential trace** (section 4.1), 9 runs over the W3C files | | **byte-identical** production; assertions = baseline assertions | [hashes](logs/after/trace-sha256.txt) |
| ✅ Eiffel test matrix (direct parser; assertions off/on × Workbench/Finalized) | | **ok ×4** | |
| ✅ Test 2, W3C in pieces | ok 2,561 · xpact-only 19 · both 5 (×2 tiers) | **2,584 cases identical; `pr-xml-utf-8` was a 300 s TIMEOUT, now stable: ok 2,562 · xpact-only 18 · both 5 (×2 tiers)** | [test2](logs/test2/) |
| ✅ Expat 2.8.1 `runtests` (C suite, production DLL) | Checks 399, Failed 38 (#165 report) | **Checks 399, Failed 38: the same 38 tests** (allocator tests xpact does not support), after the fix in section 4.2 | [expat](logs/expat/) |

### 4.1 Differential trace

[`tools/trace.c`](tools/trace.c) parses every W3C file in pieces and prints each callback with
its data and `XML_GetCurrentLineNumber` / `ColumnNumber` / `ByteIndex`, and the final status,
error and position. It also shows *in which call* a callback arrives. Nine runs: start/end/text/PI/
comment/CDATA/doctype/entity handlers (pieces of 1 and 7 bytes, and whole), the default handler
alone (1, 7), a resumable stop every 3rd callback with `XML_ResumeParser` (1, 7), and a
non-resumable stop at the 3rd callback (1, 7). Files under 2 KB byte by byte (3,020), under
8 KB otherwise (3,057).

The trace found three differences during development, all fixed before this result:

| # | Difference found | Cause | Fix |
|---|---|---|---|
| 1 | Character data split into callbacks differently in 4 files (Japanese UTF-8, XML 1.1 characters) | The old path cuts a UTF-8 character that is cut off by the end of non-final input **before** deciding reparse deferral; the resume path decided on the whole buffer, so some callbacks arrived one call earlier | Decide and parse on the same bytes (`should_defer_reparse_callbacks_on_prefix`); `XML_GetInputContext` keeps its old right edge (`context_source_count`) |
| 2 | Abort position `1:0:0` instead of the real one (1,238 traced documents) | A non-resumable `XML_StopParser` in a resumed parse fell back to the full replay, which still saw the stop request | Errors of a resumed parse are reported directly; the fallback is only for invalid characters |
| 3 | v1 still slow on documents with general entities in text | a pending text run with a general reference forced the full replay | resume after the last general reference of the run |

### 4.2 Expat's C suite found an accounting bug (fixed)

| Field | |
|---|---|
| **1. Problem** | The resumed parse counted predefined entity references again in Expat's entity accounting (the billion-laughs protection count). |
| **2. Environment** | Same PC; production DLL `build\native-eiffel\xpact.dll` built from `0ff0615`; Expat 2.8.1 source, Debug test runner. |
| **3. Command** | `$env:PATH = "<VS>\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;$env:PATH"` then `.\scripts\run_libexpat_adapter.ps1 -Mode NativeSuite -ExpatSourceDir <expat-2.8.1> -XpactLibrary build\native-eiffel\xpact.lib -SkipNativeBuild -SkipXpactBuild -OutputDir build\libexpat-native-after` |
| **4. Expected** | Checks 399, Failed 38, the 38 known allocator tests (as in #165). |
| **5. Actual** | Checks 399, Failed **39**: also `test_accounting_precision`. |
| **6. Error output** | `FAIL [chunksize=1 deferral=0]: test_accounting_precision` after `Document 10 of 36: Expected 5 count indirect bytes, got 60 instead.` ([log](logs/expat/runtests-v5-before-fix.txt)) |
| **7. Investigation** | Document 10 is `<e>&amp;&apos;&gt;&lt;&quot;</e>`, fed one byte at a time. Predefined references add to `expanded_entity_bytes`. On every call the resume path parsed the pending text run again from its checkpoint, so the references already in it were counted again; the old path resets the count before each full parse. |
| **8. Cause** | ✅ **Confirmed**: the fix below makes the test pass. |
| **9. Fix** | The checkpoint saves `expanded_entity_bytes` (`resume_entity_bytes`, also after the last general reference); `continue_prefix` restores it before parsing. |
| **10. Verification** | ✅ Expat suite: Checks 399, Failed 38, the same list as #165 ([log](logs/expat/runtests-after-fix.txt)). ✅ `XpactDllTests` 4,308/4,308 on both tiers. ✅ Traces byte-identical on both tiers; CRC rows identical; timing unchanged. ✅ Test 2 (production): all 2,585 rows identical to the run before the fix ([test2](logs/test2/chunked-fix1-acc-production.tsv)). |

The first rerun after the fix had a different crash: `test_deep_nested_attribute_entity` exited with
`0xC0000005` ([log](logs/expat/runtests-after-fix-busy-pc.txt)). That run overlapped with the C# tests
(8 processes). The test passed 3 of 3 times alone (32 s each) and in the clean full run. Cause:
🟡 **suspected** load on the PC (the same test timed out under load in the #179 report), not confirmed.

### 4.3 Found on the way (separate issue)

The **assertions** DLL crashes (`0xC0000028`, no output) on `xmlconf/ibm/not-wf/P68/ibm68n03.xml`
when only a default handler is set, at any chunk size. The baseline crashes the same way, so
#2 did not cause it. Reported as [mass-xpact#3](https://github.com/CodTanium/mass-xpact/issues/3).

## 5. Not verified / limitations

- [x] ✅ **Expat's own C tests (`runtests`)**: run on the production DLL only (section 4.2). The
  assertions DLL was not run through this suite.
- [ ] `test_deep_nested_attribute_entity` crashed once on a busy PC (section 4.2); cause not confirmed.
- [ ] Not resumed yet (old full replay, as fast as before): non-UTF-8 input, external entity
  parsers, an unfinished DOCTYPE, after `XML_ResumeParser`. See [incremental-resume.md](../../docs/incremental-resume.md).
- [ ] Memory: `input_buffer` is still kept whole (the fallback needs it).
- [ ] Whole-document parsing is unchanged; Test 2 is now dominated by per-parse cost
  (it parses each small document once per split point): a 10 % sample took 2.7 s with Expat,
  316 s with the baseline and 89 s after this change.
- [ ] Measured on one PC (student PC2) only.

## 6. Reproduce

```powershell
.\scripts\build_native_eiffel.ps1 -BuildTier Production -OutputDir build\after\native-eiffel
.\scripts\build_native_eiffel.ps1 -BuildTier Assertions -OutputDir build\after\native-eiffel-assertions
.\reports\mass-xpact-issue-0002\tools\run-tools.ps1 -DllDir build\after\native-eiffel -OutputDir build\evidence\after
dotnet build tests\dotnet\XpactDllTests -c Release
build\dotnet\XpactDllTests\bin\Release\net10.0\XpactDllTests.exe --dll build\after\native-eiffel\xpact.dll
python -I reports\issue-0165\tools\run.py --dll build\after\native-eiffel\xpact.dll --tag after
```

Do the same with a checkout of `253c81e` for the baseline, and compare the `trace-sha256.txt`
and `chunked-crc.tsv` files.
