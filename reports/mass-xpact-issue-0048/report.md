# Report: mass-xpact #48: UTF-16 signature checks ran on every call although the declaration ruled them out

> **Issue:** [CodTanium/mass-xpact#48](https://github.com/CodTanium/mass-xpact/issues/48) · **Branch:** `perf/48-known-declaration`, from `student-Mass` @ `a547454`
> **Changed:** `src/xp_native_parser.e`
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

On every `XML_Parse` call, `complete_encoded_prefix_count` and `decoded_input` asked
`has_utf16le_signature`, `has_utf16be_signature` and then the declared encoding. Once the input
starts with a complete `<?xml ...?>` seen before (#40), those answers are known. Input that starts
with `<?xml` has no UTF-16 signature, and the declared encoding is the stored one. Both routines
now take the known answers from that one check. **Nothing is checked less**: every byte of the
document is still parsed and validated. Only the same question isn't asked again.

| `pr-xml-utf-8.xml` (207 KB), one parse | Before (#46) | After | |
|---|---:|---:|---|
| 1 byte per call | 198 ms | **184 ms** | **1.07× faster** |
| 16 bytes per call | 37.6 ms | 37.1 ms | 1.01× |
| 64 / 256 bytes, whole | ~26 / 23 / 22 ms | ~26 / 23 / 22 ms | unchanged |

Median of 3 interleaved rounds, production DLL, nothing else running ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
Byte by byte, 2026-11-04/05: 2,857 → 438 (#31) → 319 (#34) → 286 (#37) → 236 (#40) → 217 (#43) → 200 (#46) → **184 ms** (this change), **15.5×** in all.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `a547454` |
| **Command** | `sampler2.exe pr-xml-utf-8.xml 6 stacks.txt 1` (profile: `reports/mass-xpact-issue-0046/logs/profile-before-split1.txt`) |
| **Profile** | `complete_encoded_prefix_count` 14.3% inclusive; `has_utf16le_signature` 4.3%, `has_utf16be_signature` 3.2% |
| **Cause** | ✔ Confirmed by the code: the same questions on every call |

## 3. The change

- [x] `starts_with_known_declaration (a_input)`: the prefix check from #40, now shared by `declared_xml_encoding`, `has_stable_encoding` and the two routines below.
- [x] `complete_encoded_prefix_count` and `decoded_input`: when it is true, both signature checks count as false and the declared encoding is `declared_encoding_value`.
- [x] **Same result.** A matching input starts with `<` `?` `x` `m`. Every alternative in `has_utf16le_signature` needs byte 1 to be 255 or byte 2 to be 0. Every alternative in `has_utf16be_signature` needs byte 1 to be 254 or 0. So both are false. The declared encoding equals `declared_xml_encoding`'s answer (#40).
- [x] UTF-16 documents and documents that start differently take the old path unchanged.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ **UTF-16 documents** | `pr-xml-utf-16.xml`, `weekly-utf-16.xml`, whole and 1 byte per call: status, counts, text bytes and checksum identical before and after ([utf16-check.tsv](logs/utf16-check.tsv)) |
| ✅ W3C trace (all handler sets; byte by byte, 7-byte pieces, whole) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases, including the W3C UTF-16 files) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix48-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |
| ✅ Timing, 5 chunk sizes | see section 1; output checksums identical |

## 5. How to revert

Revert the commit.
