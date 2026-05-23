# Benchmarks

Generated: 2026-05-23 06:06:30 +02:00

Machine: AMD Ryzen Threadripper 3970X 32-Core Processor ; 63.9 GiB RAM; Microsoft Windows 11 Pro

Runtime context:

- Eiffel target: `benchmarks\xpact_benchmarks.ecf` built as `Finalized`.
- Python: `Python 3.14.0`.
- libexpat baseline available on this machine through CPython `pyexpat`: `expat_2.7.3`.

Workload: parse the same UTF-8 catalog document containing 100 `<item>` elements. Each table row reports the median of 3 process-level runs.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 250 | 2611 | 112.569 | 2220.858 | 5.53 | Parser object reused; no-op event handler; finalized Eiffel C compilation |
| catalog-100-items | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 250 | 2611 | 104.902 | 2383.17 | 5.934 | Parser created per document; Python callbacks |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 250 | 2611 | 86.846 | 2878.652 | 7.168 | Parser created per document; no callbacks |
| catalog-100-items | libexpat C callbacks via WSL2 gcc | expat_2.2.9 | 250 | 2611 | 134.633 | 1856.897 | 4.624 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; C callbacks; launched through wsl.exe |
| catalog-100-items | libexpat C tokenizer via WSL2 gcc | expat_2.2.9 | 250 | 2611 | 138.4 | 1806.362 | 4.498 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; no callbacks; launched through wsl.exe |
| catalog-100-items | xpact native C ABI via WSL2 gcc | expat_2.8.1-xpact-eiffel-bridge | 250 | 2611 | not measured | not measured | not measured | Compiled and linked through include/xpact.h; XML_Parse reports XML_ERROR_NOT_STARTED because the Eiffel bridge is not connected yet |

Raw run data is written to `build\benchmarks\benchmark-results.tsv`.

Interpretation: the `pyexpat` rows are same-machine Expat baselines through CPython's binding. The WSL2 C rows compile and link against Ubuntu libexpat directly, but elapsed times are measured from Windows at the process level and include `wsl.exe` launch overhead, so they are conservative for libexpat core throughput.

Native ABI note: the `xpact native C ABI` row is generated from a C executable linked against `include/xpact.h` and `build\native\libxpact.so`. Until the Eiffel bridge is connected, it is reported as `not measured` when `XML_Parse` returns `XML_ERROR_NOT_STARTED`.
