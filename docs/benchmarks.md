# Benchmarks

Generated: 2026-05-29 18:59:06 +02:00

Machine: AMD64 Family 23 Model 49 Stepping 0, AuthenticAMD; Windows_NT

Runtime context:

- Eiffel target: `benchmarks\xpact_benchmarks.ecf` built as `Finalized`.
- Eiffel void safety: ``support="all" use="all"``.
- Eiffel assertions in benchmark target: disabled.
- Python: `Python 3.14.0`.
- libexpat baseline available on this machine through CPython `pyexpat`: `expat_2.7.3`.
- No direct C libexpat benchmark was run: WSL2 gcc was not visible to this process. No WSL xpact native C ABI benchmark was run: WSL2 gcc was not visible to this process.

Workload: parse the same UTF-8 catalog document containing 100 `<item>` elements. Each table row reports the median of 3 process-level runs.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 1000 | 2611 | 916.026 | 1091.673 | 2.718 | Parser object reused; no-op event handler; finalized Eiffel C compilation |
| catalog-100-items | xpact Eiffel finalized, assertions discarded, GC suspended during parse | Phase 1 finalized | 1000 | 2611 | 929.653 | 1075.67 | 2.678 | Parser object reused; no-op event handler; finalized Eiffel C compilation; calls parse_without_garbage_collection |
| catalog-100-items | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 1000 | 2611 | 171.388 | 5834.714 | 14.529 | Parser created per document; Python callbacks |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 1000 | 2611 | 107.682 | 9286.638 | 23.124 | Parser created per document; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 6188.694 | 161.585 | 0.402 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 3382.1 | 295.674 | 0.736 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks |
| catalog-100-items | xpact native C ABI callbacks via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 6065.627 | 164.863 | 0.411 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks; XML_ParserReset between documents |
| catalog-100-items | xpact native C ABI tokenizer via Windows MSVC DLL, parser reused | expat_2.8.1-xpact-eiffel-bridge | 1000 | 2611 | 3390.696 | 294.925 | 0.734 | MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks; XML_ParserReset between documents |

Raw run data is written to `build\benchmarks\benchmark-results.tsv`.

Interpretation: the `pyexpat` rows are same-machine Expat baselines through CPython's binding. When present, WSL2 C rows compile and link against Ubuntu libexpat directly, but elapsed times are measured from Windows at the process level and include `wsl.exe` launch overhead, so they are conservative for libexpat core throughput.

Native ABI note: the Windows `xpact native C ABI` rows are generated from a C executable linked against `include/xpact.h` and `build\native-eiffel\xpact.lib` and run against the Eiffel-backed `build\native-eiffel\xpact.dll`. Any WSL `xpact native C ABI` status row still targets the older bridge-only `build\native\libxpact.so` path and remains `not measured` until the Linux/WSL Eiffel-backed shared object is packaged.

See `docs/performance-analysis.md` for the current interpretation of the xpact-vs-libexpat performance gap and optimization priorities.
