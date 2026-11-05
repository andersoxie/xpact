# Report: mass-xpact #57: per-call allocations in the reparse-deferral checks

> **Issue:** [CodTanium/mass-xpact#57](https://github.com/CodTanium/mass-xpact/issues/57) · **Branch:** `perf/57-deferral-check-allocations`, from `student-Mass` @ `0ec5894`
> **Changed:** `src/xp_native_parser.e`
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

On every `XML_Parse` call, the reparse-deferral checks allocated objects they didn't need.
- Three routines created a new `XP_ATTRIBUTES` just to call its pure name-character tests. They now share one `name_checker`.
- `incremental_deferred_markup_end` created up to four substrings plus manifest strings, to tell `<!--`, `<![CDATA[`, `<?` and `<!DOCTYPE` apart. It now compares in place against constants.

The results are the same.

| `pr-xml-utf-8.xml` (207 KB), one parse | Before (#53) | After | |
|---|---:|---:|---|
| 1 byte per call, with handlers (`chunk_time`) | 145 ms | **134 ms** | **1.08× faster** |
| 1 byte per call, no handlers (`sampler2`) | 198 ms | 187 ms | 1.06× |
| 16 / 64 bytes, whole | 35 / 26 / 22 ms | 34 / 25 / 22 ms | about the same |

Median of 3 interleaved rounds ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
`pr-xml-utf-8.xml` byte by byte since 2026-11-04: 2,857 → **134 ms (21×)**.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `0ec5894` |
| **Command** | `sampler3.exe pr-xml-utf-8.xml 6 stacks.txt 1 h` (element and character-data handlers) |
| **Profile** | [inclusive](logs/profile-before-split1-handlers.txt): `is_plain_completed_start_tag` 6.3% (`XP_ATTRIBUTES.make` 3.3%); `incremental_deferred_markup_end` 9.6% (`substring` 2.5%, `makestr_with_hash` 1.8%) |
| **Cause** | ✔ Confirmed by the code |

## 3. The change

- [x] `name_checker: XP_ATTRIBUTES` is created once in `make` and used by `is_plain_completed_start_tag`, `plain_unclosed_start_tag_name_length` and `direct_start_tag_name`. Its `is_name_start_character` / `is_name_character` are pure and it never holds attributes. `direct_start_tag_attributes` stores attributes, so it keeps its own object.
- [x] `incremental_deferred_markup_end` uses `a_input.same_characters (Comment_opener, 1, Comment_opener.count, l_start)` and the same for the other openers, with the same length guards as before. The terminators are constants.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ No-handler check, 3,061 W3C files, 1 / 7 / 16 bytes and whole (tool from #53) | 0 differences ([results](logs/no-handler-w3c/)) |
| ✅ W3C trace | 9 / 9 files byte-identical, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical, both tiers (`reports/issue-0165/tools/logs/chunked-fix57-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |
| ✅ Timing | see section 1; output checksums identical |

## 5. How to revert

Revert the commit.
