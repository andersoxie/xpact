# Platform Build Preparation

The source layout is intended to support Windows, Linux, and Eiffel .NET builds
from the same Eiffel parser core.

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

Linux should use the same Eiffel source and the same assertion matrix. The first
Linux target is the core parser and tests:

```sh
ec -batch -config tests/xpact_tests.ecf -target xpact_tests
(cd EIFGENs/xpact_tests/W_code && finish_freezing)
./EIFGENs/xpact_tests/W_code/xpact_tests
ec -batch -config tests/xpact_tests.ecf -target xpact_tests_assertions
(cd EIFGENs/xpact_tests_assertions/W_code && finish_freezing)
./EIFGENs/xpact_tests_assertions/W_code/xpact_tests
```

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
