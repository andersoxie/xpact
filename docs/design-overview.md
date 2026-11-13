# Design Overview

xpact has three layers:

- Eiffel parser core;
- Eiffel-to-native adapter;
- C ABI export layer.

The parser core owns XML behavior. The native layer owns compatibility with C
callers. The libexpat adapter owns comparison with the upstream test suite.

## Parser Core

Primary classes:

- `XP_PARSER`
  Parses XML 1.0 input, emits events, handles entities and DTD declarations,
  records accounting and positions, and enforces resource limits.
- `XP_EVENT_HANDLER`
  Deferred event sink used by the parser.
- `XP_ATTRIBUTES`
  Attribute vector with duplicate checking, specified/default counts, and ID
  attribute position support.
- `XP_TOKEN_SLICE`
  Holds a buffer, offset and length for an element name in the no-event parsing
  path, avoiding a separate name string while the element is open.
- `XP_EXTERNAL_ENTITY_RESOLVER`
  Capability object supplied by an application when external entity loading is
  allowed.
- `XP_EXTERNAL_ENTITY_POLICY`
  Policy constants that gate external general entities, parameter entities,
  and external subsets.
- `XP_GC_CRITICAL_SECTION`
  Temporarily suspends Eiffel garbage collection during explicitly selected
  critical sections, then restores the previous collection state under
  contract.

The core design rule is simple: XML semantics should be visible in Eiffel
contracts and Eiffel code.

The core consumes complete `READABLE_STRING_8` inputs. Its no-event path already
uses slice-backed element names, avoids materializing simple attributes and text,
defers position accounting, and can reuse suitable normalized `STRING_8` input.
Eventful, namespace and DTD paths retain materialization where required. Further
performance work extends these paths and considers string pooling and native
byte-buffer input.

Parser reuse still produces temporary objects: element slices are created and
removed as elements open and close, and reset rebuilds per-document state.
Temporary GC suspension preserves the previous runtime collection setting; it
does not reclaim those objects or establish that a long-lived application needs
no collector. Runtime support is compiler-dependent: Gobo 26.10's controls were
stubs, while the 26.11.12 nightly passed the bounded GC-state probes described in
[the compiler qualification](gobo-assertions.md).

## Native Adapter

Primary classes and C files:

- `XP_NATIVE_PARSER`
  Keeps libexpat-compatible parser state and maps native parse calls to
  `XP_PARSER`.
- `XP_NATIVE_CALLBACK_HANDLER`
  Converts Eiffel events into native callback calls and exposes callback
  interest so no-callback parse paths avoid unnecessary native payload work.
- `XP_NATIVE_BRIDGE_INSTALLER`
  Owns native parser handles and resolves them back to Eiffel parser objects.
- `XP_NATIVE_BRIDGE_EXPORT`
  Registers Eiffel feature pointers with the runtime bridge.
- `native/xpact_native.c`
  Exports `XML_*` symbols and delegates behavior through the private Eiffel
  bridge.
- `native/xpact_eiffel_runtime_bridge.c`
  Trampoline between C function pointers and Eiffel runtime feature pointers.

The native design rule is also simple: C may hold handles and call callbacks,
but it must not become the XML parser.

## Test And Compatibility Layer

Primary files:

- `tests/xp_test_root.e`
  Eiffel regression suite run with ordinary contracts enabled and disabled;
  its explicit test checks execute in both modes.
- `tests/native/xpact_abi_smoke.c`
  Public C ABI smoke test.
- `tests/native/xpact_bridge_smoke.c`
  Private bridge smoke test.
- `tests/native/xpact_eiffel_dll_smoke.c`
  External C caller smoke test for the Eiffel-backed Windows DLL.
- `adapters/libexpat`
  CMake overlay and shims for building upstream Expat tests against xpact.
- `docs/libexpat-parity.md`
  Current upstream parity status.

## Main Runtime Path

```text
C caller
  -> XML_ParserCreate / XML_Parse in xpact.dll
  -> native/xpact_native.c
  -> XPACT_EiffelBridge function table
  -> native/xpact_eiffel_runtime_bridge.c
  -> XP_NATIVE_BRIDGE_INSTALLER
  -> XP_NATIVE_PARSER
  -> XP_PARSER
  -> XP_EVENT_HANDLER callbacks
  -> XP_NATIVE_CALLBACK_HANDLER
  -> C caller callback
```

## External Entity Path

```text
XP_PARSER
  -> external entity declaration or reference
  -> XP_EXTERNAL_ENTITY_POLICY check
  -> XP_EXTERNAL_ENTITY_RESOLVER.resolve_external_entity
  -> returned replacement text, or Void for denial/error
  -> normal Eiffel parsing under recursion and expansion limits
```

`XP_PARSER` does not open files, URLs or sockets for external entities. It calls
the configured resolver; a resolver such as `XP_LOCAL_EXTERNAL_ENTITY_RESOLVER`
may perform the application's authorized resource loading.

## EiffelStudio BON Diagrams

EiffelStudio's Diagram Tool displays Eiffel systems in BON notation after
compilation. The IDE reads the Eiffel classes through the `.ecf` target and
then builds the BON view from that compiled system. The source-controlled
`.bon` files in `docs/bon/` are textual view recipes that name the intended
class sets and relationships, so the graphical IDE views can be recreated
consistently.

References:

- EiffelStudio Diagram Tool: https://www.eiffel.org/doc/eiffelstudio/Diagram_tool
- EiffelStudio BON notation summary: https://www.eiffel.org/doc/eiffelstudio/Notation

To inspect or regenerate the interactive IDE diagrams:

1. Open `xpact.ecf` or `tests/xpact_native_library.ecf` in EiffelStudio.
2. Compile the selected target.
3. Open the Diagram Tool.
4. Use the classes listed in `docs/bon/*.bon` as the view contents.
5. Keep the view in BON mode, or toggle to UML if you need feature-level
   details.
6. In EiffelStudio 25.02 and later, save diagram views from the Diagram Tool so
   the IDE-managed view data is stored under `EIFDATA`.

Suggested views:

- `docs/bon/xpact-parser-core.bon`
- `docs/bon/xpact-native-bridge.bon`
- `docs/bon/xpact-verification.bon`
