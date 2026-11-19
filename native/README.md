# xpact Native Export Layer

This directory contains the native `include/xpact.h` export layer.

The C export layer is intentionally a bridge. It exports the libexpat-shaped
public symbols, preserves the C callback ABI, and forwards parser operations to
an Eiffel-owned bridge registered through `XPACT_SetEiffelBridge`.

It must not implement XML tokenization, entity expansion, validation, or parser
state in C. Those semantics belong to the Eiffel parser classes under `src/`.
The Eiffel-side target for this bridge is `XP_NATIVE_PARSER`, with
`XP_NATIVE_CALLBACK_HANDLER` adapting parser events to Expat-style callback
slots. `XP_NATIVE_BRIDGE_INSTALLER` owns the Eiffel runtime handles that the
runtime trampoline calls: it creates `XP_NATIVE_PARSER` instances, maps opaque
native handles back through Eiffel object ids, forwards handler setters, and
supports both direct `XML_Parse` bytes and `XML_GetBuffer` / `XML_ParseBuffer`
style input. `xpact_eiffel_runtime_bridge.c` is that trampoline; it adopts the
installer object with the Eiffel runtime and registers a populated
`XPACT_EiffelBridge` table through `XPACT_SetEiffelBridge`.
`XP_NATIVE_BRIDGE_EXPORT` is the Eiffel-side installer/export object that passes
its `$feature` routine addresses into that trampoline.

The bridge-only build from `scripts/build_native.ps1` still returns an explicit
`XML_ERROR_NOT_STARTED` failure rather than falling back to a C parser when no
Eiffel bridge has been installed.

`scripts/build_native_eiffel.ps1` packages the Eiffel-backed Windows native
library. It compiles the C export layer and Eiffel runtime trampoline, finalizes
`tests/xpact_native_library.ecf`, links the finalized Eiffel objects with
`xpact_eiffel_dllmain.c`, and produces `build/native-eiffel/xpact.dll` plus
`build/native-eiffel/xpact.lib`. The script then builds
`tests/native/xpact_eiffel_dll_smoke.c` as an external C caller and verifies
that `XML_Parse` reaches the Eiffel parser through the public `include/xpact.h`
ABI.

Linux/WSL packaging for an Eiffel-backed `libxpact.so` remains deferred
platform expansion. The current native release path is Windows x64, and the
Windows native benchmark already exercises the Eiffel-backed DLL through the
public C ABI.
Direct Linux parser benchmarks already run with EiffelStudio and Gobo; they do
not use this shared-object path. See [the WSL benchmark guide](../docs/wsl-benchmarks.md)
for compiler setup and the November 2026 comparison.

`scripts/package_windows_release.ps1` creates the Windows-only release archive
under `dist/`. The archive contains `bin/xpact.dll`, `lib/xpact.lib`,
`bin/xpact_assertions.dll` and `lib/xpact_assertions.lib`,
`include/xpact.h`, Windows release notes, checksum rows, benchmark/parity
documentation, and the C smoke source used to verify a consumer link.

`scripts/run_benchmarks.ps1` also measures that Windows DLL through the public
C ABI. It compiles `benchmarks/xpact_native_c_benchmark.c` with MSVC, links
against `build/native-eiffel/xpact.lib`, runs with `build/native-eiffel` on
`PATH`, publishes create/free and parser-reuse rows in `docs/benchmarks.md`,
and records optimization history in `docs/performance-analysis.md`. Those dated
Windows ABI measurements are separate from the direct WSL compiler comparison.

`tests/native/xpact_chunked_crc.c` is a diagnostic harness for the public
`XML_Parse` contract. It compiles against either xpact or system libexpat,
feeds the same XML through multiple chunk sizes, and records semantic CRC-32
event digests. It does not parse XML in C; it only observes callback streams
from the active parser implementation. Use `scripts/run_chunked_crc_harness.ps1`
to build and run it.

Run the native ABI smoke tests with:

```powershell
.\scripts\run_native_abi_tests.ps1 -Target All
```

Run the Eiffel-runtime bridge smoke test with:

```powershell
.\scripts\run_native_runtime_smoke.ps1
```

Build and smoke the Eiffel-backed Windows DLL with:

```powershell
.\scripts\build_native_eiffel.ps1
```

Use `-BuildTier Assertions` for the finalized assertion-enabled DLL. These
native builds use EiffelStudio; the Gobo qualification currently covers direct
parser benchmarks and compiler probes.

Package the Windows-only native release with:

```powershell
.\scripts\package_windows_release.ps1
```

Threads (#274): every trampoline in `xpact_eiffel_runtime_bridge.c` holds one
process-wide, re-entrant lock while it is inside Eiffel, because the Eiffel runtime
is built with `concurrency support="none"`. Several threads, each with its own
parser, are safe (they take turns); a handler may call back into xpact on its own
thread. Measured cost for a single thread: none (median of 5 alternating runs).

Internal failures (#273): every entry feature of `XP_NATIVE_BRIDGE_INSTALLER` has a
`rescue`/`retry` guard. An Eiffel exception inside a DLL call (for example "No more memory",
or a contract violation in `xpact_assertions.dll`) no longer ends the process: the call
returns Expat's failure value (`XML_STATUS_ERROR`, `NULL`, `0`), and the parser is marked
failed. A failed parser answers only `XML_GetErrorCode` (`XML_ERROR_NO_MEMORY` for out of
memory, otherwise `XML_ERROR_UNEXPECTED_STATE`) and must be freed with `XML_ParserFree`;
other parsers keep working. Set the environment variable `XPACT_EXCEPTION_TRACE=1` to print
the Eiffel exception trace to stderr when this happens. Before #273 such an exception jumped
into the finished `DllMain` frame (`xpact_eiffel_dllmain.c`) and the process died with
`0xC00000FF` or "PANIC: main entry point vanished", without a trace.
