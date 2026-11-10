# Report: mass-xpact #11: chunked parsing was still quadratic in long text runs and with deferral + partial UTF-8

> **Issue:** [CodTanium/mass-xpact#11](https://github.com/CodTanium/mass-xpact/issues/11) · **Branch:** `perf/resume-text-runs`, stacked on `perf/resume-utf16` @ `19ba873` (#7 + #12, PR #8)
> **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e`; docs [incremental-resume.md](../../docs/incremental-resume.md#long-text-runs-mass-xpact11)
> **Status:** ✅ fixed · ✅ verified locally, both DLL tiers

## 1. In short

Two remaining square-growth costs of chunked parsing are gone. Everything the application sees is
unchanged.

| ✅ Result (production DLL, byte by byte) | Before (`19ba873`) | After |
|---|---:|---:|
| `pr-xml-utf-8.xml` (207 KB, Japanese): the slowest Test 2 case | 72.6 s | **9.9 s** |
| 40 KB, 4,000-character ASCII runs | 15.9 s | **1.2 s** |
| 48 KB, runs full of `&amp;` | 54.6 s | **1.6 s** |
| 40 KB, 4,000-character Japanese runs | 9.1 s | **0.5 s** |
| 39 KB, short Japanese runs (deferral on) | 6.0 s | **0.21 s** |
| Timing tool, `doc-rich.xml` (131 KB), 1-byte pieces | 1,212 ms | **772 ms** |
| Test 2 wall time, `--jobs 16`, production | 1 min 39 s | **46 s** |
| Test 2 wall time, `--jobs 16`, assertions | 4 min 17 s | **1 min 14 s** |

Python times include the ctypes callbacks. Raw rows: [timing](logs/timing.tsv), [per-case Test 2 times](logs/test2-case-times-before.tsv).

## 2. Problem report

| Field | |
|---|---|
| **1. Problem** | Byte-by-byte parsing of text-heavy documents cost about (run length)² or *n*². |
| **2. Environment** | Windows 11, student PC2 (16 logical cores); EiffelStudio 25.12; MSVC (VS 18); Python 3.15 (uv). DLLs `build\textrun\native-eiffel\xpact.dll`, `build\textrun\native-eiffel-assertions\xpact_assertions.dll`. |
| **3. Command** | Per-case Test 2 timing (all 2,585 cases, 16 threads); then `XML_Parse` byte by byte with a timer around each call (scratch scripts, ctypes). |
| **4. Expected** | Linear: every call costs about the same. |
| **5. Actual (before)** | `pr-xml-utf-8`: 97.7 s in Test 2 (Expat 0.06 s), which alone set the 99.9 s wall time. Calls inside long paragraphs took about 1.8 ms. One call per 3-byte character after text took up to 3.5 ms, growing with the position. |
| **6. Error output** | None: the results were correct, only slow. |
| **7. Investigation** | External entities off: same time, so not the DTD. Synthetic documents: (1) the cost grows with the run length; (2) short Japanese runs are slow only with reparse deferral on (6.0 s vs 0.21 s), and only on the call where the input ends 2 bytes into a 3-byte character after text. A first timing mistake (the harness caches the first DLL it loads in a process) was caught and the runs repeated with one DLL per process. |
| **8. Cause** | ✅ **Confirmed** (the fixes remove the slowdown). (1) `parse_prefix_tokens` set the checkpoint at the start of the pending text run, so each call parsed the run again. (2) `should_defer_reparse_callbacks_on_prefix` cuts the partial character off `input_buffer` for a moment; `pending_scan_index` was then past the end, and `pending_markup_start` scanned from byte 1. |
| **9. Fix** | (1) Carry the run's text: checkpoint where parsing stopped inside the run, keep the text so far (`resume_text_carry`), continue with it as the seed. Only when the character data handler alone sees the text, in document content outside an entity; otherwise as before. A trailing `]`/`]]` is parsed again. (2) Clamp `pending_scan_index` to the shortened buffer. |
| **10. Verification** | ✅ Section 3. |

## 3. Verification

✅ = same as the `19ba873` build on the same tier.

| Check | Result | Log |
|---|---|---|
| ✅ DLL build + smoke test, both tiers | ok ×2 | |
| ✅ Split-point check (16 crafted documents: `]]>`, brackets, `&amp;`, general entities, Japanese, CR LF, bad characters, unclosed, …) × deferral on/off × default handler on/off; every split point and byte by byte against the whole parse | 1,852 checks per tier; the results are **identical to the `19ba873` build**. The 73 cases where a split differs from the whole parse exist on both builds (3 error documents: `]]>` in text, an unterminated `&amp`, text after the root with a default handler) | [new](logs/edge-production.txt), [before](logs/edge-production-before.txt), [script](logs/edge11.py) |
| ✅ `XpactDllTests` (4,308 cases) | 4,308 / 4,308 ×2; **`results.tsv` byte-identical**, both tiers | [production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt) |
| ✅ Differential traces (9 runs over the W3C files) | **byte-identical**, both tiers | [production](logs/trace-sha256.txt), [assertions](logs/trace-sha256-assertions.txt) |
| ✅ Chunked CRC harness | identical | [crc](logs/chunked-crc.tsv) |
| ✅ Expat 2.8.1 `runtests`, both tiers | Checks 399, Failed 38 on both tiers: the same 38 allocator tests | [production](logs/expat/runtests-production.txt), [assertions](logs/expat/runtests-assertions.txt) |
| ✅ Test 2, both tiers | **TSV byte-identical** on both tiers (ok 2,564 · xpact-only 16 · both 5) | [production](logs/chunked-textrun-production.tsv), [assertions](logs/chunked-textrun-assertions.tsv) |
| ✅ Eiffel test matrix (4 configurations) | ok (exit 0) | |

## 4. Limitations

- [ ] With a default handler, or inside an entity, a pending text run is still parsed again from its start.
- [ ] Latin-1, ASCII, explicit and unknown encodings still use the full replay (#7 limitation).
- [ ] The 73 split-point differences in error documents (section 3) were there before; not investigated here.
- [ ] Per-call overhead remains: byte by byte is still several times slower than one call.
