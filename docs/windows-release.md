# xpact Windows Native Release

The first native-library package is intentionally Windows x64 only. It ships
the Eiffel-backed `xpact.dll` and its MSVC import library, not the bridge-only
placeholder DLL/SO build.

## Scope

- Platform: Windows x64.
- C API surface: `include/xpact.h`, tracking the libexpat 2.8.1 public header
  surface used by xpact.
- Native library: `bin/xpact.dll`, initialized with the Eiffel runtime and
  wired to the Eiffel parser core.
- Link library: `lib/xpact.lib`.
- Out of scope for this package: Linux/WSL `libxpact.so`, MinGW import
  libraries, and claims of full libexpat behavioral parity while the expected
  failure list still exists.

## Build The Package

```powershell
.\scripts\package_windows_release.ps1
```

The package script runs `scripts\build_native_eiffel.ps1`, which finalizes the
Eiffel native-library target and runs an external C smoke test against the
generated import library. The resulting archive is written to:

```text
dist\xpact-0.1.0-preview-windows-x64.zip
```

Use `-Version` to choose a release label:

```powershell
.\scripts\package_windows_release.ps1 -Version 0.1.0
```

## Package Layout

```text
xpact-<version>-windows-x64\
  bin\xpact.dll
  lib\xpact.lib
  include\xpact.h
  examples\xpact_eiffel_dll_smoke.c
  docs\benchmarks.md
  docs\libexpat-api-compatibility.md
  README-WINDOWS.md
  PROJECT-README.md
  SHA256SUMS.txt
  VERSION.txt
```

## Consumer Link Smoke

A C consumer can compile the included smoke source with MSVC:

```powershell
cl /nologo /Iinclude examples\xpact_eiffel_dll_smoke.c lib\xpact.lib /Fe:xpact_eiffel_dll_smoke.exe
.\xpact_eiffel_dll_smoke.exe
```

Expected output:

```text
xpact Eiffel DLL smoke: ok
```
