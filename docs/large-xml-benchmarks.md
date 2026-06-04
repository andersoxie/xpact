# Large XML Benchmarks

Generated: 2026-06-04 08:09:55 +02:00

Machine: AMD Ryzen Threadripper 3970X 32-Core Processor ; 63.9 GiB RAM; Microsoft Windows 11 Pro

Runtime context:

- Inputs are real XML files supplied by the caller and must already be decompressed.
- Current first slice is a whole-file benchmark: each engine loads the complete XML file before parsing.
- Maximum accepted file size for this run: 524288 bytes.
- Eiffel target: `benchmarks\xpact_benchmarks.ecf` built as `Finalized`.
- Python: `Python 3.14.0`.
- CPython pyexpat baseline: `expat_2.7.3`.

Corpus note: `pubmed26n1380-first-records-512k` is a valid XML subset derived
from official PubMed update file `pubmed26n1380.xml.gz`. The subset keeps the
original XML declaration, DOCTYPE, root element, and the first 53 complete
`PubmedArticle` records. It is capped at 512 KiB for this first comparison.

| Corpus | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| pubmed26n1380-first-records-512k | xpact Eiffel finalized, assertions discarded | Phase 1 finalized | 1 | 504561 | 6724.675 | 0.148706 | 0.072 | Whole pre-decompressed XML file loaded into Eiffel STRING_8; no-op event handler |
| pubmed26n1380-first-records-512k | xpact Eiffel finalized, assertions discarded, GC suspended during parse | Phase 1 finalized | 1 | 504561 | 6854.646 | 0.145886 | 0.07 | Whole pre-decompressed XML file loaded into Eiffel STRING_8; no-op event handler; calls parse_without_garbage_collection |
| pubmed26n1380-first-records-512k | libexpat via CPython pyexpat tokenizer | expat_2.7.3 | 1 | 504561 | 91.006 | 10.988286 | 5.287 | Whole pre-decompressed XML file loaded by Python; no callbacks |
| pubmed26n1380-first-records-512k | libexpat via CPython pyexpat callbacks | expat_2.7.3 | 1 | 504561 | 97.017 | 10.307472 | 4.96 | Whole pre-decompressed XML file loaded by Python; Python callbacks |
| pubmed26n1380-first-records-512k | libexpat C tokenizer via WSL2 gcc | expat_2.2.9 | 1 | 504561 | 107.954 | 9.263188 | 4.457 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; whole pre-decompressed XML file loaded by C; no callbacks; launched through wsl.exe |
| pubmed26n1380-first-records-512k | libexpat C callbacks via WSL2 gcc | expat_2.2.9 | 1 | 504561 | 113.468 | 8.813034 | 4.241 | gcc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0; whole pre-decompressed XML file loaded by C; C callbacks; launched through wsl.exe |

Raw run data is written to `build\large-xml-benchmarks\large-xml-benchmark-results.tsv`.

Interpretation: this is a macro-benchmark companion to `docs\benchmarks.md`. It intentionally uses caller-supplied real XML corpora and does not include download or decompression time. Because the current Eiffel parser consumes a complete `STRING_8`, these rows are not a substitute for the future Phase 2 byte-buffer streaming benchmark.

First comparison note: on this 512 KiB real-data subset, direct Eiffel xpact is
roughly 62x slower than the WSL2 direct C libexpat tokenizer row and roughly 74x
slower than the CPython `pyexpat` tokenizer row. Temporary GC suspension does
not improve this workload.
