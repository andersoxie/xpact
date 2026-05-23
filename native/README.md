# xpact Native Export Layer

This directory contains the native `include/xpact.h` export layer.

The current layer is intentionally bridge-only. It exports the libexpat-shaped
public symbols, preserves the C callback ABI, and forwards parser operations to
an Eiffel-owned bridge registered through `XPACT_SetEiffelBridge`.

It must not implement XML tokenization, entity expansion, validation, or parser
state in C. Those semantics belong to the Eiffel parser classes under `src/`.
The Eiffel-side target for this bridge is `XP_NATIVE_PARSER`, with
`XP_NATIVE_CALLBACK_HANDLER` adapting parser events to Expat-style callback
slots.

Until the Eiffel bridge is wired in, `XML_Parse` returns an explicit
`XML_ERROR_NOT_STARTED` failure rather than falling back to a C parser. The next
native work should register the Eiffel bridge table from an Eiffel runtime or
shared-library export layer.

Run the native ABI smoke tests with:

```powershell
.\scripts\run_native_abi_tests.ps1 -Target All
```
