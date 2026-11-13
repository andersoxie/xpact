# Report: mass-xpact #34: input in pieces rescanned the whole DOCTYPE internal subset on every call

> **Issue:** [CodTanium/mass-xpact#34](https://github.com/CodTanium/mass-xpact/issues/34) · **Branch:** `perf/34-resumable-doctype-scan`, from `student-Mass` @ `fad2125`
> **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e`, new `src/xp_doctype_scan.e`
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

While a DOCTYPE with an internal subset is still arriving, the parser asks on every `XML_Parse`
call whether it is complete yet. It answered by scanning the DOCTYPE from its start each time. The
scan now keeps where it stopped (index, bracket depth, quote) and goes on from there.

| `pr-xml-utf-8.xml` (207 KB), one parse | Before (#31) | After | |
|---|---:|---:|---|
| 1 byte per call | 437 ms | **319 ms** | **1.37× faster** |
| 16 bytes per call | 53 ms | **47 ms** | 1.14× |
| 64 / 256 bytes, whole | 30 / 24 / 22 ms | 30 / 24 / 22 ms | unchanged |

Median of 3 interleaved rounds, production DLL, nothing else running ([timing.tsv](logs/timing.tsv)); output checksums identical in every row.
Together with #31, byte by byte went from 2,857 ms to 319 ms today (9×).

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2 (16 logical CPUs); EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `fad2125` |
| **Command** | `sampler2.exe pr-xml-utf-8.xml 4 stacks.txt 1` (stack sampler, 1 byte per call; tools in `reports/mass-xpact-issue-0031/logs/tools/`) |
| **Profile** | [inclusive](logs/profile-before-split1.txt): 34.7% in `should_defer_reparse_callbacks` → `incremental_deferred_markup_end` → `{XP_PARSER}.markup_prefix_end` → **`find_doctype_end`** (27.7%) |
| **Cause** | ✔ Confirmed by the code: `incremental_deferred_markup_end` resumes comments, CDATA and PIs from `deferred_reparse_scan_index`, but sent a DOCTYPE to `markup_prefix_end`, which scans it from the start |

## 3. The change

- [x] **`XP_DOCTYPE_SCAN`** (new): where a DOCTYPE scan stopped. It holds the start index, next index, depth, quote and the input count seen.
- [x] **`{XP_PARSER}.doctype_end_resumed`**: the loop of `find_doctype_end`, starting from the saved state. When the end is not in the input yet, it records where to go on. It stops (and looks again next time) in two cases:
  - an unterminated comment or PI inside the subset, where the old scan would skip to the end of the input;
  - a buffer that ends in a partial `<!--` or `<?` (`is_partial_comment_or_pi_opener`), where the old scan would read the comment's quotes as literals once the rest arrives.
- [x] **Same result.** The scan is left to right and depends only on bytes already seen, which don't change while the input only grows. At each stop, the old scan found no end either.
- [x] **`{XP_NATIVE_PARSER}.incremental_deferred_markup_end`**: a delayed `<!DOCTYPE` uses the resumable scan. The state is reset when the token's start index changes, when the input gets shorter, and wherever the delayed-token state is cleared.
- [x] `find_doctype_end` itself is unchanged (its other callers).

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ Timing, 5 chunk sizes | see section 1; output checksums identical |
| ✅ W3C trace (all handler sets; byte by byte, 7-byte pieces, whole) | 9 / 9 files byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases, split at every point up to 4,096) | TSVs byte-identical to `student-Mass`, both tiers (`reports/issue-0165/tools/logs/chunked-fix34-*`) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. How to revert

Revert the commit; a delayed DOCTYPE goes back to `markup_prefix_end`.
