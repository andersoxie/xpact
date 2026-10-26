# PubMed DOCTYPE path and core comparison, 26 October 2026

This follows the [text-position study](pubmed-position-performance.md), whose
fresh PubMed comparison measured an 8.99x lead for pinned Xpact-core. A source
comparison found that an unloaded external DOCTYPE disabled xpact's existing
element-name slices and no-event attribute scanner. Enabling that path for a
strictly bounded no-op case improves PubMed throughput by **19.7%**
in the direct before/after pairs. The new direct comparison measures core's
remaining lead at **7.01x**.

Baseline source: `6f73bc0`. Optimized source: `b824f10`. Both use
Windows x64, EiffelStudio 25.02.9.8723 and MSVC 19.44.35229. Core remains pinned
at `6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676`. The original 504,561-byte PubMed
extract keeps its declaration, DOCTYPE and raw bytes. These numbers measure
whole-file parsing with a no-op handler. The new eligibility requires the
exact `XP_NULL_EVENT_HANDLER` type; native and custom handlers retain their
previous path, so this study establishes no throughput gain for those APIs.

## Why the DOCTYPE mattered

The baseline's `can_use_element_name_slices` required an empty `doctype_name`.
PubMed declares an external DTD, but this no-op benchmark does not load it and
has no retained attribute declarations. The gate still selected the general
start-tag path: copied names, an `XP_ATTRIBUTES` object with its table and
ordered names list, a default-declaration lookup, and another name copy for
the open-element stack.

The selected change reuses the existing range scanner and slice stack when
the DOCTYPE alone is the obstacle. An eight-document instrumented profile
shows the resulting changes in routine calls:

| Routine | Baseline calls | Candidate calls |
|---|---:|---:|
| `XP_ATTRIBUTES.make` | 56,896 | 40 |
| `XP_TOKEN_SLICE.make` | 0 | 56,856 |
| `XP_PARSER.parse_start_tag` | 56,856 | 56,856 |
| `XP_PARSER.parse_attribute` | 14,792 | 0 |
| `XP_PARSER.parse_attribute_no_events` | 0 | 14,792 |
| `XP_PARSER.open_element` | 56,856 | 0 |
| `XP_PARSER.open_element_range` | 0 | 56,856 |
| `XP_PARSER.apply_default_attributes` | 56,856 | 0 |
| `XP_PARSER.note_position` | 821,528 | 821,528 |

The class-specific constructor evidence maps profiler class IDs from the
actual generated `RTPR` declarations. Per document, the candidate avoids
7,107 `XP_ATTRIBUTES.make` calls while introducing
7,107 `XP_TOKEN_SLICE.make` calls. The slice path still
creates a token object for each opening; tags are not allocation-free.
Optimized generated C and COFF confirm the skipped materialization branch
and the remaining slice allocation.

These are measured routine counts, not a heap-object census. Containers can
allocate their own storage. Instrumentation also changes inlining and adds
individual `slice.item` and `same_range` measurements, so the candidate's
total instrumented time can look slower despite its wall-clock improvement.
Only the final uninstrumented pairs establish speed; they measure the
complete path change together.

## Eligibility, correctness and ownership

All existing observer, namespace, foreign-DTD, declaration-table and aligned
stack guards remain. The newly enabled DOCTYPE case additionally requires:

- The exact `XP_NULL_EVENT_HANDLER` dynamic type, excluding descendants.
- No external resolver and no active entity expansion.
- A configured attribute count no greater than the default cap of 1,024.

A nonempty attribute-declaration table still selects ordinary attribute
processing, preserving defaults, declared value normalization and ID metadata.
DTD parsing, standalone checks, resource limits, final/error positions and
root well-formedness remain on their existing paths. A DOCTYPE/root-name
difference remains accepted by this nonvalidating parser.

The callback restrictions preserve ownership behavior. A resolver, or a
descendant of the no-op handler overriding `on_comment`, can edit an already
consumed opening tag in aliased `STRING_8` input. Its original open name must
remain independent of that edit. Both cases therefore retain owned names.
Active entity replacement buffers also retain their existing path: raw CR in
attributes and malformed name-byte diagnostics already differ between the
general and range scanners, so expanding eligibility into those buffers
would change behavior. The larger attribute-limit exclusion preserves the
existing `XP_ATTRIBUTES` contract boundary.

An attribute reference still returns from the range scanner to the general
scanner, which reparses the complete attribute list. A materialized subtree
can sit above slice-backed ancestors; descendants resume slices only after
the general subtree closes. Matching and popping handle both representations,
including entity-floor checks and failure/recovery.

New slices refer to the normalized document already retained by
`position_input`. Balanced closes remove their active stack entries. Errors
leave open entries until the existing ordinary or cached-body reset, which
clears both active stacks. Clearing only the DTD cache does not unwind a
failed body's stacks. The change introduces no new cache or distinct retained
replacement buffer. This source/state audit does not establish object
reclamation or an allocator-level leak result; backing capacity and active
entries are separate matters.

## What still differs from core

The source audit identifies several concrete differences. It does not assign
unmeasured portions of the remaining core lead to them.

| Area | xpact | Pinned Xpact-core in this harness |
|---|---|---|
| Text scanning | Explicit character checks, close-marker handling and position checkpoints; eligible discarded text avoids materialization. | Scans retained `SPECIAL` bytes with a byte-classification table and passes text as intervals. The no-op content sink does not traverse those intervals again. |
| Names and storage | Uses slices under the eligibility above; other paths materialize names and attribute objects. | Interns repeated names within each document, retains parse/attribute capacities, and recycles overflow and value buffers. Reset clears logical name entries and entity tables; this is not a cross-document name or result cache. |
| Input preparation | Validates for a possible alias, then restarts normalization/copying if CR is found. This input's CR bytes are near EOF, at offsets 504,538 and 504,559. | Reuses a prepared UTF-8 codec for the harness's unchanged immutable input. Initial codec creation copies bytes to a C-managed buffer; every parse still copies and normalizes into retained parse-buffer capacity. |
| GC and adapter work | Uses normal GC; its adapter also clones `last_error`, including the empty success string. | Suspends collection during processing, enables it and performs a full collection in the final-input branch. The adapter restores incoming GC state, including rescue paths. |
| Positions | Commits required final/error positions and supports eager callback observations. | Calls a position hook whose inherited implementation is empty in the timed sink. The timing therefore does not include equivalent position-query work. |

Both measurements use native finalized Eiffel executables, a matching
`DC_BACKEND` adapter interface and the same file-capable root, one reused
parser, and the same immutable document per process. These runs contain no
C ABI or .NET transition. Core's
codec cache is valid for that immutable-input workload; mutating the same
document object would make its prepared bytes stale. Closing its adapter
clears the parser, codec and cached-document reference. Restoring GC policy
and reclaiming storage are separate operations.

Correctness coverage also differs. The previously recorded selected dual-W3C
profile gave xpact 1,727 passes, and pinned core 1,051 passes, 662 wrong
verdicts and 14 timeouts, with 858 exclusions for both. Core's wrong verdicts
included 339 false accepts and 323 false rejects; 312 false rejects concern
fifth-edition names. Those results do not quantify a speed contribution from
different checks. They do prevent treating agreement on this valid PubMed
file as unrestricted XML/API equivalence or removing required checks to
imitate core.

## Controlled screen and final throughput

The selected screen uses three alternating AB/BA pairs, one warmup per
executable and a common count calibrated until both samples reach 0.25
seconds. It measures the original PubMed file and a repeated-tag document
with a DOCTYPE. Ratios above one favor the candidate.

| Screen input | Median paired speed ratio | Pair range |
|---|---:|---:|
| PubMed extract | 1.1835 | 1.1685–1.1906 |
| Repeated tags with DOCTYPE | 1.8525 | 1.8337–1.8906 |

An earlier prototype compared `generating_type` with an attached manifest
type. Installed EiffelBase returns a detachable generating type, so that
comparison never activated the new path. Its source, executable and measured
pairs are retained separately as an inactive implementation. Those samples
are not pooled with the corrected screen or treated as noisy outliers.

Final comparisons use separate uninstrumented executables, two warmup runs
per executable, six sequential AB/BA pairs, and common-count calibration until
both samples take at least one second. Builds, tests and profiling finish
before timing. Whole-process time includes startup, file reading, setup,
reset/reuse and each implementation's actual GC policy. Every pair and outlier
is retained.

| Workload | Before MiB/s | After MiB/s | Median paired speed ratio | Pair range |
|---|---:|---:|---:|---:|
| Catalog | 17.788 | 17.925 | 1.0077 | 0.9890–1.0576 |
| Plain text | 51.821 | 51.351 | 0.9934 | 0.9573–1.5356 |
| 50 attributes per item | 27.739 | 27.207 | 0.9880 | 0.8567–1.1687 |
| PubMed extract | 17.056 | 20.486 | 1.1965 | 1.1577–1.3961 |
| Unicode stylesheet | 28.111 | 27.983 | 0.9985 | 0.9064–1.1228 |
| Legislation | 13.986 | 19.681 | 1.4012 | 1.1912–1.4142 |

Paired medians use each pair's elapsed-time ratio; they can differ from a
ratio of independently calculated median throughputs. Control workload gains
and regressions remain in the table. These results apply to these inputs and
host conditions.

The fresh direct core comparison uses **512 documents per
sample**, the same raw PubMed bytes and the protocol above. Ratios above one
favor core.

| Optimized xpact MiB/s | Core MiB/s | Core paired speed ratio | Pair range |
|---:|---:|---:|---:|
| 19.968 | 139.310 | 7.0101 | 6.9010–7.0766 |

The prior 8.99x lead and this result belong to separate campaigns. The stated
PubMed improvement comes from this campaign's before/after pairs, rather
than dividing two independently measured core gaps. Normalization, codec,
GC, scanning and position costs have not been isolated into additive shares
of the remaining lead.

## Validation and portable evidence

- All 66 Eiffel regression tests pass with assertions off/on in Workbench
  and Finalized builds: 264 test/configuration executions. The new tests also
  pass on the frozen baseline with assertions enabled in Workbench.
- All 1,727 applicable W3C and 40 directed cases pass for baseline and
  candidate in each finalized assertion configuration, with no verdict or
  diagnostic differences. The selected profile excludes 858 W3C cases.
- Focused sequences cover raw resolver CR/TAB/LF, CR generated in internal
  entity values, partial UTF-8 and malformed name diagnostics, attribute
  fallback/duplicates, mixed stacks, entity-floor failures, cached DTD replay,
  default limits, standalone behavior, and consumed-input mutation from
  resolver and comment callbacks. They repeat failure, recovery and failure.
- Production and assertion-enabled native DLL smoke suites pass; all six
  incremental audit cases pass. These are compatibility checks for paths
  excluded from the new eligibility, not native-throughput measurements.

The [portable evidence](../benchmarks/results/pubmed-doctype-2026-10-26.json)
contains the source comparison, routine profiles, selected and inactive
screens, every final pair, source/input/executable identities, generated-code
context, validation and reproduction sources. TSV companions retain all
measured rows. The preceding portable JSON report remains unchanged and is
referenced by its hash. Older Markdown reports keep their measurements with
follow-up pointers.

Complete local projects and logs are under `build/pubmed-doctype-20261026/`.
Use the retained executables and `scripts/compare_eiffel_benchmarks.py` with a
fresh output directory to reproduce the measurements. Keep instrumented
routine times separate from uninstrumented process throughput.
