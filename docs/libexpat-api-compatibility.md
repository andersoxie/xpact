# libexpat API Compatibility

xpact tracks the libexpat 2.8.1 public API surface. The source of truth for
this checkpoint is `include/xpact.h`, with `src/xp_expat_api.e` keeping a
contract-tested manifest of the public names.

## Covered Now

- Expat 2.8.1 version macros: `XML_MAJOR_VERSION`, `XML_MINOR_VERSION`, and
  `XML_MICRO_VERSION`.
- Public scalar types, opaque parser type, status/error enums, content-model
  structs, parsing-status structs, memory-suite structs, feature structs, and
  handler typedefs.
- Public parser creation, parsing, handler-setting, error-reporting,
  position-reporting, memory, feature, attack-protection, hash-salt, and
  reparse-deferral declarations.
- Macro compatibility for `XML_GetUserData`, `XML_GetErrorLineNumber`,
  `XML_GetErrorColumnNumber`, and `XML_GetErrorByteIndex`.
- A native export layer in `native/xpact_native.c`, built with
  `scripts/build_native.ps1`, that exports the public C names and delegates
  parser behavior through a private Eiffel bridge. It intentionally does not
  tokenize, expand entities, or validate XML in C.

## Implemented Behind The Surface

The Eiffel parser core currently implements the behavior needed by the simple
streaming path: parser reset semantics, start/end element callbacks, character
data, XML 1.0 tokenization, entity expansion, external-entity resolver policy,
and error reporting.

## Still Required

- ABI tests that compile and link C callers against xpact.
- Eiffel bridge wiring behind the native export layer.
- Green behavioral parity runs through `adapters/libexpat` for each public
  handler and option.
- Exact byte, line, and column accounting for Expat-compatible position APIs.
