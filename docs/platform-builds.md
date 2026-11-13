# Platform Build Preparation

The same Eiffel parser core runs in the Windows builds and Linux/WSL benchmarks.
The native release package targets Windows x64; Eiffel .NET integration and an
Eiffel-backed Linux shared-library package remain future work.

## Shared Core

The portable parser core is in `src/`:

- `XP_PARSER`
- `XP_EVENT_HANDLER`
- `XP_NULL_EVENT_HANDLER`
- XML entity, attribute, content-model, limit, and resolver classes

Those classes are void-safe and do not depend on the C export layer. Platform
targets should reuse them unchanged.

## Windows

Windows is the current Phase 1 native release platform.

```powershell
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All
.\scripts\build_native_eiffel.ps1
.\scripts\run_native_runtime_smoke.ps1 -AssertionMode All
.\scripts\run_native_abi_tests.ps1 -Target Windows
```

The Windows native package builds `xpact.dll` and `xpact.lib` from the Eiffel
parser plus the C ABI bridge.

## Linux

The verified Linux path builds the parser benchmark with EiffelStudio or Gobo
and GCC inside Ubuntu 24.04/WSL2. It uses the same parser and harness sources as
the Windows benchmarks. Configure the Linux compiler environments first, then
run from Windows:

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu-24.04
```

Both compilers are selected by default; use `-EiffelCompiler EiffelStudio` or
`-EiffelCompiler Gobo` to select one. Pass Linux Bash setup-file paths with
`-EiffelEnvironment` and `-GoboEnvironment` if the tools are not exposed by the
Linux login environment. The runner builds both finalized assertion modes and
the direct libexpat C baseline. Linux benchmark targets compile Base from source;
the EiffelStudio benchmark ECF restricts its safe Base precompile to Windows.

The 13 November 2026 comparison used Gobo `26.11.12+ca6541c` and EiffelStudio
`25.02.9.8723`. The shared Jenkins Gobo environment was updated, then its benchmark
launcher was run locally; those results are not a new Jenkins job build. See
[WSL setup and results](wsl-benchmarks.md) and
[compiler assertion qualification](gobo-assertions.md). These benchmark and
bounded compiler probes do not establish that the complete Windows regression
matrix or native library has been qualified on Linux.

The repository already has a bridge-only WSL/Linux C build path for
`build/native/libxpact.so`. The missing Linux native-release step is the
Eiffel-backed shared object equivalent of `scripts/build_native_eiffel.ps1`.
That future script should:

- finalize the Eiffel native-library target on Linux;
- compile `native/xpact_native.c` and
  `native/xpact_eiffel_runtime_bridge.c` as position-independent objects;
- link them with the finalized Eiffel generated objects and Eiffel runtime;
- export the same `include/xpact.h` C ABI from `libxpact.so`;
- run the same native ABI smoke tests and libexpat adapter suite.

No parser-source fork is intended for Linux.

## Eiffel .NET

The .NET build should also reuse the same parser core, but it should not include
the C ABI bridge classes or C inline externals. The C ABI is a native-library
concern; .NET should expose a managed adapter over `XP_PARSER`.

Preparation rules:

- keep parser behavior in `XP_PARSER` and related core classes;
- keep native C callback and bridge classes isolated from the core parser;
- add a dedicated .NET ECF target when the Eiffel .NET toolchain is installed
  on CI;
- run the same assertion-on and assertion-off Eiffel regression suite for the
  managed target;
- add a managed API adapter only after the native Phase 1 behavior remains
  stable.

This preserves the article's main point: contracts and parser semantics live in
Eiffel, while platform-specific export layers adapt the same source to native C,
Linux shared objects, or managed .NET consumers.
