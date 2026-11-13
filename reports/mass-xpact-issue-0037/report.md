# Report: mass-xpact #37: per-call cost of the encoding checks

> **Issue:** [CodTanium/mass-xpact#37](https://github.com/CodTanium/mass-xpact/issues/37) · **Branch:** `perf/37-encoding-check-overhead`, from `student-Mass` @ `1f0dcb1`
> **Changed:** `src/xp_native_parser.e`
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

Every `XML_Parse` call checks the XML declaration twice: `declared_xml_encoding` and
`has_stable_encoding`. Both created new manifest strings (`"?>"`, `"encoding"`, `"<?xml"`) and ran
the generic `STRING_SEARCHER.substring_index`, only to scan a few dozen bytes. They now use
constant strings and two small loops that return exactly the same indexes.

| `pr-xml-utf-8.xml` (207 KB), one parse | Before (#34) | After | |
|---|---:|---:|---|
| 1 byte per call | 334 ms | **286 ms** | **1.17× faster** |
| 16 bytes per call | 46 ms | **43 ms** | 1.07× |
| 64 / 256 bytes, whole | 29 / 24 / 22 ms | 28 / 24 / 22 ms | unchanged |

Median of 3 interleaved rounds, production DLL, nothing else running ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
Byte by byte, 2026-11-04: 2,857 ms (start) → 438 (#31) → 319 (#34) → **286 ms** (this change), **10×** in all.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2 (16 logical CPUs); EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `1f0dcb1` |
| **Command** | `sampler2.exe pr-xml-utf-8.xml 5 stacks.txt 1` (stack sampler; tools in `reports/mass-xpact-issue-0031/logs/tools/`) |
| **Profile** | [inclusive + callers](logs/profile-before-split1.txt): `declared_xml_encoding` 20.0% and `has_stable_encoding` 13.7%. Inside them, `makestr_with_hash` (creating manifest strings) 6.9% + 6.0% and `STRING_SEARCHER.substring_index` 11.1% + 4.7% |
| **Cause** | ✔ Confirmed: allocations and searcher set-up paid on every call, for a scan of the first few dozen bytes |

## 3. The change

- [x] Constants `Xml_declaration_opener` (`"<?xml"`) and `Encoding_keyword` (`"encoding"`): created once, not per call.
- [x] `index_of_declaration_end (a_input, s)`: the first `?>` at or after `s`, or 0. Same result as `substring_index ("?>", s)`.
- [x] `index_of_encoding_keyword (a_input, e)`: the first `encoding` lying within `1 .. e`, or 0. Same result as `substring_index_in_bounds ("encoding", 1, e)`.
- [x] Used at the three call sites in `declared_xml_encoding` and `has_stable_encoding`.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ Timing, 5 chunk sizes | see section 1; output checksums identical |
| ✅ W3C trace (all handler sets; byte by byte, 7-byte pieces, whole) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix37-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. How to revert

Revert the commit.
