# Report: mass-xpact #31: chunked parsing rescanned the whole buffer for "encoding" on every call

> **Issue:** [CodTanium/mass-xpact#31](https://github.com/CodTanium/mass-xpact/issues/31) · **Branch:** `perf/31-encoding-scan-bound`, from `student-Mass` @ `83fa0b2`
> **Changed:** `src/xp_native_parser.e` (one line in `declared_xml_encoding`)
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

On every `XML_Parse` call, `declared_xml_encoding` searched the whole accumulated input for the word
`encoding`, to read the encoding from the XML declaration. When the declaration has no `encoding`
attribute, the search ran into the document body. Input in pieces grows with every call, so the
total cost grew with the square of the document size. Now the search stops at the end of the
declaration (`?>`).

| `pr-xml-utf-8.xml` (207 KB), one parse | Before | After | |
|---|---:|---:|---|
| 1 byte per call | 2,857 ms | **438 ms** | **6.5× faster** |
| 16 bytes per call | 209 ms | **55 ms** | 3.8× |
| 64 bytes per call | 69 ms | **30 ms** | 2.3× |
| 256 bytes per call | 35 ms | 25 ms | 1.4× |
| 4,096 bytes per call | 24 ms | 22 ms | about the same |
| whole document | 23 ms | 24 ms | unchanged (noise) |

Median of 3 interleaved rounds, the production DLL, nothing else running ([timing.tsv](logs/timing.tsv)).
The output (status, element counts, text bytes, checksum) is identical in every row.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2 (16 logical CPUs); EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `83fa0b2` |
| **Command** | `sampler2.exe pr-xml-utf-8.xml 20 stacks.txt 64` (stack sampler, 64-byte pieces) on the production DLL relinked with `-MAP` ([tools](logs/tools/)) |
| **Expected** | Input in pieces costs about one whole parse plus a small cost per call |
| **Actual** | Whole parse 11.5 ms, 64-byte pieces 66.1 ms (5.7×) |
| **Profile** | [flat](logs/profile-before-split64.txt), [inclusive](logs/stacks-before-split64.txt): 61.8% in `{XP_NATIVE_PARSER}.declared_xml_encoding` ← `complete_encoded_prefix_count` ← `parse_with_current_gc_policy`, nearly all of it in `{STRING_8_SEARCHER}.substring_index_with_deltas` |
| **Cause** | ✔ Confirmed by the code and the profile: `a_input.substring_index ("encoding", 1)` is not bounded to the declaration. `pr-xml-utf-8.xml` starts with `<?xml version="1.0"?>` and has the word 13 times in its body |

## 3. The change

- [x] `l_pos := a_input.substring_index_in_bounds ("encoding", 1, l_end)`, where `l_end` is the position of `?>`, or the input's end when the declaration is not complete yet.
- [x] Same result for every input. The old code kept a match only if it started before `l_end`. A match of `encoding` can't overlap `?>`, so any such match lies inside `1 .. l_end`, and the bounded search finds it.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ Timing, 6 chunk sizes | see section 1; output checksums identical |
| ✅ W3C trace (all handler sets and chunkings) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix31-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. How to revert

Revert the commit; the search goes back to the whole input.
