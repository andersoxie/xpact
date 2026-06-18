# Incremental Core Prototype

`XP_INCREMENTAL_PARSE_SESSION` is the first isolated prototype for the true
incremental parser core. It is not wired into `XP_NATIVE_PARSER` yet.

The point of this step is to establish a state-owned parsing shape before
moving production behavior away from accumulated-buffer replay.

## Current Scope

The prototype currently owns:

- an unconsumed input window;
- byte, line, and column counters;
- the element stack;
- reserved entity, namespace, DTD, and encoding decoder state slots;
- final-buffer, finished, suspended, and error state;
- callback delivery through the existing `XP_EVENT_HANDLER` abstraction.

It can incrementally parse a small but useful subset:

- start tags with quoted attributes;
- empty-element tags;
- end tags;
- character data;
- chunk splits inside start tags and attribute values;
- mismatched end-tag errors;
- resumable callback suspension hooks.

Completed tokens are consumed from `buffer_window`, so the prototype does not
retain the full document prefix after emitting callbacks.

## Verified Behaviors

The Eiffel regression suite currently checks that:

- a chunk ending inside an attribute value waits for more input and keeps only
  the incomplete token;
- the completed attributed start tag is emitted when the next chunk arrives;
- a completed attributed start tag in a non-final chunk is emitted immediately,
  unlike the current native replay shim with reparse deferral enabled;
- non-final character data is emitted and consumed;
- final end tags finish the session;
- mismatched end tags produce an error.

## Not In Scope Yet

The prototype does not yet cover XML declarations, comments, CDATA, DTDs,
entities, namespaces, encoding boundaries, external entity child parsers, or
native API integration. Those pieces should move over incrementally while the
CRC harness and shim audit continue to protect observable behavior.
