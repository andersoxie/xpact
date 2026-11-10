# Report: mass-xpact #40: the declared encoding was worked out again on every call

> **Issue:** [CodTanium/mass-xpact#40](https://github.com/CodTanium/mass-xpact/issues/40) · **Branch:** `perf/40-cache-declared-encoding`, from `student-Mass` @ `e9d7d43`
> **Changed:** `src/xp_native_parser.e`
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

`declared_xml_encoding` and `has_stable_encoding` read the XML declaration again on every
`XML_Parse` call, through about 40 dynamically dispatched `item` calls. That was needless, because
the answer can't change once the declaration is complete. Now the answer is kept together with
the bytes it depends on, up to `?>`, and reused while the input starts with the same bytes. One
`same_characters` call checks that.

| `pr-xml-utf-8.xml` (207 KB), one parse | Before (#37) | After | |
|---|---:|---:|---|
| 1 byte per call | 290 ms | **236 ms** | **1.23× faster** |
| 16 bytes per call | 43.5 ms | **40.5 ms** | 1.07× |
| 64 bytes per call | 28.1 ms | 27.3 ms | 1.03× |
| 256 bytes, whole | 23.5 / 22 ms | 23.2 / 22 ms | unchanged |

Median of 3 interleaved rounds, production DLL, nothing else running ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
Byte by byte, 2026-11-04: 2,857 ms (start) → 438 (#31) → 319 (#34) → 286 (#37) → **236 ms** (this change), **12×** in all.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2 (16 logical CPUs); EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `e9d7d43` |
| **Command** | `sampler2.exe pr-xml-utf-8.xml 5 stacks.txt 1` (stack sampler; tools in `reports/mass-xpact-issue-0031/logs/tools/`) |
| **Profile** | [inclusive](logs/profile-before-split1.txt): `declared_xml_encoding` 16.8%, `has_stable_encoding` 6.5%; `{STRING_8}.item (dispatch)` 18.0% overall |
| **Cause** | ✔ Confirmed: the declaration is re-read on every call |

## 3. The change

- [x] `declared_xml_encoding` is now a wrapper. On a miss it calls the old scan, renamed `scanned_xml_encoding`. If the declaration is complete, it stores `declared_encoding_prefix` (the bytes `1 .. index of "?>" + 1`) and `declared_encoding_value`.
- [x] On a call where the input starts with `declared_encoding_prefix`, it returns `declared_encoding_value`.
- [x] **Same result.** On a match, `has_initial_xml_declaration` reads the same first six bytes, and the first `?>` is at the same index. Every byte the scan reads (`1 .. ?>`) is the same. This holds even after the input buffer has been compacted. If the bytes differ, the scan runs as before.
- [x] `has_stable_encoding` uses the same check. A matching input has no BOM, starts with `<?xml` and has a `?>` after it, so the old code returned `True` for it.
- [x] The callers only read the returned string (name comparisons, and the decoder's argument), so sharing it is safe.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ Timing, 5 chunk sizes | see section 1; output checksums identical |
| ✅ W3C trace (all handler sets; byte by byte, 7-byte pieces, whole) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix40-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. How to revert

Revert the commit.
