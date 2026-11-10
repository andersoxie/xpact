# Upstream libexpat Test Adapter

This adapter connects xpact to an upstream libexpat checkout, currently
targeting Expat 2.8.1 (`R_2_8_1`).

It has three paths:

- `scripts/run_libexpat_adapter.ps1` extracts a manifest from the upstream C
  tests and can run xpact over XML fixture files found in the upstream tree.
- `adapters/libexpat/CMakeLists.txt` builds the upstream C unit-test harness
  against xpact's libexpat-compatible native ABI. The current Windows path
  links against the Eiffel-backed import library; Unix-like SO packaging
  remains future platform work.
- `adapters/libexpat/expected-failures.tsv` records native-suite gaps that are
  allowed while parity work is still in progress.

## Manifest And Corpus Smoke

```powershell
git clone --branch R_2_8_1 https://github.com/libexpat/libexpat.git C:\src\libexpat
.\scripts\run_libexpat_adapter.ps1 -ExpatSourceDir C:\src\libexpat -Mode All
```

Outputs are written under `build\libexpat-adapter`:

- `libexpat-runtests-manifest.tsv`: `START_TEST(...)` names found in upstream
  C test sources.
- `libexpat-expected-failures-expanded.tsv`: expected-failure patterns expanded
  against the upstream manifest.
- `libexpat-parity-expanded.tsv`: green/red parity rows expanded
  against the upstream manifest.
- `libexpat-corpus-results.tsv`: xpact parse results for upstream `.xml`
  fixture files discovered under `expat\tests` and `expat\xmlwf`.

The corpus runner records accept/reject results; it does not infer conformance
from arbitrary fixture names.

Use `-OutputDir` to choose another output directory. Relative paths are resolved
from the xpact repository root; absolute paths are used as supplied by Jenkins.

## Native C Suite With Expected Failures

For the current Windows Eiffel-backed native library:

```powershell
.\scripts\build_native_eiffel.ps1
.\scripts\run_libexpat_adapter.ps1 `
  -ExpatSourceDir C:\src\libexpat `
  -Mode NativeSuite `
  -XpactLibrary build\native-eiffel\xpact.lib `
  -SkipNativeBuild
```

The adapter puts `adapters\libexpat\include` first on the include path so
upstream tests include xpact's `expat.h` shim rather than upstream Expat's
header.

On Windows, pass the import `.lib` as `XPACT_LIBRARY`. On Unix-like systems,
pass the shared object or static archive.

Without `-XpactLibrary` (and without `XPACT_EXPAT_LIBRARY`) the adapter uses
`build\native-eiffel\xpact.lib`, and `-Mode NativeSuite` without
`-SkipNativeBuild` builds it first with `build_native_eiffel.ps1`. It never
picks `build\native\xpact.lib` by itself: that is the C bridge without the
Eiffel parser, and every parse through it fails with error 44. The suite log
names the library it used (`libexpat native suite: xpact library ...`).

The expected-failure list no longer allows a suite-wide `*/*` wildcard. It now
contains specific source/name patterns for the remaining red parity gaps, while
`adapters/libexpat/parity.tsv` records green and red rows for the
Windows-only release scope. If the native suite passes while expected failures
remain, the runner fails and requires the list to be updated. Internally the
runner still configures the CMake adapter, builds the upstream `runtests`
executable, and runs it through `ctest --verbose`.

On Windows 10 or later, each registered test runs in a separate child process.
Passing tests exercise all 12 chunk-size/deferral combinations; a test stops at its
first assertion failure. A failing callback exits the child immediately rather
than jumping across active Eiffel frames. The parent collects each result and
continues with a fresh process for the next test.

The adapter applies the selected reparse-deferral default to every parser factory
and successful reset. External entity parsers inherit their parent's setting.
This makes both deferral configurations exercise the requested native behavior.

Each child has a 120-second timeout, configurable with the CMake cache setting
`XPACT_TEST_TIMEOUT_SECONDS` (1 to 3600 seconds). CTest also limits the complete
suite to 1800 seconds. Cancelling the parent terminates its active child.

An expected-failure result is accepted only when the upstream runner reports a
complete test summary and every reported failure matches the configured
source/name patterns. Test sources are resolved from the manifest because an
assertion can originate in a shared helper. Crashes, incomplete runs, and
unlisted failures fail the stage. CTest output is printed in Jenkins and saved
to `libexpat-native-suite.log`; a validated expected-failure result returns a
successful process status to Jenkins.

Run the orchestration regression tests without building Eiffel or CMake:

```powershell
python -m unittest discover -s tests/python -p test_libexpat_adapter.py
```

Native process-isolation tests also require CMake and the Windows C toolchain:

```powershell
python -m unittest discover -s tests/python -p test_libexpat_isolation.py
```

Run all adapter regressions, including factory/reset configuration checks:

```powershell
python -m unittest discover -s tests/python -p 'test_libexpat_*.py'
```

See `docs/libexpat-parity.md` for the current Windows Phase 1 parity summary.
