# Performance Analysis

This note explains the current performance gap between xpact and libexpat based
on the Windows Phase 1 benchmark in `docs/benchmarks.md`.

## Current Baseline

The benchmark parses the same 2611-byte UTF-8 catalog document 1000 times and
reports the median of three process-level runs. The current 2026-06-18 run did
not include WSL2 C rows because WSL `gcc` was not visible to the benchmark
process. The previous published 2026-06-03 WSL2 C rows are kept as historical
comparison values in `docs/benchmarks.md`.

| Path | Median elapsed ms | Relative note |
|---|---:|---|
| libexpat via CPython `pyexpat` tokenizer | 138.316 | Current available Expat baseline row |
| libexpat via CPython `pyexpat` callbacks | 204.702 | Current Python callback baseline row |
| xpact direct Eiffel tokenizer/no-op | 874.84 | About 6.3x slower than current `pyexpat` tokenizer |
| xpact direct Eiffel tokenizer/no-op, assertions enabled | 881.754 | Assertion-enabled finalized build is effectively the same speed for this workload |
| xpact native C ABI tokenizer | 3474.593 | About 4.0x slower than direct Eiffel |
| xpact native C ABI callbacks | 6044.687 | About 6.9x slower than direct Eiffel |
| libexpat C tokenizer via WSL2 gcc | 100.937 | Historical 2026-06-03 direct C row; not measured in the current run |

The direct Eiffel row is the best measure of the Eiffel parser core. The native
C ABI rows include the exported C bridge, C/Eiffel runtime transitions, native
callback adapter work, and byte/string conversions.

## What Has Already Been Ruled Out

Temporary garbage-collection suspension does not explain the main gap. The
`parse_without_garbage_collection` row is close to the normal direct Eiffel row
in the latest table, and the difference moves within normal process-level
noise.

Parser creation and free are also not the main native cost. Reusing the native
`XML_Parser` with `XML_ParserReset` produced nearly the same median as creating
one parser per document. The remaining native overhead is per-parse bridge and
payload work.

The finalized assertion build is also not a material benchmark cost for this
workload: 881.754 ms with assertions enabled versus 874.84 ms with assertions
discarded. That supports keeping assertion-enabled finalized lanes as a
validation tool without treating them as a separate performance architecture.

Position accounting used to be a major issue. Earlier versions recomputed line
and column numbers from the start of the input on many token transitions. That
has been replaced with incremental position tracking, which removed the largest
single hot-spot found so far.

## Direct Eiffel Gap

The direct Eiffel parser is still slower mainly because the hot tokenization path
materializes many Eiffel objects that libexpat avoids.

The start-tag path in `src/xp_parser.e` still creates an `XP_ATTRIBUTES` object
for each start tag, a `STRING_8` for the element name, attribute name/value
strings, hash-table entries, insertion-order list entries, and an element-stack
string copy. For the catalog benchmark this means roughly 101 start tags and 100
attributes per document, or about 100,000 attribute/name operations across 1000
documents.

`XP_ATTRIBUTES` is correct and convenient, but it is expensive for the common
case of zero, one, or a few attributes. It uses a `HASH_TABLE` plus an
insertion-order list. A small linear duplicate-check structure would be cheaper
for the simple benchmark shape and many ordinary XML documents.

The input is also scanned or copied more than once. The parser normalizes input,
keeps `position_input` for diagnostics, and then scans the normalized text. This
is safer and simpler than libexpat's buffer-oriented scanner, but it costs time
and memory bandwidth.

## Native C ABI Gap

The native tokenizer row is slower than direct Eiffel because bytes cross the
C/Eiffel boundary and are converted before the Eiffel parser sees them. The path
includes C bytes to Eiffel `STRING_8`, native parser input buffering, decoding or
normalization, position-input copying, and then normal parsing.

The native callback row is slower again because every event requires callback
payload materialization and a C callback transition. Start-element callbacks in
particular need C strings for the element name and for each attribute name/value
plus a null-terminated pointer vector.

Internal diagnostic event logging has already been disabled for the exported C
bridge. That helped the no-callback native tokenizer path substantially, but real
C callbacks still require payload materialization by design.

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

The article changes the optimization priority. Local improvements to
`XP_ATTRIBUTES` and no-callback paths still matter, but they should fit into a
larger zero-copy buffer plan.

Recommended order:

1. Introduce a small contract-checked token-slice abstraction over a shared
   byte buffer. Its debug/test contracts should prove equivalence with
   `STRING_8` for prefix checks, equality, substring extraction, and conversion.
2. Move tokenizer prefix checks and delimiter scans onto that buffer-backed
   representation, using optimized byte operations where the Eiffel/C boundary
   already exists.
3. Store element-stack entries, names, and namespace prefixes as compact slices
   or pooled strings, materializing `STRING_8` only for event/API boundaries.
4. Replace `XP_ATTRIBUTES` in the simple path with a slice-backed structure and
   lightweight duplicate checks for small attribute counts.
5. Keep no-event/no-callback parsing lazy: avoid start-element payload objects,
   attribute vectors, and character-data strings unless a handler or public API
   asks for them.
6. Avoid `position_input` copying in success-only tokenizer paths, or make it
   lazy so detailed line/column data is fully available on error but not paid
   for on every successful parse.
7. For the native ABI tokenizer path, add a byte-buffer parse entry that avoids
   an extra C-to-Eiffel-to-buffer copy when the input is already UTF-8.
8. Treat SCOOP pipeline parsing as a later optional mode, after the
   single-threaded buffer-backed path is competitive and well measured.

These changes target the remaining structural differences from libexpat:
libexpat scans over a byte buffer and materializes little unless a callback or
API asks for it. xpact should keep the Eiffel design and contracts, but move more
work to lazy materialization at the boundary.

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
