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
- A runtime trampoline in `native/xpact_eiffel_runtime_bridge.c` that adopts an
  Eiffel `XP_NATIVE_BRIDGE_INSTALLER` object, forwards bridge callbacks to
  Eiffel feature pointers, and registers the populated bridge table with
  `XPACT_SetEiffelBridge`.
- Native ABI/link smoke tests in `tests/native`, built by
  `scripts/run_native_abi_tests.ps1`, covering public C callers and bridge
  forwarding.
- Native C ABI benchmark wiring in `benchmarks/xpact_native_c_benchmark.c` and
  `scripts/run_benchmarks.ps1`; the Windows path links with
  `build/native-eiffel/xpact.lib` and runs against the Eiffel-backed
  `build/native-eiffel/xpact.dll`, while the older WSL bridge-only shared
  object path remains separate until Linux/WSL packaging exists.
- Eiffel-side bridge classes, `XP_NATIVE_PARSER`,
  `XP_NATIVE_CALLBACK_HANDLER`, `XP_NATIVE_BRIDGE_INSTALLER`, and
  `XP_NATIVE_BRIDGE_EXPORT`, that drive the Eiffel parser, adapt events to
  Expat-style callback slots, map native opaque handles to Eiffel parser
  objects, and install the runtime bridge from Eiffel.
- `tests/xpact_native_runtime.ecf` plus
  `scripts/run_native_runtime_smoke.ps1` build the C bridge objects and verify
  `XML_Parse` entering through the C ABI reaches the Eiffel parser.
- `tests/xpact_native_library.ecf`, `native/xpact_eiffel_dllmain.c`, and
  `scripts/build_native_eiffel.ps1` package that path as
  `build/native-eiffel/xpact.dll` on Windows, with
  `tests/native/xpact_eiffel_dll_smoke.c` verifying an external C caller can
  link against the DLL import library and parse through the Eiffel core.
- `scripts/package_windows_release.ps1` publishes the initial Windows x64
  native package with the Eiffel-backed DLL, MSVC import library, public header,
  release notes, and consumer smoke source.
- The upstream libexpat C-suite adapter can configure, build, and run through
  `scripts/run_libexpat_adapter.ps1 -Mode NativeSuite` with an explicit
  expected-failure list in `adapters/libexpat/expected-failures.tsv`.
- `adapters/libexpat/parity.tsv` records green, red, and blocked Windows Phase
  1 parity rows; the adapter expands those rows into
  `build/libexpat-adapter/libexpat-parity-expanded.tsv`.

## Implemented Behind The Surface

The Eiffel parser core currently implements the behavior needed by the simple
streaming path: parser reset semantics, start/end element callbacks, character
data, XML 1.0 tokenization, entity expansion, external-entity resolver policy,
and error reporting.

## Tracked Parity Gaps

- Exact byte, line, and column accounting for Expat-compatible position APIs.
- Namespace processing and namespace callback parity.
- UTF-16, custom encoding, external entity parser, DTD declaration, notation,
  default handler, stop/resume, allocation-failure, and upstream accounting
  parity.

Linux/WSL `libxpact.so` packaging is future platform work. It is not part of
the initial Windows-only native release.
