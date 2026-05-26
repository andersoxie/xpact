# Upstream libexpat Test Adapter

This adapter connects xpact to an upstream libexpat checkout, currently
targeting Expat 2.8.1 (`R_2_8_1`).

It has three paths:

- `scripts/run_libexpat_adapter.ps1` extracts a manifest from the upstream C
  tests and can run xpact over XML fixture files found in the upstream tree.
- `adapters/libexpat/CMakeLists.txt` builds the upstream C unit-test harness
  against xpact's libexpat-compatible native ABI once that DLL/SO exists.
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

## Native C Suite With Expected Failures

After xpact has a native library exporting the declarations in `include\xpact.h`:

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

The expected-failure list no longer allows a suite-wide `*/*` wildcard. It now
contains specific source/name patterns for the remaining red parity gaps, while
`adapters/libexpat/parity.tsv` records green and red rows for the
Windows-only release scope. If the native suite passes while expected failures
remain, the runner fails and requires the list to be updated. Internally the
runner still configures the CMake adapter, builds the upstream `runtests`
executable, and runs it through `ctest --output-on-failure`.

See `docs/libexpat-parity.md` for the current Windows Phase 1 parity summary.
