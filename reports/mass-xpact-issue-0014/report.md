# Report: mass-xpact #14: production DLL was finalized with `-keep`

> **Issue:** [CodTanium/mass-xpact#14](https://github.com/CodTanium/mass-xpact/issues/14) · **Branch:** `perf/finalize-without-keep`, from `student-Mass` @ `253c81e`
> **Changed:** `scripts/build_native_eiffel.ps1` (one `ec` argument), [windows-release.md](../../docs/windows-release.md)
> **Status:** ✅ fixed · ✅ verified locally, both DLL tiers

## 1. In short

The production `xpact.dll` was finalized with `ec -finalize -keep`. With `-keep`, every routine keeps its
assertion code, an exception frame and a GC-local registration, even though the production target
disables all assertions. Without `-keep` the parser does the same work about **3.5 times faster**, and
everything the application sees is the same.

| ✅ Result (production DLL) | With `-keep` | Without |
|---|---:|---:|
| `pr-xml-utf-8.xml` (207 KB), one `XML_Parse` call, no handlers | 61.0 ms | **17.0 ms** |
| `weekly-utf-8.xml` (2.7 KB), one call | 0.76 ms | **0.21 ms** |
| `XML_ParserCreate` + `XML_ParserFree` | 16 µs | **9 µs** |
| Timing tool, `doc-rich.xml` (131 KB), whole / 1-byte pieces | 67.1 / 798.6 ms | **20.0 / 249.7 ms** |
| Test 2 wall time, `--jobs 16` (on top of #11) | 46 s | **30 s** |
| DLL size | 9.9 MB | **1.5 MB** |

Raw rows: [raw timing](logs/raw-timing.txt), [timing tool](logs/timing.tsv). The assertions DLL is
unchanged: it is still built with `-keep` and has the same size as before.

## 2. Problem report

| Field | |
|---|---|
| **1. Problem** | The production DLL spent about a third of its time on the Eiffel exception stack. |
| **2. Environment** | Windows 11, student PC2 (16 logical cores); EiffelStudio 25.12; MSVC (VS 18); Python 3.15 (uv). |
| **3. Command** | `.\scripts\build_native_eiffel.ps1 -BuildTier Production`; then a sampling profiler ([sampler.c](logs/tools/sampler.c)) on a DLL relinked with `-MAP` ([build.ps1](logs/tools/build.ps1)), with the samples mapped to Eiffel features by [report.py](logs/tools/report.py). |
| **4. Expected** | The production build without assertion code, like the other finalized builds: `build_implementations.py`, `run_benchmarks.ps1` and `run_wsl_benchmarks.py` add `-keep` only for the assertion build. |
| **5. Actual** | Profile of whole parses of `pr-xml-utf-8.xml`: `new_exset` 16.3 %, `exget` 15.9 %, `expop` 3.7 % ([profile before](logs/profile-before.txt)). The generated C of `STRING_8.item` had `RTEX`, `RTEAA` and `if ((RTAL & CK_REQUIRE) …)` blocks. |
| **6. Error output** | None: the results were correct, only slow. |
| **7. Investigation** | Test 2's slowest cases were now the 3 KB `weekly-*` files (41 s against Expat's 5 s). Their per-parse cost was fixed (no growth with split points), so I profiled one whole parse. The profile pointed at the exception stack; `scripts/build_native_eiffel.ps1` passes `-keep` for both tiers. |
| **8. Cause** | ✅ **Confirmed** (building without `-keep` removes the exception stack from the profile and gives the speed-up above). |
| **9. Fix** | Pass `-keep` only when `-BuildTier Assertions`. |
| **10. Verification** | ✅ Section 3. |

A trap found on the way is tracked separately as [#15](https://github.com/CodTanium/mass-xpact/issues/15):
`ec` exits 0 when it rejects its options, so the script relinked the old code without an error.

## 3. Verification

Two builds: **A** = `student-Mass` sources + this fix, compared with the `student-Mass` baseline build;
**B** = the #11 branch (`10c8b66`) + this fix, compared with the #11 evidence.

| Check | Result | Log |
|---|---|---|
| ✅ Build + smoke test | ok; the log has `System Recompiled.` | [production](logs/build-production.log), [assertions](logs/build-assertions.log) |
| ✅ `XpactDllTests` (4,308 cases), A | 4,308 / 4,308; **`results.tsv` byte-identical** to the baseline DLL | [baseline](logs/dlltests-baseline-summary.txt), [A](logs/dlltests-nokeep-summary.txt) |
| ✅ `XpactDllTests`, B | 4,308 / 4,308; **`results.tsv` byte-identical** to #11 | [B](logs/dlltests-textrun-nokeep-summary.txt) |
| ✅ Expat 2.8.1 `runtests`, A and B | Checks 399, Failed 38: the same 38 allocator tests | [A](logs/expat/runtests-nokeep.txt), [B](logs/expat/runtests-textrun-nokeep.txt) |
| ✅ Differential traces + chunked CRC, B | **byte-identical** to #11 | [traces](logs/trace-sha256.txt), [crc](logs/chunked-crc.tsv) |
| ✅ Test 2, B | **TSV byte-identical** to #11 (ok 2,564 · xpact-only 16 · both 5) | [tsv](logs/test2-textrun-nokeep-production.tsv), [summary](logs/test2-textrun-nokeep-production-summary.json) |
| ✅ Split-point check (1,852 checks), B | identical to #11 (the same 73 known differences) | [edge](logs/edge-production.txt) |
| ✅ Assertions tier still uses `-keep` | DLL size identical to the baseline assertions DLL (9,935,872 bytes); `XpactDllTests` 4,308 / 4,308, `results.tsv` byte-identical | [summary](logs/dlltests-assertions-summary.txt) |

## 4. What is hot now

[Profile after](logs/profile-after.txt) (whole parses of `pr-xml-utf-8.xml`): `STRING_8.item` 17 %
(with its dispatch wrapper), `reset_hash_codes` 6 % (from `append_character`), `READABLE_STRING_8.capacity`
3.5 %, `note_position` 3.5 %, `put_code` 3 %, plus string allocation (`make_filled`, `spmalloc`,
`special_malloc`). These are the next leads.

## 5. Limitations

- [ ] Only the production DLL build is changed. Other `-finalize -keep` uses are for assertion builds and stay.
- [ ] The Eiffel test matrix was not rerun: it builds its own targets with `run_eiffel_test_matrix.ps1`, which this change does not touch.
- [ ] Test 2 and the traces were run on build B only; build A was checked with the DLL tests and the Expat suite.
- [ ] Release packages built before this change still contain the slow DLL.
