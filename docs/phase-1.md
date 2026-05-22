# xpact Phase 1

Phase 1 is the credible-release track described in the Eiffel.org article:

- xpact passes the libexpat test suite.
- Benchmark results are published honestly, including slower paths.
- Contract annotations are visible in the public repository.

This repository starts that track with a contracted parser core:

- `src/xp_parser.e` implements a streaming event parser with explicit preconditions, postconditions, class invariants, loop invariants, and loop variants.
- `src/xp_event_handler.e` defines the SAX-style callback surface used internally and by tests.
- `include/xpact.h` records the intended libexpat-compatible C ABI names.
- `tests/xpact_tests.ecf` runs the current contract-enabled regression tests.
- `benchmarks/xpact_benchmarks.ecf` gives a repeatable harness for publishing early results.

## Current Phase 1 Scope

Implemented now:

- Start tags, end tags, and empty-element tags.
- Attribute counting and duplicate-attribute rejection.
- XML 1.0 document structure checks: one root element, whitespace-only misc text outside the root, optional doctype before the root.
- XML 1.0 tokenization for comments, processing instructions, XML declaration position, doctype declarations, internal subsets, CDATA sections, character data, attributes, names, and line-end normalization.
- Predefined entities: `lt`, `gt`, `amp`, `apos`, and `quot`.
- Decimal and hexadecimal character references, emitted as UTF-8 bytes in the current `STRING_8` event surface.
- Internal general entity declarations and recursive expansion in content and attributes.
- Internal parameter entity declarations and parameter-entity expansion inside the internal subset.
- Entity-generated markup in element content.
- Recursive entity detection and entity expansion byte/depth limits.
- External general entity declarations are recognized and rejected on use until the project has a resolver callback and native ABI layer.
- Resource contracts for input size, element depth, attribute count, name length, and token length.

Still required before a credible public release:

- External entity resolver API and loader policy.
- Full libexpat public API compatibility.
- Adapter for the upstream libexpat test suite.
- Published benchmark table against libexpat on the same machine.
- Native DLL/SO export layer behind `include/xpact.h`.

## Local Commands

Compile and run the contract-enabled tests:

```powershell
ec -batch -config tests\xpact_tests.ecf -target xpact_tests
.\EIFGENs\xpact_tests\W_code\xpact_tests.exe
```

Compile and run the benchmark harness:

```powershell
ec -batch -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks
.\EIFGENs\xpact_benchmarks\W_code\xpact_benchmarks.exe
```
