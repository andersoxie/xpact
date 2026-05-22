# Upstream libexpat Test Adapter

This adapter connects xpact to an upstream libexpat checkout, currently
targeting Expat 2.8.1 (`R_2_8_1`).

It has two modes:

- `scripts/run_libexpat_adapter.ps1` extracts a manifest from the upstream C
  tests and can run xpact over XML fixture files found in the upstream tree.
- `adapters/libexpat/CMakeLists.txt` builds the upstream C unit-test harness
  against xpact's libexpat-compatible native ABI once that DLL/SO exists.

## Manifest And Corpus Smoke

```powershell
git clone --branch R_2_8_1 https://github.com/libexpat/libexpat.git C:\src\libexpat
.\scripts\run_libexpat_adapter.ps1 -ExpatSourceDir C:\src\libexpat -Mode All
```

Outputs are written under `build\libexpat-adapter`:

- `libexpat-runtests-manifest.tsv`: `START_TEST(...)` names found in upstream
  C test sources.
- `libexpat-corpus-results.tsv`: xpact parse results for upstream `.xml`
  fixture files discovered under `expat\tests` and `expat\xmlwf`.

The corpus runner records accept/reject results; it does not infer conformance
from arbitrary fixture names.

## Native C Suite

After xpact has a native library exporting the declarations in `include\xpact.h`:

```powershell
cmake -S adapters\libexpat -B build\libexpat-adapter\cbuild `
  -DEXPAT_SOURCE_DIR=C:\src\libexpat `
  -DXPACT_LIBRARY=C:\path\to\xpact.lib `
  -DXPACT_INCLUDE_DIR=$PWD\include
cmake --build build\libexpat-adapter\cbuild
ctest --test-dir build\libexpat-adapter\cbuild --output-on-failure
```

The adapter puts `adapters\libexpat\include` first on the include path so
upstream tests include xpact's `expat.h` shim rather than upstream Expat's
header.

On Windows, pass the import `.lib` as `XPACT_LIBRARY`. On Unix-like systems,
pass the shared object or static archive.
