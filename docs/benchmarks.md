# Benchmarks

Generated: 2026-05-22 21:34:39 +02:00

Machine: AMD Ryzen Threadripper 3970X 32-Core Processor ; 63.9 GiB RAM; Microsoft Windows 11 Pro

Runtime context:

- Eiffel target: `benchmarks\xpact_benchmarks.ecf` with assertions enabled.
- Python: `Python 3.14.0`.
- libexpat baseline available on this machine through CPython `pyexpat`: `expat_2.7.3`.

Workload: parse the same UTF-8 catalog document containing 100 `<item>` elements. Each table row reports the median of 3 process-level runs.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel, contracts enabled | Phase 1 | 250 | 2611 | 8243.922 | 30.325 | 0.076 | Parser object reused; no-op event handler |
| catalog-100-items | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 250 | 2611 | 107.818 | 2318.72 | 5.774 | Parser created per document; Python callbacks |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 250 | 2611 | 86.017 | 2906.419 | 7.237 | Parser created per document; no callbacks |
| catalog-100-items | libexpat C callbacks via WSL2 gcc | expat_2.2.9 | 250 | 2611 | 129.963 | 1923.621 | 4.79 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; C callbacks; launched through wsl.exe |
| catalog-100-items | libexpat C tokenizer via WSL2 gcc | expat_2.2.9 | 250 | 2611 | 132.837 | 1882.004 | 4.686 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; parser created per document; no callbacks; launched through wsl.exe |

Raw run data is written to `build\benchmarks\benchmark-results.tsv`.

Interpretation: the `pyexpat` rows are same-machine Expat baselines through CPython's binding. The WSL2 C rows compile and link against Ubuntu libexpat directly, but elapsed times are measured from Windows at the process level and include `wsl.exe` launch overhead, so they are conservative for libexpat core throughput.
