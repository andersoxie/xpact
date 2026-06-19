# Benchmarks

Generated: 2026-06-18 20:05:28 +02:00

Machine: AMD64 Family 23 Model 49 Stepping 0, AuthenticAMD; Windows_NT

Runtime context:

- Eiffel benchmark build types: `Finalized, FinalizedAssertions`.
- Eiffel benchmark targets: `xpact_benchmarks` (assertions disabled) and `xpact_benchmarks_assertions` (assertions enabled).
- Eiffel void safety: ``support="all" use="all"``.
- Python: `Python 3.14.0`.
- libexpat baseline available on this machine through CPython `pyexpat`: `expat_2.7.3`.
- No direct C libexpat benchmark was run: WSL2 gcc was not visible to this process. No WSL xpact native C ABI benchmark was run: WSL2 gcc was not visible to this process.

Workload: parse the same UTF-8 catalog document containing 100 `<item>` elements. Each table row reports the median of 3 process-level runs.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 1000 | 2611 | 874.84 | 1143.067 | 2.846 | Parser object reused; no-op event handler; finalized Eiffel C compilation |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, GC suspended during parse | Phase 1 finalized | 1000 | 2611 | 891.838 | 1121.28 | 2.792 | Parser object reused; no-op event handler; finalized Eiffel C compilation; calls parse_without_garbage_collection |
| catalog-100-items | xpact Eiffel finalized, assertions enabled | Phase 1 finalized assertions | 1000 | 2611 | 881.754 | 1134.103 | 2.824 | Parser object reused; no-op event handler; finalized Eiffel C compilation; runtime assertions enabled |
| catalog-100-items | xpact Eiffel finalized, assertions enabled, GC suspended during parse | Phase 1 finalized assertions | 1000 | 2611 | 897.704 | 1113.953 | 2.774 | Parser object reused; no-op event handler; finalized Eiffel C compilation; runtime assertions enabled; calls parse_without_garbage_collection |
| catalog-100-items | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 1000 | 2611 | 204.702 | 4885.143 | 12.164 | Parser created per document; Python callbacks |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 1000 | 2611 | 138.316 | 7229.822 | 18.003 | Parser created per document; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 6044.687 | 165.435 | 0.412 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 3474.593 | 287.804 | 0.717 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 6078.09 | 164.525 | 0.41 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks; XML_ParserReset between documents |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 3420.794 | 292.33 | 0.728 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks; XML_ParserReset between documents |

Raw run data is written to `build\benchmarks\benchmark-results.tsv`.

Interpretation: the `pyexpat` rows are same-machine Expat baselines through CPython's binding. When present, WSL2 C rows compile and link against Ubuntu libexpat directly, but elapsed times are measured from Windows at the process level and include `wsl.exe` launch overhead, so they are conservative for libexpat core throughput.

Native ABI note: the Windows `xpact native C ABI` rows are generated from a C executable linked against `include/xpact.h` and `build\native-eiffel\xpact.lib` and run against the Eiffel-backed `build\native-eiffel\xpact.dll`. Any WSL `xpact native C ABI` status row still targets the older bridge-only `build\native\libxpact.so` path and remains `not measured` until the Linux/WSL Eiffel-backed shared object is packaged.

See `docs/performance-analysis.md` for the current interpretation of the xpact-vs-libexpat performance gap and optimization priorities.

For opt-in macro-benchmarks against caller-supplied, pre-decompressed real XML
corpora, see `docs/large-xml-benchmarks.md`.

## 2026-06-19 Direct Tokenizer Updates

After the slice-backed element stack, no-event attribute parsing, lazy
position accounting, no-event character-data scanning, and normalized-input
aliasing for the safe no-callback `STRING_8` path landed, controlled
post-publication runs were taken against the same catalog workload. These were
not produced by the full publishing script above; they were focused
finalized-build timing runs with five process-level repetitions and the same
1000-document workload.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 1000 | 2611 | 247.600 | 4038.772 | 10.057 | Parser object reused; no-op event handler; finalized Eiffel C compilation; slice/no-event fast paths; normalized `STRING_8` input aliased when safe |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 1000 | 2611 | 111.683 | 8953.914 | 22.296 | Parser created per document; no callbacks; same-run baseline |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, previous focused row | Phase 1 finalized | 1000 | 2611 | 271.328 | 3685.576 | 9.177 | Parser object reused; no-op event handler; finalized Eiffel C compilation; slice/no-event fast paths before normalized-input aliasing |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, GC suspended during parse, previous focused row | Phase 1 finalized | 1000 | 2611 | 276.164 | 3621.037 | 9.017 | Parser object reused; no-op event handler; finalized Eiffel C compilation; slice/no-event fast paths; calls parse_without_garbage_collection |

This reduces the direct Eiffel tokenizer/no-op median from the previous
controlled 774.653 ms measurement to 247.600 ms, about a 68.0% reduction. The
normalized-input alias step alone improved the focused direct row from 271.328 ms
to 247.600 ms, about 8.7%. Against the same-run `pyexpat` tokenizer row, the
remaining direct Eiffel gap is about 2.22x. Compared with the 2026-06-18
published direct Eiffel row of 874.84 ms, the new focused measurement is about
71.7% faster.

## Previous Published Values

The previous published same-machine run was generated on 2026-06-03. Keep these
rows for trend comparison; the WSL2 C rows are historical in the current update
because WSL `gcc` was not visible to the 2026-06-18 benchmark process.

| Engine | Previous median ms | Current median ms | Change |
|---|---:|---:|---:|
| xpact Eiffel finalized, assertions discarded | 851.331 | 874.84 | +2.8% |
| xpact Eiffel finalized, assertions discarded, GC suspended during parse | 860.699 | 891.838 | +3.6% |
| libexpat via CPython pyexpat callbacks | 192.109 | 204.702 | +6.6% |
| libexpat via CPython pyexpat tokenizer | 114.742 | 138.316 | +20.5% |
| xpact native C ABI callbacks via Windows MSVC DLL | 6420.215 | 6044.687 | -5.8% |
| xpact native C ABI tokenizer via Windows MSVC DLL | 3458.657 | 3474.593 | +0.5% |
| xpact native C ABI callbacks via Windows MSVC DLL, parser reused | 6392.354 | 6078.09 | -4.9% |
| xpact native C ABI tokenizer via Windows MSVC DLL, parser reused | 3443.014 | 3420.794 | -0.6% |
| libexpat C callbacks via WSL2 gcc | 105.146 | not measured | n/a |
| libexpat C tokenizer via WSL2 gcc | 100.937 | not measured | n/a |
| xpact native C ABI via WSL2 gcc | not measured | not measured | n/a |
