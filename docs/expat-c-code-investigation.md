# Expat C-Code Investigation

This note records what is useful in the original Expat C implementation for
future xpact work. It is an architecture investigation, not a decision to move
XML semantics out of Eiffel.

Source studied:

- `build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/lib/xmlparse.c`
- `build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/lib/xmltok.c`
- `build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/lib/xmltok_impl.c`
- `build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/lib/xmltok_impl.h`
- `build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/lib/xmltok.h`
- `build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/lib/xmlrole.c`
- `build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/lib/xmlrole.h`

Expat is MIT-licensed. Any vendored or derived C helper must preserve the
required copyright and license notices.

## What Expat Separates Well

Expat's strongest design lesson is the separation between byte-level scanning,
document-state processing, and public ABI state.

`xmltok.*` owns byte classification, encoding-aware tokenization, partial-token
detection, character-reference parsing, public-id checks, XML declaration
parsing, and position updates. Its tokenizer API returns token ids plus a
pointer to the next byte. It explicitly distinguishes:

- no available input;
- partial token;
- partial multibyte character;
- invalid token;
- complete token with a next pointer.

`xmlrole.*` owns prolog and DTD role classification. It maps token streams into
roles such as XML declaration, doctype name, entity declaration, attribute-list
declaration, element declaration, comments, processing instructions, and the
start of document content.

`xmlparse.c` owns parser semantics. It has the processor loop, parser status,
callback dispatch, entity expansion, DTD state, namespace bindings, tag stack,
memory pools, accounting, error mapping, and external-entity child parser state.

That split is relevant for xpact because the byte scanner is the only part that
looks like a reasonable C helper. The parser semantics should remain in Eiffel.

## Useful C Patterns

Expat's parser object stores a retained C buffer with `m_buffer`, `m_bufferPtr`,
`m_bufferEnd`, and `m_bufferLim`. `XML_GetBuffer` preserves only the unconsumed
tail and optional input-context bytes before appending more input. xpact's
native adapter currently accumulates full input in `XP_NATIVE_PARSER.input_buffer`
and then reparses prefixes through `XP_PARSER`. Replacing that replay shape with
an unconsumed-tail session is the most important architectural improvement.

`callProcessor` calls the current processor repeatedly until parsing blocks,
suspends, errors, or consumes all available work. The active processor slot is
the right shape for xpact's true incremental parser: prolog init, prolog,
content, CDATA, external entity init/content, epilog, and error processors.
`XP_EXPAT_PORT_PARSE_SESSION` already models this direction, but only for a
small token subset.

Expat's non-final reparse deferral avoids rescanning the same partial token over
and over. It remembers how many bytes were available when no bytes were
consumed, then waits until enough new data arrives or buffer pressure makes a
retry useful. xpact has a start-tag-specific approximation in
`XP_NATIVE_PARSER.should_defer_reparse_callbacks`; the general version belongs
in the future incremental session, not as more special cases in the native
adapter.

Expat is also careful about lazy materialization. Open tag names can initially
point into the input buffer, and strings are copied only when they must survive
across parse calls or callback/API boundaries. xpact's Phase 2 token-slice plan
matches this idea: represent names, attribute values, namespace prefixes, and
text runs as buffer slices until a public API needs a `STRING_8`.

## Current xpact Fit

The C export layer is already on the right side of the boundary:

- `native/xpact_native.c` exports `XML_*` symbols and owns native ABI state.
- `native/xpact_eiffel_runtime_bridge.c` calls Eiffel feature pointers.
- `XP_NATIVE_PARSER` maps native parse calls to Eiffel parser behavior.
- `XP_PARSER` owns XML semantics.

The weak point is not the exported C bridge. The weak point is that
`XP_NATIVE_PARSER` still has to buffer and replay input into a whole-prefix
Eiffel parser. The isolated `XP_INCREMENTAL_PARSE_SESSION` and
`XP_EXPAT_PORT_PARSE_SESSION` prototypes are the correct direction.

## C Helper Options

There are two plausible hybrid paths.

Option A: keep the tokenizer in Eiffel, but add small C intrinsics for hot
operations such as prefix checks, delimiter scans, byte classification,
`memchr`-style searches, UTF-8 validation, and line/column updates. This keeps
the implementation easier to own but still removes expensive Eiffel string
operations from the hot path.

Option B: vendor a private, prefixed subset of Expat's `xmltok` and possibly
`xmlrole` layers. Eiffel would call a narrow xpact-owned C facade that returns
token descriptors, not parser callbacks. This gives closer Expat parity for
partial UTF-8, XML name rules, comments, CDATA, declarations, and literal
tokenization, but it adds vendoring, build, and license-maintenance cost.

If either path crosses Eiffel/C for every byte or every tiny token, the call
overhead may erase the benefit. Prefer either coarse helper operations or a
batch tokenizer API that fills a small array of token descriptors in one call.

## Recommended Boundary

C may do:

- byte-buffer ownership for native `XML_GetBuffer` style input;
- UTF-8 and UTF-16 byte scanning;
- token boundary detection;
- XML name and whitespace classification;
- character-reference numeric decoding;
- fast line, column, and byte-position updates;
- batch production of token descriptors.

C should not do:

- entity expansion;
- DTD declaration semantics;
- namespace binding semantics;
- external entity resolution or I/O;
- callback dispatch;
- Expat public parser state beyond ABI bookkeeping;
- user-visible error policy beyond raw tokenizer status.

This keeps the "XML parsing by contract" claim meaningful: Eiffel remains the
semantic owner, while C is a low-level scanner.

## Suggested Next Spike

Start with a private tokenizer facade instead of changing production parsing:

1. Add a small C file under `native/` with xpact-prefixed functions and no
   public `XML_*` symbols.
2. Support UTF-8 content tokenization first: start tag, empty element, end tag,
   data chars, entity ref, char ref, comment, CDATA open/close, processing
   instruction, partial token, partial character, and invalid token.
3. Return `(token_id, start_offset, end_offset, invalid_offset)` descriptors.
4. Expose a batch function that scans up to `N` tokens from a pointer and
   length.
5. Add Eiffel externals in a new prototype class, not in `XP_PARSER` directly.
6. Compare the C-token stream with `XP_PARSER` and the chunked CRC harness on a
   small corpus before wiring anything into `XP_NATIVE_PARSER`.

The first production integration should be the true incremental Eiffel session
replacing accumulated-buffer replay. A C tokenizer can be introduced behind
that session later if measurements show that Eiffel byte scanning is still the
dominant cost.

## Bottom Line

The original C code gives xpact three useful ideas:

- a retained unconsumed buffer instead of whole-prefix replay;
- a processor-loop parser state machine;
- a byte tokenizer that reports exact token and partial-token boundaries.

It does not argue for turning `native/xpact_native.c` into a parser or for
rewriting `XP_PARSER` in C. The best hybrid design is an Eiffel-owned
incremental parser core with an optional low-level C tokenizer facade that is
contract-checked against the existing `STRING_8` parser behavior.
