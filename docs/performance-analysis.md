# Performance Analysis

This note explains the current performance gap between xpact and libexpat based
on the Windows Phase 1 benchmark in `docs/benchmarks.md`.

## Current Baseline

The benchmark parses the same 2611-byte UTF-8 catalog document 1000 times and
reports process-level elapsed time. The generated 2026-06-18 publication table
reported the median of three runs. Focused 2026-06-19 finalized-build updates
then measured the direct Eiffel tokenizer path and selected native C ABI
tokenizer rows against the same workload. The latest focused direct row includes
slice-backed open element names, no-event attribute and character-data scanning,
lazy position accounting, normalized-input aliasing for the safe no-callback
`STRING_8` path, direct ASCII XML/name-character checks, and an inlined
`scan_name` loop. It is now the best current measurement of the Eiffel parser
core.

| Path | Median elapsed ms | Relative note |
|---|---:|---|
| libexpat via CPython `pyexpat` tokenizer | 115.293 | 2026-06-19 same-run Expat tokenizer baseline |
| xpact direct Eiffel tokenizer/no-op | 184.700 | 2026-06-19 latest focused row; about 1.60x slower than same-run `pyexpat` tokenizer |
| xpact native C ABI tokenizer, parser reused | 784.110 | 2026-06-19 focused row through the Windows Eiffel-backed native DLL |
| xpact native C ABI tokenizer, parser created per document | 787.427 | 2026-06-19 focused row through the Windows Eiffel-backed native DLL |
| xpact direct Eiffel tokenizer/no-op, previous focused row | 247.600 | Slice/no-event fast paths plus normalized-input aliasing, before direct ASCII/name-scanner work |
| xpact direct Eiffel tokenizer/no-op, earlier focused row | 271.328 | Slice/no-event fast paths before normalized-input aliasing |
| xpact direct Eiffel tokenizer/no-op, GC suspended, previous focused row | 276.164 | GC suspension remains neutral for this workload |
| libexpat via CPython `pyexpat` callbacks | 204.702 | 2026-06-18 Python callback baseline row |
| xpact direct Eiffel tokenizer/no-op, assertions enabled | 881.754 | 2026-06-18 pre-fast-path assertion-enabled row |
| xpact native C ABI tokenizer, previous publication | 3474.593 | 2026-06-18 native bridge row before latest direct-core and no-callback native improvements |
| xpact native C ABI callbacks | 6044.687 | 2026-06-18 native callback row |
| libexpat C tokenizer via WSL2 gcc | 100.937 | Historical 2026-06-03 direct C row; not measured in the current run |

The direct Eiffel row is the best measure of the Eiffel parser core. The native
C ABI rows include the exported C bridge, C/Eiffel runtime transitions, native
callback adapter work, and byte/string conversions.

The direct Eiffel tokenizer/no-op path has improved from the previous
controlled 774.653 ms measurement to 184.700 ms, about a 76.2% reduction. The
latest direct ASCII/name-scanner work improved the previous focused direct row
of 247.600 ms by about 25.4%. Against the 2026-06-18 published direct row of
874.84 ms, the focused 2026-06-19 row is about 78.9% faster. The direct core is
no longer an order-of-magnitude problem on this catalog microbenchmark; the
remaining direct gap is roughly 1.6x versus same-run `pyexpat`.

## What Has Already Been Ruled Out

Temporary garbage-collection suspension does not explain the main gap. The
`parse_without_garbage_collection` row is close to the normal direct Eiffel row
in both the published and focused tables. In the 2026-06-19 focused run it was
276.164 ms versus 271.328 ms without suspension, so the difference remains
normal process-level noise.

Parser creation and free are also not the main native cost. Reusing the native
`XML_Parser` with `XML_ParserReset` produced nearly the same focused median as
creating one parser per document: 784.110 ms versus 787.427 ms. The remaining
native overhead is per-parse bridge, byte/string conversion, and payload work.

The finalized assertion build is also not a material benchmark cost for this
workload in the 2026-06-18 pre-fast-path table: 881.754 ms with assertions
enabled versus 874.84 ms with assertions discarded. That supports keeping
assertion-enabled finalized lanes as a validation tool without treating them as
a separate performance architecture.

Position accounting used to be a major issue. Earlier versions recomputed line
and column numbers from the start of the input on many token transitions. That
was first replaced with incremental position tracking, and the latest
no-callback tokenizer path now defers line/column accounting until an error or
final position query. This keeps Expat-style position results available while
removing most line/column work from successful no-op tokenization.

## Direct Eiffel Gap

The direct Eiffel parser is still slower mainly because the hot tokenization path
does more Eiffel-level dispatch and validation than libexpat's tight C byte
scanner. The largest object-materialization costs in the catalog no-callback
path have now been removed: open element names are slice-backed, simple
attributes are parsed without building `XP_ATTRIBUTES`, duplicate-attribute
checks keep name ranges instead of token objects, successful no-callback
character data is scanned without creating text strings, line/column position
counters are lazy, ordinary ASCII XML characters bypass the expensive Unicode
validation path, and XML name scanning uses direct code comparisons instead of
per-character Eiffel library predicates. The latest steps also avoid building a
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

## Native C ABI Gap

The native tokenizer rows have been rerun against the faster direct Eiffel core
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
callbacks still require payload materialization by design. The callback row has
not yet been republished after the latest direct-core scanner improvements.

## Article Performance Update

Finnian Reilly's 2026-05-30 article update adds a more explicit Phase 2
performance architecture. The important distinction is that the current
`STRING_8` parser is still the right Phase 1 choice: it made XML behavior,
contracts, and libexpat parity tractable first. The article's performance
section defines what should come next.

The central idea is to stop treating every token as a newly materialized Eiffel
string. The article uses `C_STRING_8` as a proof-of-concept wrapper around
C-allocated memory, with operations such as prefix comparison delegated to
optimized C routines while Eiffel contracts check equivalence with `STRING_8`
during development. The published microbenchmarks in the article report a
large advantage for C-buffer prefix checks, a smaller but still meaningful
advantage for occurrence counting, and a roughly 20% advantage for a
CSV-style token extraction workflow.

For xpact, the bigger point is architectural rather than the exact
microbenchmark number: the parser should eventually operate on shared input
buffers and token slices. Element names, attribute names, attribute values,
namespace prefixes, and text runs can be represented as `(base pointer, offset,
length)` views into the input, with `STRING_8` materialized only for public
Eiffel APIs, diagnostics, or native callback payloads that actually need an
owned string.

The article also calls out three related performance levers:

- string-pool recycling for repeated element names, attribute names, and
  namespace prefixes;
- garbage collection disabled across the parse window, which we already expose
  experimentally but have not yet paired with a lower-allocation parser shape;
- optional SCOOP pipeline parallelism after the single-threaded parser is fast
  enough to justify parallel tokenizer/attribute/callback stages.

That means the main Phase 2 target is not just "make current strings faster".
It is to make the hot path buffer-backed, slice-oriented, pooled where useful,
and contract-checked against ordinary `STRING_8` behavior in debug/test builds.

## Most Useful Next Optimizations

The latest no-callback work completed the first slice/lazy-materialization slice
of the plan: element-stack names, simple attributes, successful character data,
line/column accounting, ordinary normalized input, ASCII character validation,
and XML name scanning now avoid most materialization and generic Eiffel
predicate dispatch in the direct tokenizer/no-op path. The remaining gap is
smaller and should be attacked with more measurement discipline, because some
changes that were previously obvious will now move less needle.

Recommended order:

1. Fold the focused 2026-06-19 rows into the full publication flow in
   `scripts/run_benchmarks.ps1`, including callback rows, so future comparisons
   use one repeatable command.
2. Add a native ABI byte-buffer parse entry that avoids an extra C-to-Eiffel copy
   when the input is already UTF-8, then keep callback payload materialization
   only at callback boundaries.
3. Move delimiter scans and prefix checks toward shared-buffer or slice-oriented
   operations, especially for markup recognition, comments, CDATA, processing
   instructions, and DTD scans.
4. Extend slice-backed no-event parsing beyond the simple catalog shape:
   namespace-safe names, selected DTD/default-attribute cases, and entity-free
   attribute values that currently force materialization.
5. Revisit string pooling for eventful parsing, where element names, attribute
   names, namespace prefixes, and repeated callback strings still need owned
   Eiffel or C-compatible storage.
6. Treat SCOOP pipeline parsing as a later optional mode, after the
   single-threaded buffer-backed path and native byte-buffer path are competitive
   and well measured.

These changes target the remaining structural differences from libexpat:
libexpat scans over a byte buffer and materializes little unless a callback or
API asks for it. xpact should keep the Eiffel design and contracts, but continue
moving work to lazy materialization at the boundary.

## Large XML Measurements

The microbenchmark is intentionally small and repeatable. The repository now
also has an opt-in large XML macro-benchmark runner,
`scripts/run_large_xml_benchmarks.ps1`, documented in
`docs/large-xml-benchmarks.md`.

Those measurements should use real caller-supplied XML corpora, already
decompressed, with download and decompression excluded from parser throughput.
The first slice is explicitly a whole-file benchmark because the current Eiffel
core consumes a complete `READABLE_STRING_8`. That makes it useful for
realistic medium and large documents that fit in memory, but not yet for
multi-gigabyte streaming claims.

The first published macro comparison uses a 512 KiB valid subset derived from
official PubMed update file `pubmed26n1380.xml.gz`: the original declaration,
DOCTYPE, root element, and the first 53 complete `PubmedArticle` records. On
that input, direct finalized Eiffel xpact takes 6724.675 ms, while the WSL2
direct C libexpat tokenizer row takes 107.954 ms and CPython `pyexpat`
tokenizer takes 91.006 ms. The macro result therefore shows a larger gap than
the small catalog benchmark: roughly 62x versus direct C libexpat tokenizer and
roughly 74x versus CPython `pyexpat` tokenizer. GC suspension remains neutral.
