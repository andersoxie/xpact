# Report: mass-xpact #51: a long text run in pieces was quadratic (positions counted again every call)

> **Issue:** [CodTanium/mass-xpact#51](https://github.com/CodTanium/mass-xpact/issues/51) · **Branch:** `perf/51-position-high-water`, from `student-Mass` @ `3f75c8f`
> **Changed:** `src/xp_parser.e` (position counting only)
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

A document with a long text run, fed in small pieces, took time quadratic in the run length: a
100 KB run took **7.4 s** byte by byte. #11 already continues such a run instead of parsing it
again, but on every call the parser noted the run's start position and then counted lines and
columns byte by byte to its end, over the whole run. Two small memories in the position counter
remove that: the furthest position counted so far, and the last run start moved back to. Both
hold line and column. Every reported line, column and byte index stays the same.

| Document, chunk size | Before (#48) | After | |
|---|---:|---:|---|
| 100 KB single text run, 1 byte | 7,394 ms | **102 ms** | **72×** |
| 100 KB single text run, 16 / 256 bytes | 466 / 33 ms | 10.6 / 4.6 ms | 44× / 7× |
| 25 / 50 / 100 KB run, 1 byte | 489 / 1,875 / 7,394 ms | 27 / 52 / 102 ms | now linear |
| 98 KB text, 4,000 lines, 1 byte | 5,446 ms | **100 ms** | **54×** |
| 98 KB text, 4,000 lines, 16 bytes | 344 ms | 10.6 ms | 32× |
| `pr-xml-utf-8.xml` (207 KB), 1 byte | 184 ms | **145 ms** | 1.27× |
| `pr-xml-utf-8.xml`, 16 / 64 bytes, whole | 38 / 27 / 23 ms | 36 / 27 / 23 ms | about the same |

Median of 3 interleaved rounds, production DLL, element + character-data handlers, nothing else
running ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
`pr-xml-utf-8.xml` byte by byte since 2026-11-04: 2,857 → **145 ms (20×)**.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `3f75c8f` |
| **Command** | `chunk_time.exe text-<N>k.xml 1 1`, where the document is `<a>` + N KB of `x` + `</a>`. Found while profiling with element and character-data handlers set: `sampler3.exe text-50k.xml 2 stacks.txt 16 h` ([sampler3.c](logs/tools/sampler3.c)) |
| **Expected** | Linear in the document size |
| **Actual** | 4× slower per doubling of the run (table above) |
| **Profile** | [96.1% in `{XP_PARSER}.note_position`](logs/profile-before-text50k-split16.txt), via `advance_position_to` |
| **Cause** | ✔ Confirmed by the code. Each call moves the position back to the run start (`note_token_position (text_run_start (...))`), then forward to the end. `advance_position_to` walked the whole run. `retreat_position_to` was cheap on one line, but walked the run backwards when the run spans lines |

Earlier profiles used a sampler without handlers, which takes a different path, so they didn't show this.

## 3. The change

- [x] **High-water mark.** `advance_position_to` keeps the furthest index it reached, with line and column. A later advance from before that index to past it jumps there and counts only the new bytes.
- [x] **Retreat memory.** `retreat_position_to` keeps the last index it moved back to across a line end, with line and column. The same target next time is O(1).
- [x] **Same result.** Both are keyed to the `position_input` object and cleared in `recompute_position_from_start`, `reset` and `reset_cached_doctype_body`. They rely on what `retreat_position_to` already relies on: `position_input` doesn't change before the furthest index reached since the last recompute. Line and column at an index depend only on the bytes before it.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ **Positions** | Three ~100 KB documents with 4,000 text lines: well-formed; with an error at the end; CRLF with a duplicate attribute at the end ([documents](logs/position-test/)). Traced with the old and the new DLL, byte by byte (293,374 trace lines), in 7-byte pieces and whole. Every event's line, column and byte index identical, and so are the error positions ([trace SHA-256](logs/position-test/trace-sha256.txt)) |
| ✅ DLL tests, 4,308 cases (with error line, column, byte index) | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ Timing | see section 1; output checksums identical |
| ✅ W3C trace (every event with line:column:byte; byte by byte, 7-byte pieces, whole) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases, positions compared at every split) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix51-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. Still open

- [ ] Without a character-data handler, a long text run is parsed again from its start on every call (`is_resumable_text_run` path). That's a separate quadratic case, not changed here.

## 6. How to revert

Revert the commit.
