# Performance Analysis

This note explains the current performance gap between xpact and libexpat based
on the Windows Phase 1 benchmark in `docs/benchmarks.md`.

## Current Baseline

The benchmark parses the same 2611-byte UTF-8 catalog document 1000 times and
reports the median of three process-level runs.

| Path | Median elapsed ms | Relative note |
|---|---:|---|
| libexpat via CPython `pyexpat` tokenizer | 107.682 | Baseline tokenizer row |
| xpact direct Eiffel tokenizer/no-op | 916.026 | About 8.5x slower than libexpat tokenizer |
| xpact native C ABI tokenizer | 3382.100 | About 3.7x slower than direct Eiffel |
| xpact native C ABI callbacks | 6188.694 | About 6.8x slower than direct Eiffel |

The direct Eiffel row is the best measure of the Eiffel parser core. The native
C ABI rows include the exported C bridge, C/Eiffel runtime transitions, native
callback adapter work, and byte/string conversions.

## What Has Already Been Ruled Out

Temporary garbage-collection suspension does not explain the main gap. The
`parse_without_garbage_collection` row is close to the normal direct Eiffel row,
and the difference moves within normal process-level noise.

Parser creation and free are also not the main native cost. Reusing the native
`XML_Parser` with `XML_ParserReset` produced nearly the same median as creating
one parser per document. The remaining native overhead is per-parse bridge and
payload work.

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

## Most Useful Next Optimizations

The next high-value optimization is a no-DTD/no-namespace/no-event start-tag fast
path. It should preserve the full parser behavior but avoid public event payload
objects unless they are needed.

Recommended order:

1. Replace `XP_ATTRIBUTES` in the simple no-event path with a lightweight
   duplicate-check structure for small attribute counts.
2. Store element stack entries as compact internal tokens or pooled strings, and
   materialize `STRING_8` only for event/API boundaries.
3. Parse start-tag names and attribute names as ranges into the input buffer
   where possible.
4. Avoid `position_input` copying in success-only tokenizer paths, or make it
   lazy so detailed line/column data is fully available on error but not paid
   for on every successful parse.
5. For the native ABI tokenizer path, add a byte-buffer parse entry that avoids
   an extra C-to-Eiffel-to-buffer copy when the input is already UTF-8.

These changes target the remaining structural differences from libexpat:
libexpat scans over a byte buffer and materializes little unless a callback or
API asks for it. xpact should keep the Eiffel design and contracts, but move more
work to lazy materialization at the boundary.

