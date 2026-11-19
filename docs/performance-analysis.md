# Performance Analysis

For the current local compiler comparison, see the
[13 November 2026 WSL measurements](wsl-benchmarks.md). They compare Gobo
`26.11.12+ca6541c` with EiffelStudio 25.02 using the same parser and workload,
with separate assertion-off/on rows and a shared-ECF control. They measure
toolchain configurations, not a new parser optimization or a new Jenkins build.
The [assertion investigation](gobo-assertions.md) records the fixed Gobo checks
and GC controls and the remaining literal-`ensure False` inlining difference.
Assertion overhead must be read from that qualified campaign, not inferred
from the small June difference retained below.

The separate November parser and native-DLL speed work, including incremental
parsing, production builds without `-keep`, and inlining, is recorded in
[Speed work: session notes](notes/README.md). Those reports retain their own
source revisions, build settings and measurements.

The [PubMed DOCTYPE follow-up](pubmed-doctype-performance.md) compares the
October source revisions' core architecture differences and measures the bounded no-op
slice-path change. Earlier reports retain their original measurements.

The [PubMed text-position follow-up](pubmed-position-performance.md) records
its preceding profile, allocation-free position batching and that campaign's
direct core comparison. Older reports below retain their original provenance.

The [PubMed character-data follow-up](pubmed-character-data-performance.md)
profiles the remaining gap and removes repeated close-marker construction.
It records a further 62.3% PubMed throughput improvement and the fresh core
comparison. Earlier reports below preserve their own measurements.

The [2026-10-26 parser profiling and optimization report](parser-profile-performance.md)
records the completed position, duplicate-attribute and normalization work,
with fresh before/after measurements and a six-workload comparison to pinned
Xpact-core. The older measurements below retain their original context.

The [2026-10-25 tag-dispatch comparison](tag-dispatch-performance.md) measures
the marker-reuse refinement against fresh baseline builds on both MSVC and
WSL2 GCC, including text-heavy and real XML inputs. The tables below retain
the earlier measurements and their original context.

The remainder preserves the June 2026 analysis of the Windows Phase 1 benchmark
in [benchmarks.md](benchmarks.md). Its timings and ratios describe those source
and runtime configurations, not current cross-compiler rankings.

## June 2026 catalog baseline

The benchmark parses the same 2611-byte UTF-8 catalog document 1000 times and
reports process-level elapsed time. The generated 2026-06-19 publication table
reports the median of three process-level runs and includes the WSL2 direct
C libexpat rows. Focused 2026-06-19 finalized-build updates also measured the
direct Eiffel tokenizer path and selected native C ABI tokenizer rows against
the same workload with tighter repetitions. The June 19 focused direct row
includes slice-backed open element names, no-event attribute and character-data
scanning, lazy position accounting, normalized-input aliasing for the safe
no-callback `STRING_8` path, direct ASCII XML/name-character checks, and an
inlined `scan_name` loop. It is retained as the endpoint of that June focused
campaign; the October reports measure later parser changes separately.

| Path | Median elapsed ms | Relative note |
|---|---:|---|
| libexpat C tokenizer via WSL2 gcc | 100.230 | 2026-06-19 full publication direct C baseline |
| libexpat C callbacks via WSL2 gcc | 99.917 | 2026-06-19 full publication direct C callback baseline |
| libexpat via CPython `pyexpat` tokenizer | 115.293 | 2026-06-19 same-run Expat tokenizer baseline |
| libexpat via CPython `pyexpat` tokenizer, full publication | 136.860 | 2026-06-19 full publication Python binding baseline |
| xpact direct Eiffel tokenizer/no-op | 184.700 | 2026-06-19 focused row; about 1.60x slower than same-run `pyexpat` tokenizer and 1.84x slower than that June WSL2 direct C tokenizer |
| xpact direct Eiffel tokenizer/no-op, full publication | 193.800 | 2026-06-19 full publication row; about 1.93x slower than the WSL2 direct C tokenizer |
| xpact native C ABI tokenizer, parser reused | 779.704 | 2026-06-19 full publication row through the Windows Eiffel-backed native DLL |
| xpact native C ABI tokenizer, parser created per document | 805.676 | 2026-06-19 full publication row through the Windows Eiffel-backed native DLL |
| xpact direct Eiffel tokenizer/no-op, previous focused row | 247.600 | Slice/no-event fast paths plus normalized-input aliasing, before direct ASCII/name-scanner work |
| xpact direct Eiffel tokenizer/no-op, earlier focused row | 271.328 | Slice/no-event fast paths before normalized-input aliasing |
| xpact direct Eiffel tokenizer/no-op, GC suspended, previous focused row | 276.164 | GC suspension was neutral in this June configuration |
| libexpat via CPython `pyexpat` callbacks | 208.242 | 2026-06-19 full publication Python callback baseline row |
| xpact direct Eiffel tokenizer/no-op, assertions enabled | 199.462 | 2026-06-19 full publication assertion-enabled row |
| xpact native C ABI tokenizer, previous publication | 3474.593 | 2026-06-18 native bridge row before latest direct-core and no-callback native improvements |
| xpact native C ABI callbacks | 6475.666 | 2026-06-19 full publication native callback row |

Within this campaign, the direct Eiffel row excludes native bridge costs. The
C ABI rows include the exported C bridge, C/Eiffel runtime transitions, native
callback adapter work, and byte/string conversions.

The June direct Eiffel tokenizer/no-op path improved from the previous
controlled 774.653 ms measurement to 184.700 ms, about a 76.2% reduction. The
June direct ASCII/name-scanner work improved the previous focused direct row
of 247.600 ms by about 25.4%. Against the 2026-06-18 published direct row of
874.84 ms, the focused 2026-06-19 row is about 78.9% faster. In that campaign,
the direct core was no longer an order of magnitude behind on the catalog.
The measured direct gap was roughly 1.6x versus same-run `pyexpat` and about 1.84x
versus the June WSL2 direct C libexpat tokenizer row. In the full publication
table, where the direct Eiffel median is 193.800 ms, the gap is about 1.93x
versus WSL2 direct C libexpat and about 1.42x versus the same-table CPython
`pyexpat` tokenizer.

## What the June experiments tested

Temporary garbage-collection suspension did not explain that campaign's main gap. The
`parse_without_garbage_collection` row is close to the normal direct Eiffel row
in both the published and focused tables. In the 2026-06-19 full publication it
was 194.754 ms versus 193.800 ms without suspension, within ordinary
process-level variation. This does not establish the effect of another GC,
parser revision, or allocation workload.

Parser creation and free were also not the main native cost in those runs. Reusing the native
`XML_Parser` with `XML_ParserReset` produced nearly the same median as creating
one parser per document: 779.704 ms versus 805.676 ms. The remaining
native overhead is per-parse bridge, byte/string conversion, and payload work.

The 2026-06-19 full publication recorded 199.462 ms with assertions enabled
versus 193.800 ms with assertions discarded. That small historical difference
does not establish that assertions are cheap in the current parser or across
compilers. Later parser changes and the corrected Gobo assertion behavior
change the work performed; the [November comparison](wsl-benchmarks.md) reports
assertion-on/off costs separately. Assertion-enabled lanes also remain useful
for correctness checks, independent of their performance cost.

Position accounting used to be a major issue. Earlier versions recomputed line
and column numbers from the start of the input on many token transitions. That
was first replaced with incremental position tracking, and the June
no-callback tokenizer path deferred line/column accounting until an error or
final position query. This keeps Expat-style position results available while
removing most line/column work from successful no-op tokenization.

## June interpretation of the direct Eiffel gap

The June analysis identified Eiffel-level dispatch and validation in the hot
tokenization path as remaining work relative to libexpat's C byte scanner.
Several object-materialization costs in the catalog no-callback path had
already been removed: open element names are slice-backed, simple
attributes are parsed without building `XP_ATTRIBUTES`, duplicate-attribute
checks keep name ranges instead of token objects, successful no-callback
character data is scanned without creating text strings, line/column position
counters are lazy, ordinary ASCII XML characters bypass the expensive Unicode
validation path, and XML name scanning uses direct code comparisons instead of
per-character Eiffel library predicates. The June changes also avoid building a
normalized copy when the complete-document no-callback path receives a
`STRING_8` that has no UTF-8 BOM or CR line endings to normalize.

Those changes are deliberately guarded. If a handler wants start/end/text/default
events, if an attribute value needs entity expansion, or if character data sees
an entity reference, the parser falls back to the existing materialized path.
That preserves the eventful parser contract while making the tokenizer/no-op
case much closer to libexpat's "scan only" behavior.

The input is also scanned or copied more than once. The parser normalizes input,
keeps `position_input` for diagnostics, and then scans the normalized text. The
safe no-callback `STRING_8` path now aliases the validated input as the parser
and position buffer, but other entry points still keep owned normalized buffers.
That is safer and simpler than libexpat's buffer-oriented scanner, but it still
leaves work for native byte-buffer and eventful paths.

## June native C ABI comparison

The native tokenizer rows were rerun against the June direct Eiffel core
and are much better than the 2026-06-18 publication, but they are still slower
than direct Eiffel parsing. Bytes cross the C/Eiffel boundary and are converted
before the Eiffel parser sees them. The path includes C bytes to Eiffel
`STRING_8`, native parser input buffering, decoding or normalization,
position-input handling, and then normal parsing.

The native callback row is slower again because every event requires callback
payload materialization and a C callback transition. Start-element callbacks in
particular need C strings for the element name and for each attribute name/value
plus a null-terminated pointer vector.

Internal diagnostic event logging has already been disabled for the exported C
bridge. The no-callback native path now also avoids eager context-buffer copies
and eager position accounting when no installed callback can observe parser
positions. That helped the native tokenizer path substantially, but real C
callbacks still require payload materialization by design. The June focused
scanner campaign did not also republish a native callback measurement; its
tokenizer gain must not be applied to that path without a matching measurement.

## Article Performance Update

Finnian Reilly's 2026-05-30 article update proposed a Phase 2 performance
architecture. The initial `STRING_8` parser made XML behavior, contracts and
libexpat parity tractable first. Some of the proposed slice and allocation
changes subsequently landed; the proposal is not an unchanged current backlog.

The central idea is to stop treating every token as a newly materialized Eiffel
string. The article uses `C_STRING_8` as a proof-of-concept wrapper around
C-allocated memory, with operations such as prefix comparison delegated to
optimized C routines while Eiffel contracts check equivalence with `STRING_8`
during development. The published microbenchmarks in the article report a
large advantage for C-buffer prefix checks, a smaller but still meaningful
advantage for occurrence counting, and a roughly 20% advantage for a
CSV-style token extraction workflow.

For xpact, the architectural proposal was to operate on shared input
buffers and token slices. Guarded versions are already implemented, as the
June and October reports describe. Element names, attribute names, attribute values,
namespace prefixes, and text runs can be represented as `(base pointer, offset,
length)` views into the input, with `STRING_8` materialized only for public
Eiffel APIs, diagnostics, or native callback payloads that actually need an
owned string.

The article also calls out three related performance levers:

- string-pool recycling for repeated element names, attribute names, and
  namespace prefixes;
- garbage collection disabled across the parse window, which is implemented
  and must be measured with each parser/runtime configuration;
- optional SCOOP pipeline parallelism after the single-threaded parser is fast
  enough to justify parallel tokenizer/attribute/callback stages.

These proposals motivate buffer views, selective pooling and contract checks
against ordinary `STRING_8` behavior. They do not establish a measured benefit
for every workload or justify bypassing callback and ownership requirements.

## Completed optimizations and remaining measurement questions

The June slice-backed names, no-event attributes/text, safe input aliasing and
ASCII/name-scanner changes are implemented. Later measured work includes:

- [Tag-dispatch marker reuse](tag-dispatch-performance.md).
- [Backward-position updates, duplicate-attribute hashing and ASCII normalization](parser-profile-performance.md).
- [Character-data marker guards and reuse](pubmed-character-data-performance.md).
- [Batched text positions and UTF-8 tail guards](pubmed-position-performance.md).
- [Bounded no-op DOCTYPE slice eligibility](pubmed-doctype-performance.md).

These reports retain their own baselines and before/after pairs. Their gains
must not be multiplied together or combined with November's compiler ratios
to manufacture a new measurement. The latest listed PubMed study identifies
remaining differences in scanning, name storage, normalization, input
preparation, GC and position work without assigning additive speed shares.

For native chunked calls, the later [November checkpoint-resume implementation](incremental-resume.md)
continues eligible UTF-8 and UTF-16 input from saved parser state. It retains
the full input buffer and falls back to replay in the documented cases; the
earlier whole-file studies do not measure this change.

Broader buffer views, pooling for eventful/native paths and optional parallel
pipelines remain design questions here, not measured solutions. Any extension
needs its own ownership and mutation rules, failure/reset coverage, and a
comparison on the affected path. A no-op whole-file gain does not establish a
gain for callbacks, native ABI, .NET or streaming.

## Large XML Measurements

The microbenchmark is intentionally small and repeatable. The repository also
has an opt-in large XML macro-benchmark runner,
`scripts/run_large_xml_benchmarks.ps1`, documented in
`docs/large-xml-benchmarks.md`.

Those measurements should use real caller-supplied XML corpora, already
decompressed, with download and decompression excluded from parser throughput.
This harness is explicitly a whole-file benchmark using a complete
`READABLE_STRING_8`. It measures documents that fit in memory, not incremental
parsing or multi-gigabyte streaming behavior through other APIs.

The first published macro comparison, from 4 June 2026, uses a 512 KiB valid subset derived from
official PubMed update file `pubmed26n1380.xml.gz`: the original declaration,
DOCTYPE, root element, and the first 53 complete `PubmedArticle` records. On
that input, direct finalized Eiffel xpact takes 6724.675 ms, while the WSL2
direct C libexpat tokenizer row takes 107.954 ms and CPython `pyexpat`
tokenizer takes 91.006 ms. The macro result therefore shows a larger gap than
the small catalog benchmark: roughly 62x versus direct C libexpat tokenizer and
roughly 74x versus CPython `pyexpat` tokenizer. GC suspension was neutral in
that configuration. The October profiling and PubMed follow-ups above document
later changes on this input; those historical June ratios are not current parser
or Gobo performance claims.
