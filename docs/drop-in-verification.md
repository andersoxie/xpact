# Drop-In Replacement Verification

This document defines how to verify xpact as a libexpat replacement. It is
honest about the current state: xpact is not yet a 100% drop-in replacement,
but the pipeline below makes that claim measurable.

## Compatibility Levels

Use these levels when discussing status:

- L0, header surface:
  C code can include `include/xpact.h` and compile against the expected public
  names.
- L1, ABI smoke:
  C callers can link against `xpact.lib`/`xpact.dll` and execute basic parser
  calls.
- L2, upstream libexpat suite:
  Upstream Expat `runtests` builds against xpact and only known expected
  failures remain.
- L3, public application replacement:
  A real public application that normally builds against libexpat can be built
  and tested against xpact instead.
- L4, release claim:
  L2 has zero unexplained red rows, L3 passes for at least one serious public
  application, benchmarks are published, and ABI packaging is repeatable.

The current Windows preview is between L2 and L3:

- L0 and L1 are covered on Windows.
- L2 is covered with an explicit expected-failure list.
- L3 is not automated yet.
- L4 is not claimed.

## Current Windows Verification Commands

Run from the repository root.

Eiffel regression matrix, both with and without runtime assertions:

```powershell
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All
```

Windows Eiffel-backed DLL:

```powershell
.\scripts\build_native_eiffel.ps1
```

Optimized assertion DLL for contract-audited validation runs:

```powershell
.\scripts\build_native_eiffel.ps1 -BuildTier Assertions
```

Native ABI/link smoke:

```powershell
.\scripts\run_native_abi_tests.ps1 -Target Windows
```

Chunked `XML_Parse` CRC diagnostics:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target Xpact `
  -ParseMode All `
  -AllowMismatches
```

Strict mode should be enabled once the incremental parser/session core is in
place. The current native chunk adapter still uses accumulated-buffer replay,
and the first harness run found a silent semantic mismatch for the generated
catalog document at chunk size 31.

Upstream Expat manifest and parity expansion:

```powershell
.\scripts\run_libexpat_adapter.ps1 `
  -Mode Manifest `
  -ExpatSourceDir .\build\libexpat-R_2_8_1\libexpat-R_2_8_1\expat `
  -OutputDir .\build\libexpat-adapter-current `
  -XpactLibrary .\build\native-eiffel\xpact.lib `
  -SkipNativeBuild
```

Upstream Expat native suite with expected-failure gating:

```powershell
.\scripts\run_libexpat_adapter.ps1 `
  -Mode NativeSuite `
  -ExpatSourceDir .\build\libexpat-R_2_8_1\libexpat-R_2_8_1\expat `
  -OutputDir .\build\libexpat-adapter-current `
  -XpactLibrary .\build\native-eiffel\xpact.lib `
  -SkipNativeBuild
```

Windows package:

```powershell
.\scripts\package_windows_release.ps1
```

Benchmark publication is useful but should normally run nightly because it is
more sensitive to machine load:

```powershell
.\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions
```

Large XML macro-benchmarks are also nightly-only and require pre-decompressed
real corpus files prepared outside the workspace:

```powershell
.\scripts\run_large_xml_benchmarks.ps1 `
  -XmlFile C:\data\pubmed\pubmed25n0001.xml `
  -Iterations 1 `
  -Repetitions 3
```

## Jenkins Pipeline

The all-tests pipeline is in:

```text
ci/Jenkinsfile.all-tests
```

The Windows Phase 1 release-oriented pipeline is in:

```text
ci/Jenkinsfile.windows-phase1
```

Recommended agent prerequisites:

- Windows x64 agent.
- EiffelStudio command-line tools on `PATH`, including `ec` and
  `finish_freezing`.
- Visual Studio 2022 C++ build tools.
- CMake on `PATH`, or installed at `C:\Program Files\CMake\bin\cmake.exe`.
- A prepared Expat 2.8.1 source checkout or release tree.
- Optional WSL2 Ubuntu with `gcc` for cross-platform ABI smoke.
- Optional CPython source checkout for L3 public-application replacement.

Recommended Jenkins parameters:

- `EXPAT_SOURCE_DIR`
  Path to the upstream Expat source tree.
- `RUN_BENCHMARKS`
  Run benchmark publication on nightly builds only.
- `RUN_PUBLIC_APP`
  Run CPython replacement experiment.
- `CPYTHON_SOURCE_DIR`
  Path to a CPython checkout.

## Public Application Replacement Candidate

Primary candidate: CPython.

Reason:

- CPython is widely used.
- It includes a `pyexpat` module and higher-level XML modules.
- Its own test suite exercises Expat through realistic public APIs.

The replacement verification should have two lanes.

### CPython Baseline Lane

Build CPython normally and run the XML-related tests:

```powershell
cd $env:CPYTHON_SOURCE_DIR
.\PCbuild\build.bat -p x64 -c Release
.\PCbuild\amd64\python.exe -m test `
  test_pyexpat `
  test_xml_etree `
  test_xml_dom_minidom `
  test_xml_sax `
  test_xmlrpc
```

The baseline must pass before xpact replacement results mean anything.

### CPython xpact Lane

Build xpact first:

```powershell
cd $env:XPACT_WORKSPACE
.\scripts\build_native_eiffel.ps1
```

Then modify the CPython `pyexpat` build so that:

- `pyexpat` includes xpact's `include` directory for `expat.h`;
- `pyexpat` links against `build\native-eiffel\xpact.lib`;
- `xpact.dll` is copied beside the CPython test interpreter or placed on
  `PATH`;
- bundled Expat C source objects are not linked into `pyexpat` for this lane.

The exact CPython project-file patch should be kept in CI once selected. On
Windows, expect to inspect `PCbuild\pyexpat.vcxproj` and the Expat-related
property files in `PCbuild`.

Then run the same tests:

```powershell
cd $env:CPYTHON_SOURCE_DIR
$env:PATH = "$env:XPACT_WORKSPACE\build\native-eiffel;$env:PATH"
.\PCbuild\amd64\python.exe -m test `
  test_pyexpat `
  test_xml_etree `
  test_xml_dom_minidom `
  test_xml_sax `
  test_xmlrpc
```

Acceptance rule:

- If the baseline passes and the xpact lane fails, record each failure as a
  drop-in gap.
- If both fail, fix the CPython baseline environment first.
- If the xpact lane passes, archive the CPython commit, patch, xpact commit,
  DLL checksum, and test log as release evidence.

## What Jenkins Should Archive

Archive these artifacts:

- `EIFGENs/**/W_code/*.exe` and `EIFGENs/**/F_code/*.exe` when preserved by
  the CI job configuration
- `build/native-eiffel/xpact.dll`
- `build/native-eiffel/xpact.lib`
- `build/native-eiffel/xpact_assertions.dll`
- `build/native-eiffel/xpact_assertions.lib`
- `build/libexpat-adapter-current/libexpat-runtests-manifest.tsv`
- `build/libexpat-adapter-current/libexpat-expected-failures-expanded.tsv`
- `build/libexpat-adapter-current/libexpat-parity-expanded.tsv`
- `build/libexpat-adapter-current/libexpat-native-suite.log`
- `build/chunked-crc/chunked-crc-results.tsv`
- `docs/benchmarks.md` when benchmarks run
- `docs/large-xml-benchmarks.md` when large XML benchmarks run
- `docs/performance-analysis.md` when benchmarks run
- `build/large-xml-benchmarks/large-xml-benchmark-results.tsv` when large XML
  benchmarks run
- `dist/*.zip`
- CPython baseline and xpact-lane test logs when `RUN_PUBLIC_APP` is enabled

## Future CI Improvements

The current native-suite gate knows the expected-failure manifest, but it does
not yet parse the upstream test runner output into exact unexpected test names.
Before a public replacement claim, add a parser that:

- extracts failing upstream `START_TEST` names from the native-suite log;
- compares them with `adapters/libexpat/expected-failures.tsv`;
- fails the build if any non-expected row fails;
- fails the build if an expected row unexpectedly passes and the manifest was
  not updated.
