# Parser profiling and optimization, 26 October 2026

The [PubMed character-data follow-up](pubmed-character-data-performance.md)
measures the next optimization and revised core gap. The tables below retain
this earlier campaign's results.

Profiling found repeated document-prefix position scans and quadratic duplicate
attribute searches. The changes substantially improve the two real XML process
latency workloads and the attribute-heavy workload. Catalog throughput remains
approximately unchanged, and pinned Xpact-core retains a performance advantage.

The source baseline is `ba7e264`; the optimized parser is `2892437`. Both use
Windows x64, EiffelStudio 25.02.9.8723 and MSVC 19.44.35229. Core remains pinned
at `6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676`. This report does not combine these
results with older June measurements or cross-platform timings.

## What the profiles showed

An isolated finalized build enabled Eiffel routine profiling in its ECF. The
raw `profinfo` contains inclusive time, descendant time, call count and routine
identity. Exclusive time here is inclusive minus descendant time. Application
profiling and precompiled suppliers can distort small-call costs and inlining;
the performance tables below use separate uninstrumented executables.

- PubMed: `recompute_position_from_start` consumed 6.156 of 7.422 instrumented
  seconds (82.95%) and ran 6,718 times. Entity processing switched positions to
  eager accounting, after which ordinary end-tag rewinds repeatedly scanned the
  document prefix. The final profile makes one such call.
- Attribute workload: 100 parses of 20 tags with 50 attributes performed
  2,450,000 name-range comparisons, exactly `100 * 20 * C(50, 2)`. The final
  profile makes 240,000 of the old range comparisons; larger sets use hashing.
- Text: normalization made 11,001,300 calls to the generic XML-character
  predicate. Direct ASCII checks remove those calls while preserving the XML
  Char production, CR normalization and the existing UTF-8 path. The profile's
  large time change is not an uninstrumented speedup claim.

## Focused changes and lifecycle

1. `b8fda38`: update backward positions over the intervening bytes. Rewinds
   within a line subtract the byte distance directly. Cross-line rewinds count
   removed line feeds and recover the target column. Public positions remain
   eager where required. The target-one boundary avoids `last_index_of(0)`.
   No cache, retained buffer or new parser state is added.
2. `33d3e5a`: keep the small attribute path through 16 attributes, then use a
   private per-tag hash index. It stores integer ranges and hashes, compares
   complete names on hash collisions, grows below excessive occupancy, and
   preserves limits and fallback parsing. The object and old growth arrays
   become collectible when their local calls return. It never stores input
   references and introduces no reset or cross-document cache obligation.
   An eight-attribute prototype slowed the nine-attribute case; the final
   threshold was raised. The prototype screen and count sweep remain local.
3. `2892437`: specialize the two normalization ASCII branches. Exhaustive tests
   retain TAB/LF/CR and DEL acceptance and reject forbidden controls before
   callbacks. Whole-input validation is preserved.

The source lifecycle and reference ownership were reviewed separately from
parsing behavior. These checks are not an allocator-level leak measurement.

## Before and after: one-document process latency

Each sample starts a new process and parses one original XML file. It includes
startup, file reading, setup, parsing and teardown. There are two warmup runs
per executable and six alternating AB/BA pairs, with no minimum-duration calibration
for these two workloads. Common iteration count stays one because calibrating
the faster candidate to one second would make the old parser samples very long.

| Workload | Before ms | After ms | Median paired speedup | Pair range |
|---|---:|---:|---:|---:|
| PubMed extract | 6,250.91 | 72.77 | 85.80x | 81.72–92.88 |
| Legislation | 2,527.26 | 63.90 | 39.48x | 33.14–42.55 |

## Before and after: repeated parsing

The same immutable bytes and parser are reused within each process. Both
samples use a common calibrated count and last at least one second. Two warmup
runs per executable precede six alternating pairs. Rates are medians of the individual
sample rates; the ratio is the median of paired time ratios.

| Workload | Before MiB/s | After MiB/s | Paired speed ratio | Pair range |
|---|---:|---:|---:|---:|
| Catalog | 18.021 | 18.230 | 1.0059 | 0.9826–1.0884 |
| Text-heavy | 52.959 | 52.060 | 0.9751 | 0.6645–1.1693 |
| 50 attributes per item | 10.959 | 27.623 | 2.5424 | 2.4278–2.6200 |
| Unicode stylesheet | 28.030 | 28.823 | 1.0285 | 0.9885–1.1031 |

The first text series was particularly variable. A predeclared follow-up used
the same binaries, six new alternating pairs, two warmup runs per executable,
and a two-second
minimum sample. Its paired ratio was **0.9945**
(range 0.8278–1.2870),
with 52.669 versus 52.058 MiB/s. Both series are retained; the initial series
has not been replaced. These measurements do not establish a text-throughput improvement.

## Optimized parser versus pinned core

These file-capable binaries use the same scratch root and the existing
dual-catalog adapters. All six original inputs were accepted, and every timed
sample must report the exact successful document count. Whole-process timing
includes once-per-process input preparation, parser reuse/reset and each
implementation's GC behavior. Both samples are calibrated to at least one
second; two warmup runs per executable precede six alternating pairs.

Our parser retains normal GC. Core disables collection while parsing and
performs a full collection on final input; its adapter reuses a prepared codec
for unchanged bytes. That work is timed. Both use their default non-namespace
name mode, finalized assertions-discarded builds, and no-op event handling.

| Workload | Optimized xpact MiB/s | Core MiB/s | Core speed ratio | Pair range |
|---|---:|---:|---:|---:|
| Catalog | 18.094 | 43.467 | 2.4156 | 2.3300–2.4784 |
| Text-heavy | 51.309 | 512.990 | 9.9946 | 8.0748–14.7876 |
| 50 attributes per item | 26.572 | 52.766 | 1.9634 | 1.9289–2.1859 |
| PubMed extract | 8.756 | 154.157 | 17.7197 | 17.4033–18.5900 |
| Unicode stylesheet | 28.308 | 126.785 | 4.4657 | 4.3900–4.5469 |
| Legislation | 8.656 | 99.638 | 11.5461 | 11.1837–12.5839 |

A ratio above one favors core. The sustained file comparison amortizes startup
and reuses input preparation, so its absolute values cannot be combined with
the one-document latency table to derive a three-way comparison.

The unchanged qualified catalog runner was also rebuilt and rerun independently:
**18.019 MiB/s xpact versus 44.675 MiB/s core**, with a median paired core
advantage of **2.5045** (range 2.3748–2.5583), at 32,000 documents per sample.
All five directed controls passed in both assertion configurations for each
implementation. Its different root and measurement campaign remain separate
from the generic file results above.

## Correctness evidence and scope

- All 58 Eiffel regression tests pass in Workbench and Finalized builds, with
  assertions off and on: 232 test/configuration executions. New cases cover
  backward callback and error positions, normalized CR/CRLF, UTF-8 byte columns,
  external fragments, entity-driven eager positions, repeated failure/recovery,
  hash collisions, table growth, entity fallback and 504 ASCII parses per lane.
- The optimized parser passes all 1,727 applicable W3C cases in each finalized
  assertion mode, matching the independently rebuilt baseline with no outcome
  or diagnostic differences. The selected profile explicitly excludes 858 cases.
  All 40 additional directed cases also match in both modes.
- The 45 attribute fixtures pass with baseline and final binaries in both
  assertion modes: 180 executions, including 1,024/1,025 attribute limits.
- Fresh assertion-enabled and production Eiffel-backed native DLL smoke suites
  pass. All six incremental shim audit cases pass, including suspend/resume and
  bounded input context.

The broad file timing root qualifies acceptance and count protocol, not event
equality or file-specific conformance for core. Core's general conformance was
not rerun in this investigation; see the existing [dual W3C results](dual-w3c-lane.md).
These throughput results do not measure user callbacks, native ABI or .NET
performance, streaming, or another compiler/OS.

## Evidence and reproduction

The [portable JSON](../benchmarks/results/parser-profile-2026-10-26.json) retains
all raw pairs and outliers, source/executable/input hashes, actual revisions,
profile rows, correctness summaries, exact scratch root/configuration sources
and build provenance. Its raw TSV companions preserve the measured rows.
Older manifests used to prepare the scratch configurations are labelled
template provenance; they do not identify the parser revision actually measured.

The complete local investigation is under `build/parser-profile-20261025/`.
The independently qualified catalog run is
`build/dual-catalog/20261025T230545Z-f16cd5a6d5b9/`. Its supported reproduction is:

```powershell
./scripts/run_dual_catalog.ps1 -Offline
```

The generic file benchmark root and ECF sources are embedded in the portable
JSON. The preserved local binaries can be compared with
`scripts/compare_eiffel_benchmarks.py` using a fresh output directory. Keep
one-document latency and calibrated repeated parsing as separate campaigns.
