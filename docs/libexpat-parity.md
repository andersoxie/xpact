# libexpat Parity Status

Windows Phase 1 no longer uses a suite-wide expected failure for the upstream
libexpat adapter. The broad `*/*` row has been replaced by:

- `adapters/libexpat/expected-failures.tsv`: explicit red expected-failure
  patterns tied to upstream Expat 2.8.1 source files and `START_TEST(...)`
  names.
- `adapters/libexpat/parity.tsv`: green, red, and blocked parity rows for the
  Windows-only native release scope.

The adapter expands those rows against an upstream Expat 2.8.1 checkout:

```powershell
.\scripts\run_libexpat_adapter.ps1 `
  -ExpatSourceDir C:\src\libexpat `
  -Mode Manifest
```

The current upstream manifest has 399 `START_TEST(...)` entries. The explicit
expected-failure patterns expand to 293 named upstream tests in the downloaded
R_2_8_1 sources used for this checkpoint.

## Green Rows

The Windows release has green evidence for:

- loading the Eiffel-backed `xpact.dll` through the public `include/xpact.h`
  ABI;
- `XML_Parse` reaching the Eiffel parser;
- native C callbacks through the Windows MSVC DLL benchmark;
- basic entity, attribute, duplicate-attribute, empty-document, and
  `XML_GetBuffer` / `XML_ParseBuffer` coverage in the Eiffel/native bridge
  path.

## Red Rows

The red rows are specific remaining parity gaps, not a suite-wide failure:

- namespace parsing and namespace callback semantics;
- allocation-failure injection and allocation accounting tests;
- UTF-16 and custom/unknown encoding tests;
- external entity parser creation/loading through the Expat C callback model;
- DTD declaration, notation, default-handler, and content-model callbacks;
- stop/suspend/resume/abort parser state;
- exact byte, line, and column accounting;
- Expat hash/reparse-deferral/accounting semantics.

## Blocked Row

The upstream native C suite was not executed in this Windows verification
environment because `cmake` was not on `PATH`. The adapter still generates the
manifest, expected-failure expansion, and parity expansion. Running the native
suite is a toolchain verification step, while the Windows Phase 1 release scope
is now explicit about the green and red parity rows it claims.
