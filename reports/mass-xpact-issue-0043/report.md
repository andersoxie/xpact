# Report: mass-xpact #43: every XML_Parse call copied the input chunk twice

> **Issue:** [CodTanium/mass-xpact#43](https://github.com/CodTanium/mass-xpact/issues/43) · **Branch:** `perf/43-single-copy-input`, from `student-Mass` @ `658d799`
> **Changed:** `src/xp_native_bridge_installer.e` (`bytes_to_string`)
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

`bytes_to_string` turned each input chunk into a `STRING_8` through a `C_STRING`, which copied the
bytes twice. `make_by_pointer_and_count` copied them into new managed memory, and `substring_8`
copied them again. That meant two allocations and two copies per call. It now copies once:
`create Result.make (n); Result.from_c_substring (bytes, 1, n)`. The copy goes by count, so
embedded NUL bytes are kept as before.

| `pr-xml-utf-8.xml` (207 KB), one parse | Before (#40) | After | |
|---|---:|---:|---|
| 1 byte per call | 248 ms | **217 ms** | **1.14× faster** |
| 16 bytes per call | 41.5 ms | **39.4 ms** | 1.05× |
| 64 bytes per call | 27.7 ms | 26.8 ms | 1.03× |
| 256 bytes, whole | 23.3 / 22 ms | 22.8 / 22 ms | about the same |

Median of 3 interleaved rounds, production DLL, nothing else running ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
Byte by byte, 2026-11-04: 2,857 → 438 (#31) → 319 (#34) → 286 (#37) → 236 (#40) → **217 ms** (this change), **13×** in all.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `658d799` |
| **Command** | `sampler2.exe pr-xml-utf-8.xml 5 stacks.txt 1` |
| **Profile** | `bytes_to_string` 10.8% inclusive byte by byte. Below it: `C_STRING.make_by_pointer_and_count` 5.1%, `C_STRING.substring_8` 5.0%, `MANAGED_POINTER.make`, and allocation (see `reports/mass-xpact-issue-0040/logs/profile-before-split1.txt` for the same run's top lines) |
| **Cause** | ✔ Confirmed by the code: two copies per call |

## 3. The change

- [x] `create Result.make (a_length); Result.from_c_substring (a_bytes, 1, a_length)`. EiffelBase's `from_c_substring` points its shared `C_STRING` provider at the bytes, without copying, then copies them into the string once with `read_substring_into`, by count.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ **NUL bytes kept** | Four documents with a NUL: in text, in an attribute, after the root, inside a UTF-8 sequence. Traced with the old and the new DLL, whole and 1 byte per call: identical, and each is rejected at the NUL (`error=4`) ([inputs and traces](logs/nul-test/)) |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ Timing, 5 chunk sizes | see section 1; output checksums identical |
| ✅ W3C trace (all handler sets; byte by byte, 7-byte pieces, whole) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix43-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. How to revert

Revert the commit.
