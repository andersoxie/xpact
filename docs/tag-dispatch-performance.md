# Tag-dispatch marker reuse

`XP_PARSER.parse_markup` checks fixed prefixes to distinguish end tags,
comments, CDATA, processing instructions and declarations. Ordinary mutable
manifest strings recreated those prefixes on each call. The 100-item catalog
executes 909 such marker-string constructions per document.

The refinement uses ten private `once` manifest strings. Eiffel manages these
bounded constants as GC roots; they contain no document or parser references.
The prefix helpers read their contents without retaining or modifying them.
The ten objects remain for the runtime's lifetime, with a fixed memory cost.
Parser reset and failure therefore have no new cache state to invalidate.

The original classification order, partial-marker diagnostics, contracts,
character validation and GC policy remain unchanged. The separate ASCII
predicate experiment is not included. Earlier byte-dispatch experiments
motivated checking text-heavy performance as well as the catalog.

## Paired benchmark method

Baseline and candidate executables were freshly built from the same benchmark
ECF and EiffelStudio release on the same computer. The baseline source is
commit `3a5551d`; the candidate changes marker lifetime in `parse_markup`.
Windows uses MSVC 19.44 with the generated `-Ox` options. WSL2 Ubuntu 20.04
uses GCC 9.4 with the generated `-O3` options. Comparisons are within each OS;
they do not isolate compiler differences from OS/runtime differences.

The paired driver runs two untimed warmups and six adjacent measurement
pairs per workload, alternating baseline/candidate and candidate/baseline
order. Both executables use the same iteration count within a pair.
Calibration doubles the common count until both samples last at least one
second. Compilation and functional tests finish before measurement begins.
Timing includes native process startup inside the current OS and excludes
Windows-to-WSL launch overhead.

The reported speed ratio is the median of the six paired baseline-time /
candidate-time ratios. Ratios above 1 favor the candidate. Raw pairs and their
minimum/maximum ratios are retained, including outliers. A 2% median noise
budget was selected for the text-heavy check before final measurement; this
is a local regression check, not a universal performance guarantee.

Workloads include the existing 2,611-byte catalog, a 110,013-byte text-heavy
document, a 12,153-byte attribute-heavy document, the local 504,561-byte PubMed
extract, and the Xpact-core Unicode stylesheet and Legislation XML fixtures.
Real inputs retain their declarations and the parser's existing external
entity policy. These tests measure the direct Eiffel no-op-handler path with
normal GC and parser reuse.

## Results, 2026-10-24/25

Finalized builds with assertions discarded, measured sequentially on the same
computer. Percentages are throughput changes from the median paired ratio;
the ranges show all six individual ratios.

| Workload | MSVC throughput change | MSVC ratio range | WSL2 GCC throughput change | GCC ratio range |
|---|---:|---:|---:|---:|
| Catalog | +31.3% | 1.297–1.338 | +29.6% | 1.246–1.326 |
| Text-heavy | −0.7% | 0.943–1.010 | +0.3% | 0.980–1.212 |
| Attribute-heavy | +0.6% | 1.001–1.053 | +0.1% | 0.761–1.051 |
| PubMed extract | −1.5% | 0.959–1.006 | +0.8% | 0.994–1.013 |
| Unicode stylesheet | +13.5% | 1.098–1.191 | +9.0% | 1.021–1.145 |
| Legislation | −0.3% | 0.981–1.014 | +0.3% | 0.980–1.022 |

The text-heavy medians pass the preselected 2% regression budget on both
platforms. This addresses the earlier prototype's repeatable 4–9% Windows
text regression while retaining a substantial catalog gain. Individual pairs
still vary, especially on GCC; the results do not establish a sub-percent
improvement or regression. PubMed and Legislation show little benefit, so
marker reuse does not address their dominant parsing costs.

With assertions enabled, the catalog improves by 6.7% on MSVC (ratio range
1.041–1.088) and 4.1% on GCC (1.014–1.052). Other workloads were timed only
with assertions discarded. Functional tests exercise both assertion modes.

Raw paired durations and throughput are committed without removing outliers:

- [MSVC, assertions discarded](../benchmarks/results/tag-dispatch-msvc-2026-10-25.tsv)
- [WSL2 GCC, assertions discarded](../benchmarks/results/tag-dispatch-gcc-2026-10-25.tsv)
- [MSVC, assertions enabled](../benchmarks/results/tag-dispatch-msvc-assertions-2026-10-25.tsv)
- [WSL2 GCC, assertions enabled](../benchmarks/results/tag-dispatch-gcc-assertions-2026-10-25.tsv)
- [Build identities, corpus hashes, calibration and summaries](../benchmarks/results/tag-dispatch-2026-10-25.json)

The PubMed extract uses the first 53 complete records described in
[the existing corpus note](large-xml-benchmarks.md). The two Xpact-core inputs
are unchanged files from commit
[`6c017fb5`](https://github.com/andersoxie/Xpact-core/tree/6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676/tools/data).
Their SHA-256 hashes and exact byte counts are in the metadata file.

## Reproduce a comparison

Use two executables built from `benchmarks/xpact_benchmarks.ecf` in separate
project directories, then run the driver inside the OS containing them:

```powershell
python scripts/compare_eiffel_benchmarks.py `
  --baseline C:/baseline/xpact_benchmarks.exe `
  --candidate C:/candidate/xpact_benchmarks.exe `
  --output-dir build/tag-dispatch-comparison `
  --xml-file C:/data/document.xml --xml-iterations 1
```

The default selection includes the three synthetic workloads and any supplied
XML files. `--workload text` selects the text-heavy check alone. The driver
requires a successful exit and the exact parsed-document count before
recording a sample. It rejects inputs that alias generated fixtures or reports
before touching either. For an accepted run, it clears old reports and publishes
`comparison.json` and `comparison.tsv` only after the complete run succeeds.

## Correctness checks

- All 54 Eiffel regression tests pass in workbench/finalized builds with
  assertions off/on. New tests cover malformed prefixes and their exact error
  positions, repeated failure/recovery, mixed declaration callbacks and
  callback-time positions.
- Fresh baseline and candidate match on all 1,727 applicable W3C cases and 40
  directed cases in each finalized assertion mode. The profile excludes 858
  cases; this comparison is not a claim of unrestricted XML conformance.
- The rebuilt Eiffel-backed Windows DLL passes its native smoke test.
- The paired-driver unit tests cover calibration fairness, AB/BA order,
  paired medians, failed-run recovery, child-output validation and cleanup
  after partial report-publication failure. Collision tests verify input and
  report bytes remain intact, including aliases through hard links.
- All 52 Python harness tests pass on Windows; the ten new paired-driver
  tests also pass under WSL Python 3.8.
