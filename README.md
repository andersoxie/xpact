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

**Version 0.9.0** (launch candidate). What each version contains: [CHANGELOG.md](CHANGELOG.md).

The native Phase 1 preview package targets Windows x64. The same Eiffel parser
also builds and runs in Ubuntu 24.04/WSL2 benchmarks with EiffelStudio and Gobo.
Full libexpat drop-in compatibility and an Eiffel-backed Linux shared-library
release remain work in progress.

Implemented and verified now:

- Eiffel targets explicitly compile with void safety enabled
  (`support="all" use="all"`). The safe Base precompile is used by Windows
  EiffelStudio targets; Linux benchmarks compile Base from source.
- Contract-backed temporary garbage-collection suspension for critical parse
  sections.
- XML 1.0 tokenization and entity handling in Eiffel.
- A no-event parsing fast path with slice-backed element names, deferred
  materialization, and lazy position accounting.
- Capability-based external entity resolver policy: xpact does not open files,
  URLs, or sockets by itself.
- A libexpat 2.8.1 public API header surface in `include/xpact.h`.
- A Windows x64 Eiffel-backed `xpact.dll` build path.
- A finalized assertion-enabled `xpact_assertions.dll` tier for contract-audited
  validation runs.
- C ABI smoke tests for public callers and for the private Eiffel bridge.
- A native C benchmark path against the Windows Eiffel-backed DLL.
- A chunked `XML_Parse` CRC harness that compares event digests across buffer
  sizes and can be compiled against xpact or libexpat.
- Native checkpoint resume for eligible UTF-8 and UTF-16 chunked input, with
  documented replay fallbacks and full-input retention.
- An upstream libexpat test-suite adapter with explicit green/red parity rows.
- A native-suite gate that resolves reported failures to upstream test names
  and rejects unexpected failures, crashes, and incomplete test runs.
- Published benchmark, performance-analysis, and parity documentation.
- W3C XML binary conformance tests in the benchmark lane, with per-case
  reports for both finalized assertion modes and Jenkins publication.
- An opt-in large XML benchmark runner for caller-supplied, pre-decompressed
  real corpora.
- Safe use from several threads, each with its own parsers: calls take turns
  inside the single-threaded Eiffel runtime, so they do not run in parallel (#274).
- An internal Eiffel exception (for example out of memory) makes the call fail
  with an error code instead of ending the process (#273).

The upstream Expat 2.8.1 manifest currently has 399 `START_TEST(...)` entries.
The expected-failure list expands to 86 rows:

- 86 allocator-injection tests are intentionally out of the current Eiffel
  release scope because they exercise libexpat's manual C allocation hook
  contract.

### Compiler Verification And Benchmarks — 13 November 2026

The configured Jenkins WSL environment now selects Gobo nightly
**26.11.12+ca6541c**, alongside EiffelStudio **25.02.9.8723**. After the update,
the Jenkins benchmark launcher was run locally with the same environment files
and workload; these measurements are not from a new Jenkins job build.

Both compilers parsed the same 2,611-byte, 100-item catalog with a reused parser
and no-op event handler. Each value below is the median of five runs of
**10,000 documents**, after one full warmup, using finalized builds and normal GC.

| Requested assertions | EiffelStudio | Gobo | Gobo throughput relative to EiffelStudio |
|---|---:|---:|---:|
| Off | 1.552 s | 0.915 s | **1.70×** |
| On | 15.400 s | 4.025 s | **3.83×** |

This compares complete toolchains: Gobo uses GCC `-O2` and Boehm GC;
EiffelStudio uses GCC `-O3` and its own collector. The installed Base-library
snapshots also differ. A separate Gobo run using the unchanged EiffelStudio ECF
gave similar results: **0.941 s off** and **4.015 s on**.

The new Gobo passes the previously failing `check`, loop-variant, and
supplier-precondition probes. Imported-library assertion scope and repeated
GC on/off transitions also pass on Linux and Windows. This is bounded
qualification: a separate Linux test still finds that an empty routine's literal
`ensure False` is skipped by finalized Gobo with assertions off, while
EiffelStudio raises an exception.

See [the WSL comparison and setup](docs/wsl-benchmarks.md),
[assertion qualification and remaining differences](docs/gobo-assertions.md),
and [raw measurements](benchmarks/results/gobo-eiffelstudio-comparison-2026-11-13.tsv).

## What Is Left

Before calling xpact a credible drop-in replacement, the project still needs:

- broader incremental coverage and bounded input retention: the native adapter
  now continues from checkpoints for eligible input, while replay fallbacks and
  complete input buffers remain; see [incremental resume](docs/incremental-resume.md);
- tighter expected-failure accounting that detects individual unexpected
  passes even when other expected failures remain in the same native-suite run;
- further performance work: extending the existing slice and deferred-materialization
  paths, string-pool recycling, and a native byte-buffer parse path;
- replacement testing in at least one public application that normally builds
  against libexpat;
- Linux/WSL packaging for an Eiffel-backed `libxpact.so`;
- broader consumer ABI coverage across compilers and build systems;
- a release decision on whether allocator-injection semantics are intentionally
  unsupported or emulated at the C ABI boundary;
- parallel parsing on several threads: needs a multi-threaded Eiffel runtime
  build (today calls are serialized, #274).

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
8. `docs/chunked-parse-crc.md` for incremental parsing verification through
   CRC-32 event digests across chunk sizes.
9. `docs/incremental-shim-audit.md` for native callback/position checks and
   [incremental resume](docs/incremental-resume.md) for checkpoint coverage and fallbacks.
10. `docs/incremental-core-prototype.md` for the isolated Eiffel session
    prototype that starts replacing replay with state-owned parsing.
11. `docs/expat-port-spike.md` for the isolated Expat-processor-style Eiffel
    port experiment.
12. `docs/expat-c-code-investigation.md` for what the original Expat C source
    suggests about incremental parsing and optional low-level C helpers.
13. [WSL2 Eiffel/GCC benchmarks](docs/wsl-benchmarks.md) for the current
    Gobo/EiffelStudio comparison, setup, and Jenkins compiler selection.
14. [Gobo assertion investigation](docs/gobo-assertions.md) for verified fixes,
    remaining compatibility differences, and the original slowdown analysis.
15. `docs/benchmarks.md` for the Windows benchmark series.
16. `docs/large-xml-benchmarks.md` for opt-in real-corpus macro-benchmarking.
17. `docs/performance-analysis.md` for optimization history and links to
    workload-specific profiles; its older baseline measurements retain their dates.
18. `docs/drop-in-verification.md` for the Jenkins and public-application
   replacement plan.
19. [Jenkins email notifications](docs/jenkins-email-notifications.md) for
   setting recipients for failed and unstable builds.
20. [Speed work: session notes](docs/notes/README.md) for the 2026-11 speed
   fixes, their issues and PRs, the merge order, and how to repeat the checks.

## Build And Verify

For independent builds of our parser and a pinned Finnian Xpact-core revision,
see [Pinned implementation builds](docs/implementation-builds.md). This first
integration step provides isolated build probes and provenance; shared test
and benchmark execution follows separately.

The first complete comparison path is [the focused dual catalog lane](docs/dual-catalog-lane.md):
`scripts/run_dual_catalog.ps1` qualifies both implementations, then measures only
the finalized, assertion-discarded 100-item catalog configuration.

The [dual W3C lane](docs/dual-w3c-lane.md), `scripts/run_dual_w3c.ps1`, runs the
same applicable conformance cases with both implementations in that configuration
and reports their acceptance/rejection results side by side.

Both lanes are included in the main [Jenkins execution and plots](docs/dual-implementation-jenkins.md)
when `RUN_BENCHMARKS` is enabled.

The [All Benchmark Plots report](docs/jenkins-plots.md) brings the dual-parser,
Windows, WSL, and optional large XML plots together on one page, with detailed
measurement explanations and links to their source evidence.

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

Run chunked `XML_Parse` CRC diagnostics:

```powershell
.\scripts\run_chunked_crc_corpus.ps1 -Target Xpact -ParseMode All
```

Audit the native chunk adapter's callback and position behavior:

```powershell
.\scripts\run_incremental_shim_audit.ps1 -SkipBuild
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

Run benchmarks including the W3C XML conformance suite:

```powershell
.\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions
```

The suite runs by default in both Jenkins benchmark pipelines. See
[W3C conformance benchmarks](docs/w3c-xml-conformance.md) for the supported
profile, offline setup, and detailed reports.

> **Testing a DLL you already built (#302):** by default `run_benchmarks.ps1`
> rebuilds `build\native-eiffel\*.dll` and rewrites `docs\benchmarks.md`. To test
> the exact DLL you built and checked, and keep the docs, add
> `-UseExistingNativeDll -NoDocsUpdate` (the page then goes to
> `build\benchmarks\benchmarks.md`). These scripts also rebuild the DLL unless told
> not to: `run_large_xml_benchmarks.ps1`, `run_chunked_crc_harness.ps1`,
> `run_incremental_shim_audit.ps1`, `package_windows_release.ps1` (`-SkipBuild`)
> and `run_libexpat_adapter.ps1` (`-SkipNativeBuild`); so do
> `website\scripts\build-dll.ps1` and `student\baseline\run_baseline.ps1` (on
> purpose). `run_large_xml_benchmarks.ps1` also rewrites
> `docs\large-xml-benchmarks.md` unless `-NoPublishDocs`. Check the DLL's SHA-256
> before and after a run.
>
> **Freeze the tested DLL (#319):** `build_native_eiffel.ps1` prints the DLL it
> replaces with its SHA-256 before and after. Set `$env:XPACT_FROZEN_DLL = "1"`
> before a test run and any runner that tries to rebuild stops at once with an
> error instead of replacing the DLL (child scripts inherit the variable).
>
> **Python (#308):** `run_benchmarks.ps1` and `run_large_xml_benchmarks.ps1` use
> `$env:XPACT_PYTHON` if set, otherwise `python` from PATH. They stop at once if
> that is the Microsoft Store alias (`...\WindowsApps\python.exe`).

Run the additional Eiffel/GCC comparison inside WSL2 after configuring the Linux
compiler environments (`ISE_EIFFEL`, `ISE_PLATFORM`, `GOBO`, and compiler paths):

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu-24.04
```

If the compiler setup is kept in Bash files instead of the Linux login
environment, pass their Linux paths through `-EiffelEnvironment` and
`-GoboEnvironment`. Jenkins's configured paths are documented in the
[WSL setup guide](docs/wsl-benchmarks.md#jenkins).

Both compilers use the same xpact parser and workload, with assertions requested
or discarded, alongside the libexpat C baseline. Pass `-EiffelCompiler Gobo`
or `-EiffelCompiler EiffelStudio` to select just one compiler.
See [WSL2 Eiffel/GCC benchmarks](docs/wsl-benchmarks.md) for setup, timing
methodology, and the Jenkins lane.

Run opt-in large XML benchmarks with pre-decompressed real XML files:

```powershell
.\scripts\run_large_xml_benchmarks.ps1 -XmlFile C:\data\pubmed\pubmed25n0001.xml
```
