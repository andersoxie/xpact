# Report: mass-xpact #46: a new string was allocated for every XML_Parse chunk

> **Issue:** [CodTanium/mass-xpact#46](https://github.com/CodTanium/mass-xpact/issues/46) · **Branch:** `perf/46-reuse-input-chunk`, from `student-Mass` @ `9321b8e`
> **Changed:** `src/xp_native_bridge_installer.e`
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

Every `XML_Parse` call made a new `STRING_8` for its input chunk, although the parser only reads that
string during the call. Small chunks (up to 64 KB) are now copied into one reused string. A new
string is still made when a parse is already reading the reused one (a parse started from a
callback, such as a child parser for an external entity), and for larger chunks.

| `pr-xml-utf-8.xml` (207 KB), one parse | Before (#43) | After | |
|---|---:|---:|---|
| 1 byte per call | 219 ms | **200 ms** | **1.10× faster** |
| 16 bytes per call | 38.7 ms | 37.8 ms | 1.02× |
| 64 / 256 bytes, whole | ~26 / 23 / 22 ms | ~26 / 23 / 22 ms | unchanged |

Median of 3 interleaved rounds, production DLL, nothing else running ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
Byte by byte, 2026-11-04: 2,857 → 438 (#31) → 319 (#34) → 286 (#37) → 236 (#40) → 217 (#43) → **200 ms** (this change), **14×** in all.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `9321b8e` |
| **Command** | `sampler2.exe pr-xml-utf-8.xml 6 stacks.txt 1` |
| **Profile** | [inclusive](logs/profile-before-split1.txt): `bytes_to_string` 10.5% (`from_c_substring` 6.9%, plus string creation and allocation) |
| **Cause** | ✔ Confirmed by the code: one new string per call, used only during the call |

## 3. The change

- [x] New `parsed_chunk` used by `parse` and `parse_buffer`: copies a chunk of 1 .. 64 KB into `input_chunk` with `from_c_substring`, which keeps its capacity, and parses that.
- [x] `input_chunk_in_use` is set during the call. A nested parse, from any callback on any parser, gets a new string as before, so it can't overwrite a string an outer parse is still reading.
- [x] **Safe to reuse.** I checked every use of the argument in `XP_NATIVE_PARSER.parse` and `parse_with_current_gc_policy`. It is appended to `input_buffer` or read in place, and never stored. Every `:= a_input` targets a local. `decoded_input`, `same_or_copied_input` and `decoded_input_with_encoding` are only called with `input_buffer`. Token slices are built in `XP_PARSER`, which only sees `input_buffer`.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ NUL-byte test (from #43) | identical, whole and 1 byte per call ([traces](logs/nul-test/)) |
| ✅ W3C trace (all handler sets; byte by byte, 7-byte pieces, whole) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix46-*`) |
| ✅ Expat 2.8.1 `runtests`, incl. external-entity tests that parse from a callback | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |
| ✅ Timing, 5 chunk sizes | see section 1; output checksums identical |

## 5. How to revert

Revert the commit; every chunk gets its own string again.
