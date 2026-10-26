# PubMed character-data profiling, 26 October 2026

The [text-position follow-up](pubmed-position-performance.md) records the next
profile, allocation-free position batching and the latest direct core
comparison. The tables below retain this earlier campaign's results.

This follows the [first profiling pass](parser-profile-performance.md), where
pinned Xpact-core was 17.7197x faster on sustained PubMed parsing. The next
measured bottleneck was repeated construction of a fixed three-byte marker in
ordinary text. The focused fix improves PubMed throughput by **62.3%** in the
paired before/after run. A fresh direct comparison puts core's remaining lead
at **11.02x**.

Baseline source: `e43ad66`. Optimized source: `a4da007`. Both use Windows x64,
EiffelStudio 25.02.9.8723 and MSVC 19.44.35229. Core remains pinned at
`6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676`. Input is the same original
504,561-byte PubMed extract; no declaration, DOCTYPE or byte rewriting was added.

## Profile and allocation evidence

A fresh eight-document Eiffel profile puts `parse_character_data` at 79.26%
inclusive time and 29.35% exclusive time. Instrumentation inflates small-call
costs, so generated C and optimized COFF object code were also inspected.

The original generic loop constructs `"]]>"` with `RTMS_EX_H` on every byte,
before testing the prefix. The baseline's optimized object code confirms the
`makestr_with_hash` call in that loop. MSVC inlines `has_at` and the XML-character
predicate in the uninstrumented build; treating their profiler call overhead as
production cost would therefore be misleading.

PubMed contains one right bracket, at byte offset 501,669, after its first
entity reference at offset 28,827. That reference moves the existing parser to
the generic eager-position path. Across eight documents, whole-parser
`has_at` calls fall from 2,788,520 to 398,656, eliminating 298,733 ordinary-byte
checks per document. Adding the one surviving generic check establishes
**298,734 original marker-construction invocations per document**. This is a
source/profile derivation, not an allocator-object count or heap-leak test.

The candidate uses a first-byte guard and a private `once` marker in complete,
prefix and no-event character-data scanning. Generated C and COFF confirm a
guarded once lookup with initialization outside recurring construction.
There are three bounded once literals in source, managed as runtime roots.
`has_at` reads its arguments and retains neither; these literals contain no
document references. Parser reset and failure introduce no new cleanup state.

Position handling, entity expansion, callbacks, validation and limits retain
their existing behavior. `note_position` calls remain exactly 3,015,096 across
the eight-document profiles. External resolver observability and entity error
positions therefore do not depend on a new lazy-position shortcut.

## Controlled experiments

Three isolated copies changed only the generic marker condition. Every other
source byte matched the frozen baseline. Each screen used three alternating
AB/BA pairs, one warmup run per executable, and common-count calibration to
at least 0.25 seconds. The second input is plain text following `&amp;`, which
forces the same generic path. Ratios above one favor the candidate.

| Variant | PubMed speed ratio | Text after reference speed ratio |
|---|---:|---:|
| Reuse marker | 1.4537 | 1.8449 |
| Guard first byte | 1.6219 | 2.2426 |
| Guard and reuse | 1.5895 | 2.2553 |

Guard-only and combined results are close on this PubMed input. The combined
change also bounds marker construction when text contains many right brackets.
The final implementation applies that same rule to all three character-data
paths, including the prefix path exercised by native chunk parsing.

## Final before/after throughput

Separate uninstrumented executables use the same file-capable root and parser
adapter. Each process reads its bytes once and reuses its parser. A common
iteration count is calibrated until both samples last at least one second;
two warmup runs per executable precede six alternating AB/BA measurement pairs.
Compilation, tests and profiling finish before timing starts. Process startup,
file reading, setup, reset/reuse and normal GC remain timed.

| Workload | Before MiB/s | After MiB/s | Median paired speed ratio | Pair range |
|---|---:|---:|---:|---:|
| Catalog | 18.425 | 18.124 | 0.9811 | 0.9435–1.0195 |
| Plain text | 52.540 | 53.575 | 1.0156 | 0.9896–1.1894 |
| 50 attributes per item | 25.582 | 28.148 | 1.1003 | 1.0050–1.1595 |
| PubMed extract | 8.899 | 14.499 | 1.6234 | 1.5983–1.6745 |
| Unicode stylesheet | 28.565 | 29.154 | 1.0270 | 0.9823–1.0965 |
| Legislation | 8.737 | 12.187 | 1.4101 | 1.2816–1.4208 |

The predicate directly affects generic text, including PubMed and Legislation.
Control workloads and every outlier are retained. The attribute algorithm is
unchanged; its observed movement is not a second attribute-lookup optimization.
Catalog's -1.9% paired median is small relative to its observed range, but is
reported rather than replaced by a more favorable run.

## Fresh comparison with pinned core

The unchanged core executable and pinned source were verified against the
previous committed evidence. Both engines use the same file-capable root and
unchanged no-op adapters. The common count calibrates both to at least one
second; two warmup runs per executable precede six alternating pairs.

| Optimized xpact MiB/s | Core MiB/s | Core paired speed ratio | Pair range |
|---:|---:|---:|---:|
| 13.846 | 152.916 | 11.0214 | 10.4046–12.4508 |

The common count is 512 documents per sample. Ratios above one
favor core. The previous 17.7197x result and this new comparison are separate
campaigns; the 62.3% improvement comes from the direct before/after pairs, not
from dividing the two independently measured core gaps.

Our GC policy stays normal. Core suspends collection while parsing, performs
full collection on final input, and reuses a prepared codec for unchanged
bytes. This internal behavior remains timed. These are direct Eiffel no-op
measurements, not callback, native ABI, .NET or streaming throughput results.
Core's general XML conformance was not rerun; the file harness checks accepted
documents and exact counts, not event equality with core.

## Correctness and retained evidence

- All 60 regression tests pass in Workbench and Finalized configurations with
  assertions off and on: 240 test/configuration executions.
- All 1,727 applicable W3C cases and 40 directed cases match the baseline in
  both finalized assertion modes, with no verdict or diagnostic differences.
  The W3C profile still explicitly excludes 858 cases.
- New Eiffel cases cover near matches, overlapping/trailing brackets, UTF-8,
  normalized CRLF error positions, legal entity-assembled close characters,
  illegal literal close markers in entity replacements, and repeated recovery.
  The new tests pass against the unchanged baseline as well as the candidate.
- Updated assertion-enabled and production native DLL smoke suites pass.
  The new native sequence rejects a marker split across three chunks, resets,
  accepts escaped text without duplicate/lost bytes, resets, and rejects again.
  All six incremental audit cases pass, including suspend/resume.

The [portable JSON](../benchmarks/results/pubmed-character-data-2026-10-26.json)
contains raw profile rows, all 60 timing pairs, input/source/executable hashes,
build and harness sources, assembly evidence, ablation patches, and validation
summaries. Five TSV companions preserve the measured rows byte for byte.
The previous investigation remains intact and is referenced by its committed
file hash. Local projects and full logs are under
`build/pubmed-profile-20261026/`.

For local reproduction, use the retained executables with
`scripts/compare_eiffel_benchmarks.py` and a fresh output directory. The embedded
ECFs/build scripts identify the frozen baseline and candidate projects. Keep
instrumented profile timings separate from uninstrumented wall-clock results.
