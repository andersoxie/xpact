# Expat-Port Spike

This is the parallel experiment requested for incremental parsing. It is
isolated from production code and does not replace `XP_NATIVE_PARSER`.

The local source studied for this spike is:

```text
build\libexpat-R_2_8_1\libexpat-R_2_8_1\expat\lib\xmlparse.c
```

The upstream source is MIT-licensed; see:

```text
build\libexpat-R_2_8_1\libexpat-R_2_8_1\expat\COPYING
```

## What Was Ported

`XP_EXPAT_PORT_PARSE_SESSION` ports the high-level processor dispatch shape
from Expat, not the full tokenizer:

- a current processor slot, mirroring Expat's `m_processor`;
- a processor loop, mirroring `callProcessor`;
- explicit transitions through prolog-init, prolog, content, epilog, and error
  processors;
- final-buffer and suspended/finished/error parse status;
- bounded unconsumed input instead of whole-document replay.

The current spike handles the same small token subset as the first
`XP_INCREMENTAL_PARSE_SESSION` slice: start tags, quoted attributes,
empty-element tags, end tags, character data, XML-declaration-like prolog
consumption, and mismatched end-tag errors.

## Why Keep It Separate

This class exists to compare architecture and behavior against both:

- xpact's native accumulated-buffer shim;
- the independent incremental Eiffel session prototype.

It should remain separate until the CRC harness, shim audit, and native smoke
tests prove that a replacement session preserves the observable libexpat API
contract.

## Next Spike Work

The next useful additions are:

- model Expat token categories for comments, CDATA, entity references, and
  partial UTF-8 boundaries;
- add explicit `XML_StopParser` / resume semantics to the processor loop;
- drive the spike through a native-compatible wrapper so the CRC harness can
  compare xpact-current, the xpact session prototype, and the Expat-port spike.
