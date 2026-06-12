# xpact

xpact is an Eiffel XML parser project inspired by Finnian Reilly's Eiffel.org
proposal, "Finding a billion-user project for Eiffel: How DbC catches the
security flaws that Rust misses."

Tagline: **XML parsing, by contract.**

The project goal is to use libexpat as the public reference point while keeping
the parser semantics owned by Eiffel. The C code in `native/` is an ABI bridge:
it exports libexpat-shaped symbols and delegates parsing to Eiffel classes. It
is not intended to become a second C parser.

## Current Status

This checkpoint is a Windows-only Phase 1 preview, not a final drop-in
replacement for libexpat.

Implemented and verified now:

- Eiffel targets explicitly compile with void safety enabled
  (`support="all" use="all"`), using the safe Base precompile.
- Contract-backed temporary garbage-collection suspension for critical parse
  sections.
- XML 1.0 tokenization and entity handling in Eiffel.
- Capability-based external entity resolver policy: xpact does not open files,
  URLs, or sockets by itself.
- A libexpat 2.8.1 public API header surface in `include/xpact.h`.
- A Windows x64 Eiffel-backed `xpact.dll` build path.
- A finalized assertion-enabled `xpact_assertions.dll` tier for contract-audited
  validation runs.
- C ABI smoke tests for public callers and for the private Eiffel bridge.
- A native C benchmark path against the Windows Eiffel-backed DLL.
- An upstream libexpat test-suite adapter with explicit green/red parity rows.
- Published benchmark, performance-analysis, and parity documentation.
- An opt-in large XML benchmark runner for caller-supplied, pre-decompressed
  real corpora.

The upstream Expat 2.8.1 manifest currently has 399 `START_TEST(...)` entries.
The expected-failure list expands to 86 rows:

- 86 allocator-injection tests are intentionally out of the current Eiffel
  release scope because they exercise libexpat's manual C allocation hook
  contract.

## What Is Left

Before calling xpact a credible drop-in replacement, the project still needs:

- a stronger native-suite gate that reports actual unexpected failures by
  upstream test name, not only the current expected-failure manifest expansion;
- Phase 2 performance work: buffer-backed token slices, lazy materialization,
  string-pool recycling, and a native byte-buffer parse path;
- replacement testing in at least one public application that normally builds
  against libexpat;
- Linux/WSL packaging for an Eiffel-backed `libxpact.so`;
- broader consumer ABI coverage across compilers and build systems;
- a release decision on whether allocator-injection semantics are intentionally
  unsupported or emulated at the C ABI boundary.

## Reading Order

Start here, then read:

1. `docs/article-reading-guide.md` for how the repository maps to the original
   Eiffel.org article and the Design by Contract argument.
2. `docs/phase-1.md` for the full Windows Phase 1 scope.
3. `docs/test-matrix.md` for assertion-on/assertion-off test lanes.
4. `docs/platform-builds.md` for Windows, Linux, and Eiffel .NET build
   preparation.
5. `docs/design-overview.md` and `docs/bon/` for the design map and BON views.
6. `docs/libexpat-api-compatibility.md` for the public C API surface.
7. `docs/libexpat-parity.md` and `adapters/libexpat/parity.tsv` for green/red
   upstream test-suite status.
8. `docs/benchmarks.md` for same-machine benchmark results.
9. `docs/large-xml-benchmarks.md` for opt-in real-corpus macro-benchmarking.
10. `docs/performance-analysis.md` for the current xpact-vs-libexpat performance
   gap analysis and next optimization priorities.
11. `docs/drop-in-verification.md` for the Jenkins and public-application
   replacement plan.

## Build And Verify

Compile and run the Eiffel regression matrix, both with and without Eiffel
runtime assertions:

```powershell
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All
```

Build the Windows Eiffel-backed native DLL:

```powershell
.\scripts\build_native_eiffel.ps1
```

Build the optimized assertion tier:

```powershell
.\scripts\build_native_eiffel.ps1 -BuildTier Assertions
```

Run native ABI/link smoke tests:

```powershell
.\scripts\run_native_abi_tests.ps1 -Target Windows
```

Refresh the upstream Expat manifest and parity expansion:

```powershell
.\scripts\run_libexpat_adapter.ps1 `
  -Mode Manifest `
  -ExpatSourceDir .\build\libexpat-R_2_8_1\libexpat-R_2_8_1\expat `
  -OutputDir .\build\libexpat-adapter-current `
  -XpactLibrary .\build\native-eiffel\xpact.lib `
  -SkipNativeBuild
```

Package the Windows x64 preview release:

```powershell
.\scripts\package_windows_release.ps1
```

Run opt-in large XML benchmarks with pre-decompressed real XML files:

```powershell
.\scripts\run_large_xml_benchmarks.ps1 -XmlFile C:\data\pubmed\pubmed25n0001.xml
```
