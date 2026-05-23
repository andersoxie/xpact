# xpact Native Export Layer

This directory contains the native `include/xpact.h` export layer.

The current layer is intentionally bridge-only. It exports the libexpat-shaped
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

The next native packaging work is the equivalent Linux/WSL `libxpact.so` path
and then the native xpact-vs-libexpat benchmark through the same C ABI.

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
