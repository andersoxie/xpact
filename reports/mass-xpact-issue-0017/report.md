# Report: mass-xpact #17: production DLL was finalized without Eiffel inlining

> **Issue:** [CodTanium/mass-xpact#17](https://github.com/CodTanium/mass-xpact/issues/17) · **Branch:** `perf/eiffel-inlining`, stacked on `perf/finalize-without-keep` (#14, PR #16)
> **Changed:** `tests/xpact_native_library.ecf`, production target only
> **Status:** ✅ fixed · ✅ verified locally

## 1. In short

The production target now sets `inlining` (size 4) and `array_optimization`. Small routines such as
`STRING_8.item` are compiled into their callers. Whole-document parsing is about **15–20 % faster**;
everything the application sees is the same. The assertions target is unchanged.

| ✅ Result (production DLL, one `XML_Parse` call, no handlers) | #14 only | + inlining |
|---|---:|---:|
| `pr-xml-utf-8.xml` (207 KB), on #11 sources | 17.5–17.7 ms | **14.2–14.3 ms** |
| `pr-xml-utf-8.xml`, on `student-Mass` sources | 17.3–18.2 ms | **15.3–15.7 ms** |
| `weekly-utf-8.xml` (2.7 KB), on #11 sources | 223–224 µs | **182–183 µs** |
| Timing tool `doc-rich.xml` whole, 3 runs | 21.7 / 20.8 / 21.8 ms | **25.4 / 18.0 / 17.8 ms** |
| Timing tool `doc-plain.xml` whole, 3 runs | 8.8 / 8.4 / 8.1 ms | **7.4 / 7.3 / 7.8 ms** |
| DLL size | 1.54 MB | 1.57 MB |

Raw rows: [raw timing](logs/raw-timing.txt), [timing tool, 3 runs](logs/timing.tsv). The timing tool
includes its callbacks, so its gain is smaller (about 10–15 %). Test 2's wall time did not change
measurably (30 s → 34 s, within its noise; the Python harness dominates).

`inlining_size` trial (pr-xml-utf-8, #11 sources): no inlining 17.6 ms · 4: 14.2 ms · 10: 14.2 ms ·
30: 16.0 ms. Size 4 is as fast as 10 and inlines less code; 30 is slower.

## 2. Problem report

| Field | |
|---|---|
| **1. Problem** | Small hot routines were out-of-line C calls. |
| **2. Environment** | Windows 11, student PC2; EiffelStudio 25.12; MSVC (VS 18); Python 3.15 (uv). |
| **3. Command** | Stack-sampling profile ([tools of #14](../mass-xpact-issue-0014/logs/tools/), plus stack unwinding) of whole parses of `pr-xml-utf-8.xml` on the #14 build. |
| **4. Expected** | One-line queries such as `STRING_8.item` inlined into the scanners. |
| **5. Actual** | `STRING_8.item` 14 % self, 17 % in its dispatch wrapper (inclusive); callers spread over `note_position`, `parse_character_data`, `normalized_input`, `find_sequence`, `is_incomplete_utf8_sequence_at`, `parse_comment`, `utf8_character_length` and more. The ECF sets no `inlining`. |
| **6. Error output** | None: only slow. |
| **7. Investigation** | The generated C calls `F793_5598` (`STRING_8.item`) as a function at every use. Builds with `inlining_size` 4, 10 and 30 compared above. |
| **8. Cause** | ✅ **Confirmed** (enabling `inlining` gives the speed-up above). |
| **9. Fix** | `<setting name="inlining" value="true"/>`, `<setting name="inlining_size" value="4"/>` and `<setting name="array_optimization" value="true"/>` in the production target. |
| **10. Verification** | ✅ Section 3. |

## 3. Verification

**A** = `student-Mass` + #14 + this change, compared with #14 alone; **B** = #11 + #14 + this change,
compared with the #11 evidence.

| Check | Result | Log |
|---|---|---|
| ✅ Build + smoke test | `System Recompiled.`, smoke ok | [build](logs/build-production.log) |
| ✅ `XpactDllTests` (4,308 cases), A and B | 4,308 / 4,308 ×2; **`results.tsv` byte-identical** to the build without inlining | [A](logs/dlltests-A-summary.txt), [B](logs/dlltests-B-summary.txt) |
| ✅ Expat 2.8.1 `runtests`, A and B | Checks 399, Failed 38: the same 38 allocator tests | [A](logs/expat/runtests-A.txt), [B](logs/expat/runtests-B.txt) |
| ✅ Differential traces + chunked CRC, B | **byte-identical** | [traces](logs/trace-sha256.txt), [crc](logs/chunked-crc.tsv) |
| ✅ Test 2, B | **TSV byte-identical** (ok 2,564 · xpact-only 16 · both 5) | [tsv](logs/test2-B-production.tsv), [summary](logs/test2-B-production-summary.json) |
| ✅ Split-point check (1,852 checks), B | identical (the same 73 known differences) | [edge](logs/edge-production.txt) |

## 4. Limitations

- [ ] `inlining` and `array_optimization` were enabled together; their separate effects were not measured.
- [ ] The assertions target is not changed: it is the contract-checking build, and speed matters less there.
- [ ] The Eiffel test matrix uses `tests/xpact_tests.ecf`, which this change does not touch; it was not rerun.
- [ ] No new profile after this change yet.
