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

Until the Eiffel bridge is wired in, `XML_Parse` returns an explicit
`XML_ERROR_NOT_STARTED` failure rather than falling back to a C parser. The
runtime smoke target now proves the end-to-end path in an Eiffel executable,
but the standalone DLL/SO build still remains C-only. The next native work
should package the verified runtime bridge path as the standalone native export
artifact.

Run the native ABI smoke tests with:

```powershell
.\scripts\run_native_abi_tests.ps1 -Target All
```

Run the Eiffel-runtime bridge smoke test with:

```powershell
.\scripts\run_native_runtime_smoke.ps1
```
