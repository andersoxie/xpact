# Report: mass-xpact #7: chunked UTF-16 input still re-parsed the whole buffer

> **Issue:** [CodTanium/mass-xpact#7](https://github.com/CodTanium/mass-xpact/issues/7) · **Branch:** `perf/resume-utf16`, stacked on `perf/incremental-parsing` @ `7c3eda4` (#2, PR #4)
> **Changed:** `src/xp_native_parser.e`; docs [incremental-resume.md](../../docs/incremental-resume.md)
> **Status:** ✅ fixed · ✅ verified locally, both DLL tiers

## 1. In short

UTF-16 documents fed in pieces now resume like UTF-8 ones (#2): each call decodes and parses
only its new bytes. Everything the application sees is unchanged, except that two W3C cases
that timed out now pass.

| ✅ Result | Before (`7c3eda4`) | After |
|---|---:|---:|
| `pr-xml-utf-16.xml` (313 KB UTF-16), 256-byte pieces | 70.5 s | **0.18 s** |
| same, 4 KB pieces | 11.6 s | **0.16 s** |
| same, whole (one call + empty final call) | 263 ms | **163 ms** |
| Test 2 cases `pr-xml-little`, `pr-xml-utf-16` | TIMEOUT (300 s) | **stable** |
| Test 2 wall time, `--jobs 16` (#5), production | 5 min 02 s | **1 min 39 s** |
| Test 2 wall time, `--jobs 16`, assertions | (21 min 16 s sequential) | **4 min 17 s** |

The "after" times in the first three rows were measured while the Eiffel test matrix ran on the same PC.
Raw rows: [timing-pr-xml-utf-16.tsv](logs/timing-pr-xml-utf-16.tsv).

## 2. Problem report

| Field | |
|---|---|
| **1. Problem** | UTF-16 input in *n* pieces cost about *n* × its size. |
| **2. Environment** | Windows 11, student PC2 (16 logical cores); EiffelStudio 25.12; MSVC (VS 18); Python 3.15 (uv). DLLs: `build\utf16\native-eiffel\xpact.dll` (Production), `build\utf16\native-eiffel-assertions\xpact_assertions.dll` (Assertions). |
| **3. Command** | `python -I reports\issue-0165\tools\run.py --dll <dll> --tag <tag> --jobs 16`; `chunk_time.exe <pr-xml-utf-16.xml> <chunk> 1` |
| **4. Expected** | Linear, like UTF-8 after #2; same callbacks, positions and errors. |
| **5. Actual (before)** | 256-byte pieces: 70.5 s. Test 2: both 313 KB UTF-16 cases TIMEOUT after 300 s. |
| **6. Error output** | Test 2 rows `pr-xml-little … xpact-only TIMEOUT`, `pr-xml-utf-16 … xpact-only TIMEOUT`. |
| **7. Investigation** | Timing single cases after #5 showed the two UTF-16 cases at the timeout. In `parse_with_current_gc_policy` the resume path was enabled only when `decoded_input` returned `input_buffer` itself (UTF-8); UTF-16 was decoded whole and parsed from byte 1 on every call. |
| **8. Cause** | ✅ **Confirmed**: the fix removes the slowdown (section 1). |
| **9. Fix** | Keep the UTF-8 decoding (`decoded_buffer`), decode only new bytes (`append_decoded_utf16`), and resume on it (`resume_source`). Fall back to the full replay for an invalid surrogate or a partial character at the final call. Design: [incremental-resume.md](../../docs/incremental-resume.md#utf-16-input-mass-xpact7). |
| **10. Verification** | ✅ Section 3. |

## 3. Verification

✅ = same as the `7c3eda4` build on the same tier.

| Check | Result | Log |
|---|---|---|
| ✅ DLL build + smoke test, both tiers | ok ×2 | |
| ✅ `XpactDllTests` (4,308 cases) | 4,308 / 4,308 ×2; **`results.tsv` byte-identical** to the `7c3eda4` run, both tiers | [production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt) |
| ✅ Differential traces (9 runs over the W3C files) | **byte-identical** on both tiers; they include **45 UTF-16 files byte by byte and 47 in 7-byte pieces** (odd pieces cut UTF-16 characters) | [production](logs/trace-sha256.txt), [assertions](logs/trace-sha256-assertions.txt) |
| ✅ Chunked CRC harness | 54 rows identical | [crc](logs/chunked-crc.tsv) |
| ✅ Timing tool checksums (rich and plain UTF-8 documents) | identical; times unchanged | [timing](logs/timing.tsv) |
| ✅ Expat 2.8.1 `runtests` (production) | Checks 399, Failed 38: "completed with 38 expected test failures" | [runtests](logs/expat/runtests.txt) |
| ✅ Test 2, production and assertions | **only 2 rows changed**: `pr-xml-little`, `pr-xml-utf-16` TIMEOUT → stable. ok 2,564 · xpact-only 16 · both 5 | [production](logs/chunked-utf16-production.tsv), [assertions](logs/chunked-utf16-assertions.tsv) |
| ✅ Eiffel test matrix (4 configurations) | ok (exit 0) | |

## 4. Limitations

- [ ] Latin-1, ASCII, explicit (`XML_ParserCreate ("UTF-16")`) and unknown encodings still use the full replay.
- [ ] UTF-16 that the signature alone does not identify (an explicit encoding) is not resumed.
- [ ] `decoded_buffer` is a second copy of the input (UTF-8), next to `input_buffer`: more memory for UTF-16 input.
- [x] ✅ Expat `runtests` now also run on the assertions DLL: it found a contract violation, fixed in [#12](../mass-xpact-issue-0012/report.md).
