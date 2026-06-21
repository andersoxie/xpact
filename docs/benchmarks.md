# Benchmarks

Generated: 2026-06-19 22:14:18 +02:00

Machine: AMD Ryzen Threadripper 3970X 32-Core Processor ; 63.9 GiB RAM; Microsoft Windows 11 Pro

Runtime context:

- Eiffel benchmark build types: `Finalized, FinalizedAssertions`.
- Eiffel benchmark targets: `xpact_benchmarks` (assertions disabled) and `xpact_benchmarks_assertions` (assertions enabled).
- Eiffel void safety: ``support="all" use="all"``.
- Python: `Python 3.14.0`.
- libexpat baseline available on this machine through CPython `pyexpat`: `expat_2.7.3`.

Workload: parse the same UTF-8 catalog document containing 100 `<item>` elements. Each table row reports the median of 3 process-level runs.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 1000 | 2611 | 193.8 | 5159.961 | 12.849 | Parser object reused; no-op event handler; finalized Eiffel C compilation |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, GC suspended during parse | Phase 1 finalized | 1000 | 2611 | 194.754 | 5134.672 | 12.786 | Parser object reused; no-op event handler; finalized Eiffel C compilation; calls parse_without_garbage_collection |
| catalog-100-items | xpact Eiffel finalized, assertions enabled | Phase 1 finalized assertions | 1000 | 2611 | 199.462 | 5013.484 | 12.484 | Parser object reused; no-op event handler; finalized Eiffel C compilation; runtime assertions enabled |
| catalog-100-items | xpact Eiffel finalized, assertions enabled, GC suspended during parse | Phase 1 finalized assertions | 1000 | 2611 | 190.243 | 5256.427 | 13.089 | Parser object reused; no-op event handler; finalized Eiffel C compilation; runtime assertions enabled; calls parse_without_garbage_collection |
| catalog-100-items | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 1000 | 2611 | 208.242 | 4802.103 | 11.957 | Parser created per document; Python callbacks |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 1000 | 2611 | 136.86 | 7306.764 | 18.194 | Parser created per document; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 6475.666 | 154.424 | 0.385 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 805.676 | 1241.193 | 3.091 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 5842.685 | 171.154 | 0.426 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks; XML_ParserReset between documents |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 779.704 | 1282.539 | 3.194 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks; XML_ParserReset between documents |
| catalog-100-items | libexpat C callbacks via WSL2 gcc | expat_2.2.9 | 1000 | 2611 | 99.917 | 10008.287 | 24.921 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; C callbacks; launched through wsl.exe |
| catalog-100-items | libexpat C tokenizer via WSL2 gcc | expat_2.2.9 | 1000 | 2611 | 100.23 | 9977.063 | 24.843 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; no callbacks; launched through wsl.exe |
| catalog-100-items | xpact native C ABI via WSL2 gcc | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | not measured | not measured | not measured | Compiled and linked through include/xpact.h; XML_Parse reports XML_ERROR_NOT_STARTED because the Eiffel bridge is not connected yet |

Raw run data is written to `build\benchmarks\benchmark-results.tsv`.

Interpretation: the `pyexpat` rows are same-machine Expat baselines through CPython's binding. When present, WSL2 C rows compile and link against Ubuntu libexpat directly, but elapsed times are measured from Windows at the process level and include `wsl.exe` launch overhead, so they are conservative for libexpat core throughput.

Native ABI note: the Windows `xpact native C ABI` rows are generated from a C executable linked against `include/xpact.h` and `build\native-eiffel\xpact.lib` and run against the Eiffel-backed `build\native-eiffel\xpact.dll`. Any WSL `xpact native C ABI` status row still targets the older bridge-only `build\native\libxpact.so` path and remains `not measured` until the Linux/WSL Eiffel-backed shared object is packaged.

See `docs/performance-analysis.md` for the current interpretation of the xpact-vs-libexpat performance gap and optimization priorities.

For opt-in macro-benchmarks against caller-supplied, pre-decompressed real XML
corpora, see `docs/large-xml-benchmarks.md`.

## 2026-06-19 Focused Performance Updates

After the slice-backed element stack, no-event attribute parsing, lazy
position accounting, no-event character-data scanning, normalized-input
aliasing for the safe no-callback `STRING_8` path, direct ASCII XML-character
checks, direct ASCII name-character checks, and inlined `scan_name` landed,
controlled post-publication runs were taken against the same catalog workload.
The native no-callback path was also rerun after avoiding eager context-buffer
copies when no native callbacks can observe parser positions. These rows were
not produced by the full publishing script above; they were focused
finalized-build timing runs against the same 1000-document workload.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 1000 | 2611 | 184.700 | 5414.185 | 13.482 | Parser object reused; no-op event handler; finalized Eiffel C compilation; slice/no-event fast paths; normalized `STRING_8` input aliased when safe; direct ASCII character/name checks; inlined name scanner |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 1000 | 2611 | 115.293 | 8673.553 | 21.598 | Parser created per document; no callbacks; same-run baseline |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 787.427 | 1269.959 | 3.162 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks; parser created per document; optimized direct core; no eager context copy without callbacks |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 784.110 | 1275.331 | 3.176 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks; XML_ParserReset between documents; optimized direct core; no eager context copy without callbacks |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, previous focused row | Phase 1 finalized | 1000 | 2611 | 247.600 | 4038.772 | 10.057 | Parser object reused; no-op event handler; finalized Eiffel C compilation; slice/no-event fast paths; normalized `STRING_8` input aliased when safe |
| catalog-100-items | libexpat via CPython pyexpat tokenizer, previous same-run focused row | expat_2.7.3 | 1000 | 2611 | 111.683 | 8953.914 | 22.296 | Parser created per document; no callbacks; same-run baseline |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, earlier focused row | Phase 1 finalized | 1000 | 2611 | 271.328 | 3685.576 | 9.177 | Parser object reused; no-op event handler; finalized Eiffel C compilation; slice/no-event fast paths before normalized-input aliasing |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, GC suspended during parse, earlier focused row | Phase 1 finalized | 1000 | 2611 | 276.164 | 3621.037 | 9.017 | Parser object reused; no-op event handler; finalized Eiffel C compilation; slice/no-event fast paths; calls parse_without_garbage_collection |

This reduces the direct Eiffel tokenizer/no-op median from the previous
controlled 774.653 ms measurement to 184.700 ms, about a 76.2% reduction. The
latest ASCII/name-scanner work improved the focused direct row from 247.600 ms
to 184.700 ms, about 25.4%. Against the same-run `pyexpat` tokenizer row, the
remaining direct Eiffel gap is about 1.60x. Compared with the 2026-06-18
published direct Eiffel row of 874.84 ms, the new focused measurement is about
78.9% faster. The native tokenizer rows also improved substantially versus the
2026-06-18 publication, from 3474.593 ms to 787.427 ms for parser creation per
document and from 3420.794 ms to 784.110 ms with parser reuse.

## Previous Published Values

The previous published same-machine run was generated on 2026-06-03. Keep these
rows for trend comparison against the current 2026-06-19 full publication.

| Engine | Previous median ms | Current median ms | Change |
|---|---:|---:|---:|
| xpact Eiffel finalized, assertions discarded | 851.331 | 193.8 | -77.2% |
| xpact Eiffel finalized, assertions discarded, GC suspended during parse | 860.699 | 194.754 | -77.4% |
| libexpat via CPython pyexpat callbacks | 192.109 | 208.242 | +8.4% |
| libexpat via CPython pyexpat tokenizer | 114.742 | 136.86 | +19.3% |
| xpact native C ABI callbacks via Windows MSVC DLL | 6420.215 | 6475.666 | +0.9% |
| xpact native C ABI tokenizer via Windows MSVC DLL | 3458.657 | 805.676 | -76.7% |
| xpact native C ABI callbacks via Windows MSVC DLL, parser reused | 6392.354 | 5842.685 | -8.6% |
| xpact native C ABI tokenizer via Windows MSVC DLL, parser reused | 3443.014 | 779.704 | -77.4% |
| libexpat C callbacks via WSL2 gcc | 105.146 | 99.917 | -5.0% |
| libexpat C tokenizer via WSL2 gcc | 100.937 | 100.23 | -0.7% |
| xpact native C ABI via WSL2 gcc | not measured | not measured | n/a |
