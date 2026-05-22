# Benchmarks

Generated: 2026-05-22 19:15:45 +02:00

Machine: AMD64 Family 23 Model 49 Stepping 0, AuthenticAMD; Windows_NT

Runtime context:

- Eiffel target: `benchmarks\xpact_benchmarks.ecf` with assertions enabled.
- Python: `Python 3.14.0`.
- libexpat baseline available on this machine through CPython `pyexpat`: `expat_2.7.3`.
- No direct C libexpat benchmark was run: cl, clang, gcc were not on PATH in this session.

Workload: parse the same UTF-8 catalog document containing 100 `<item>` elements. Each table row reports the median of 3 process-level runs.

| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| catalog-100-items | xpact Eiffel, contracts enabled | Phase 1 | 250 | 2611 | 8339.71 | 29.977 | 0.075 | Parser object reused; no-op event handler |
| catalog-100-items | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 250 | 2611 | 102.403 | 2441.33 | 6.079 | Parser created per document; Python callbacks |
| catalog-100-items | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 250 | 2611 | 87.611 | 2853.52 | 7.105 | Parser created per document; no callbacks |

Raw run data is written to `build\benchmarks\benchmark-results.tsv`.

Interpretation: the libexpat rows are same-machine Expat baselines through CPython's binding, not a direct C executable. The callback row includes Python callback overhead; the tokenizer row shows the lower-overhead binding path available in this environment.
