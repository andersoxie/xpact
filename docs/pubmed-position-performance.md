# PubMed text-position profiling, 26 October 2026

The [DOCTYPE follow-up](pubmed-doctype-performance.md) records the next
core comparison and bounded no-op element-name/attribute path change.
The measurements below retain this earlier campaign's provenance.

This follows the [character-data marker study](pubmed-character-data-performance.md),
which left a measured 11.02x PubMed gap to pinned Xpact-core. The next profile
showed repeated position bookkeeping in discarded ordinary text. Batching that
work and skipping UTF-8 tail checks for ASCII improve PubMed throughput by
**20.4%** in the direct before/after comparison. The fresh core
comparison measures a remaining **8.99x** lead for core.

Baseline source: `622d826`. Optimized source: `50269ff`. Both use Windows x64,
EiffelStudio 25.02.9.8723 and MSVC 19.44.35229 on the same computer. Core stays
at `6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676`. The original 504,561-byte PubMed
extract retains its declaration, DOCTYPE and bytes. Older reports keep their
own measurements and source identities.

## What the profiles showed

Eight-document Eiffel profiles use source matching the frozen baseline and
candidate. The baseline profiling executable is retained from the preceding
study, with its complete parser source verified against this baseline; it was
run again for this profile. The candidate profile uses a separate new build.

| Routine | Baseline calls | Candidate calls |
|---|---:|---:|
| `parse_character_data` | 113,568 | 113,568 |
| `note_position` | 3,015,096 | 821,528 |
| `bounded_position_index` | 3,015,104 | 821,536 |
| `advance_position_to` | 2,923,840 | 730,272 |
| `is_incomplete_utf8_sequence_at` | 2,511,616 | 171,080 |
| `is_xml_character_code` | 2,479,328 | 2,479,328 |

The candidate removes 72.8% of position calls and 93.2% of UTF-8 tail-helper
calls on this input. The XML-character predicate count remains unchanged.
The baseline places `note_position` at 36.50% inclusive instrumented time;
the candidate places it at 17.30%. Routine instrumentation changes inlining
and adds overhead, so these times locate work rather than establish production
speedups. The performance tables use separate uninstrumented executables.

## Change and state lifecycle

The complete and prefix character-data routines retain a local integer for
the last ordinary byte whose position update is pending. They commit it when
leaving an allocation-free, discarded text span. This reduces repeated calls
while preserving the position of the last processed byte, including included
entity text whose surrounding loop performs no position update.

Positions are still committed before references and their resolver/default
callbacks, right-bracket checks, invalid or incomplete characters, and string
appends that may allocate. Materialized text keeps its per-byte append-time
positions. A special boundary clears the pending integer before handling its
event or error. Reference-only endings therefore cannot replay an older span
or leave an incorrect byte count.

Each routine invocation owns its pending integer, including recursive entity
parsing. It stores no input reference, survives no return, and needs no reset,
cache invalidation or cleanup. The change adds no parser cache, pool or new
owned buffer. GC policy, eager-position requirements, entity expansion,
callbacks, whole-input validation and limits retain their existing behavior.
These lifecycle checks are separate from allocator-level leak measurements.

The complete, prefix and no-event character-data paths also call the incomplete
UTF-8 helper only for bytes at or above 128. ASCII cannot begin an incomplete
UTF-8 sequence; XML-character checks still validate those bytes. High bytes
retain the existing validation and partial-character handling.

## Controlled screens

Each valid screen uses three sequential alternating AB/BA pairs, one warmup
run per executable and common-count calibration to at least 0.25 seconds.
The synthetic input places a long plain-text run after `&amp;`, exercising the
same generic path. Ratios above one favor the candidate; the ranges retain
every measured pair.

| Variant | PubMed paired ratio (range) | Text after reference paired ratio (range) |
|---|---:|---:|
| One-byte position step | 1.0755 (1.0057–1.1000) | 1.2151 (1.2025–1.2218) |
| ASCII guard | 1.0738 (1.0698–1.1963) | 1.2405 (1.1968–1.5490) |
| Position batching | 1.1183 (1.1047–1.1195) | 0.9841 (0.9461–1.0863) |
| Batching and ASCII guard | 1.2040 (1.0275–1.2091) | 1.2123 (0.7536–1.3224) |

The one-byte step experiment specializes the common next-byte update inside
`note_position`. The batch experiment instead reduces calls for discarded
literal spans. The selected production change combines batching with the
ASCII guard. These exploratory ranges do not establish a precise ranking
between nearby variants; the six-pair measurements below assess the final code.

An initial batch screen overlapped baseline test compilation and execution.
It is explicitly marked invalid and excluded from performance decisions and
clean summaries. Its original JSON, annotation and raw rows remain available
for audit; the valid batch and combined screens were run after build/test
processes stopped.

## Final before/after throughput

Finalized assertion-discarded builds use the same whole-file root and unchanged
no-op parser adapter. Each process prepares its input once and reuses a parser.
Common counts calibrate both executables to samples lasting at least one
second. Two warmup runs per executable precede six sequential measurement
pairs in alternating AB/BA order. Builds, tests and profiling finish before
timing. Process startup, file reading, setup, reset/reuse and normal GC remain
timed. All outliers are retained.

| Workload | Before MiB/s | After MiB/s | Median paired speed ratio | Pair range |
|---|---:|---:|---:|---:|
| Catalog | 17.921 | 17.795 | 0.9912 | 0.8501–1.0029 |
| Plain text | 51.657 | 51.735 | 0.9992 | 0.8358–1.0177 |
| 50 attributes per item | 27.026 | 26.820 | 0.9996 | 0.8817–1.0344 |
| PubMed extract | 14.037 | 16.927 | 1.2039 | 1.1394–1.2413 |
| Unicode stylesheet | 28.335 | 28.273 | 0.9963 | 0.9109–1.1108 |
| Legislation | 12.196 | 13.937 | 1.1447 | 1.1254–1.2072 |

The paired median is computed from each pair's elapsed-time ratio; it can
differ from dividing independently calculated median throughputs. Control
workloads retain their observed gains and regressions. The results apply to
these documents and host conditions.

## Fresh PubMed comparison with pinned core

The direct comparison uses the verified retained core executable with the
same file-capable root, document and no-op adapter boundary. It follows the
same one-second calibration, two warmups per executable and six alternating
pairs. The calibrated common count is **512 documents per
sample**. Ratios above one favor core.

| Optimized xpact MiB/s | Core MiB/s | Core paired speed ratio | Pair range |
|---:|---:|---:|---:|
| 16.969 | 152.020 | 8.9949 | 8.8064–9.3773 |

Our parser uses normal GC. Core suspends collection while parsing, performs
a full collection on final input and reuses a prepared codec for unchanged
immutable document bytes. Those costs and benefits remain inside the timed
path. This is an end-to-end comparison of the actual implementations, with
different internal GC and input-preparation policies. It does not isolate
scanner speed or measure callback, native ABI, .NET or streaming throughput.

The earlier 11.02x result and this result are separate campaigns. The PubMed
improvement stated above comes from the new direct before/after pairs rather
than division of independently measured core gaps. Core's general W3C campaign
was not rerun; file timing checks acceptance and exact document counts.

## Correctness and evidence

- All 62 Eiffel regression tests pass in Workbench and Finalized builds with
  assertions off and on: 248 test/configuration executions. The new tests also
  pass in an assertion-enabled Workbench build of the frozen baseline.
- All 1,727 applicable W3C cases and 40 directed cases pass for both baseline
  and candidate in each finalized assertion configuration, with no verdict or
  diagnostic differences. The profile explicitly excludes 858 W3C cases.
- New tests preserve resolver positions after multiline ordinary text,
  malformed replacement-markup diagnostics and checkpoints, final versus
  non-final partial UTF-8 positions, callback byte counts, reference-only
  endings and repeated failure/recovery. Existing bracket, CRLF, entity,
  cached-DOCTYPE and callback-position tests remain green.
- Production and assertion-enabled native DLL smoke suites pass. All six
  incremental audit cases pass, including suspension/resumption and bounded
  input-context behavior.

The [portable evidence](../benchmarks/results/pubmed-position-2026-10-26.json)
contains raw profiles, clean screen and final timing pairs, the explicitly
excluded overlap screen, source/input/executable hashes, validation summaries,
generated C and COFF context, and reproduction sources. TSV companions retain
the measured rows without dropping outliers. The preceding portable JSON report
is referenced by its file hash and remains unchanged.

Local projects and complete logs are under `build/pubmed-position-20261026/`.
For reproduction, use the retained executables and
`scripts/compare_eiffel_benchmarks.py` with a fresh output directory; the
evidence embeds the ECFs and build commands. Keep instrumented profile times
separate from uninstrumented wall-clock measurements.
