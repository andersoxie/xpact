# Benchmarks

Generated: 2026-06-03 23:08:16 +02:00

Machine: AMD Ryzen Threadripper 3970X 32-Core Processor ; 63.9 GiB RAM; Microsoft Windows 11 Pro

Runtime context:

- Eiffel target: `benchmarks\xpact_benchmarks.ecf` built as `Finalized`.
- Eiffel void safety: ``support="all" use="all"``.
- Eiffel assertions in benchmark target: disabled.
- Python: `Python 3.14.0`.
- libexpat baseline available on this machine through CPython `pyexpat`: `expat_2.7.3`.

Workload: parse the same UTF-8 catalog document containing 100 `<item>` elements. Each table row reports the median of 3 process-level runs.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 1000 | 2611 | 851.331 | 1174.631 | 2.925 | Parser object reused; no-op event handler; finalized Eiffel C compilation |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, GC suspended during parse | Phase 1 finalized | 1000 | 2611 | 860.699 | 1161.847 | 2.893 | Parser object reused; no-op event handler; finalized Eiffel C compilation; calls parse_without_garbage_collection |
| catalog-100-items | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 1000 | 2611 | 192.109 | 5205.378 | 12.962 | Parser created per document; Python callbacks |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 1000 | 2611 | 114.742 | 8715.227 | 21.701 | Parser created per document; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 6420.215 | 155.758 | 0.388 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 3458.657 | 289.13 | 0.72 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 6392.354 | 156.437 | 0.39 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks; XML_ParserReset between documents |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 3443.014 | 290.443 | 0.723 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks; XML_ParserReset between documents |
| catalog-100-items | libexpat C callbacks via WSL2 gcc | expat_2.2.9 | 1000 | 2611 | 105.146 | 9510.594 | 23.682 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; C callbacks; launched through wsl.exe |
| catalog-100-items | libexpat C tokenizer via WSL2 gcc | expat_2.2.9 | 1000 | 2611 | 100.937 | 9907.15 | 24.669 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; no callbacks; launched through wsl.exe |
| catalog-100-items | xpact native C ABI via WSL2 gcc | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | not measured | not measured | not measured | Compiled and linked through include/xpact.h; XML_Parse reports XML_ERROR_NOT_STARTED because the Eiffel bridge is not connected yet |

Raw run data is written to `build\benchmarks\benchmark-results.tsv`.

Interpretation: the `pyexpat` rows are same-machine Expat baselines through CPython's binding. When present, WSL2 C rows compile and link against Ubuntu libexpat directly, but elapsed times are measured from Windows at the process level and include `wsl.exe` launch overhead, so they are conservative for libexpat core throughput.

Native ABI note: the Windows `xpact native C ABI` rows are generated from a C executable linked against `include/xpact.h` and `build\native-eiffel\xpact.lib` and run against the Eiffel-backed `build\native-eiffel\xpact.dll`. Any WSL `xpact native C ABI` status row still targets the older bridge-only `build\native\libxpact.so` path and remains `not measured` until the Linux/WSL Eiffel-backed shared object is packaged.

See `docs/performance-analysis.md` for the current interpretation of the xpact-vs-libexpat performance gap and optimization priorities.

For opt-in macro-benchmarks against caller-supplied, pre-decompressed real XML
corpora, see `docs/large-xml-benchmarks.md`.
