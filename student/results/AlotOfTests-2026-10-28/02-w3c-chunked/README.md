# 2 · W3C fed in chunks

> **Question:** Does xpact give the same result whether a document arrives whole, in two pieces, or one byte at a time?
> **Status:** ✅ run (2026-10-28) · ✅ the verdict never changes · 🔴 the events change in 581 documents (3 problems) · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

All 2,585 W3C documents through `xpact.dll` and Expat:
- whole;
- byte by byte;
- split in two at **every** byte position (documents up to 4 KB).

| Result | Documents |
|---|---:|
| ✅ the same verdict, error code and events in every mode | **1,995** |
| ✅ **the verdict (ACCEPT/REJECT) changes** | **0** |
| 🔴 only xpact changes: other **events** | 581 |
| 🔴 only xpact changes: other **error code** | 1 (`hst-lhs-009`) |
| ⏱ xpact too slow for the every-split test (timeout 300 s, see test 5 F05-1) | 3 |
| ⚪ Expat changes as well (error code at a different position) | 5 |

Per case: [logs/chunked-xpact.tsv](logs/chunked-xpact.tsv) · what changed: [logs/unstable-xpact.tsv](logs/unstable-xpact.tsv)

## Problems

| # | Problem | Documents | Example |
|---|---|---:|---|
| 🔴 F02-1 | **`startdoctype` is reported twice** when the document has an internal DTD subset and arrives in several pieces | 481 | `valid-sa-028` byte by byte: `xmldecl, startdoctype, startdoctype, elementdecl, …`; whole and Expat: one `startdoctype` |
| 🔴 F02-2 | **Events before an error depend on chunking.** Whole document: xpact reports **nothing** before the error. In pieces: everything up to the error, as Expat does in both modes | 100 | `not-wf-sa-030`: whole `[]`; byte by byte and Expat `start, chars` |
| 🔴 F02-3 | **Error code depends on chunking** | 1 | `hst-lhs-009`: whole `XML_ERROR_PARTIAL_CHAR` (6); byte by byte `XML_ERROR_INVALID_TOKEN` (4); Expat the same in both |

### F02-1 · Duplicate `startdoctype`

| Field | |
|---|---|
| **Environment** | `xpact.dll` from `w9-latest` (`student-Mass` `293918f`), Windows 11, Python 3.14 ctypes harness |
| **Command** | `python run.py` then `python analyze.py` in this folder |
| **Smallest repro** | `<?xml version="1.0"?><!DOCTYPE d [<!ENTITY e "v">]><d/>` fed byte by byte |
| **Expected** | one `startdoctype` (whole xpact, Expat whole and chunked) |
| **Actual** | two `startdoctype` events; the declarations are not repeated |
| **Investigation** | the 2-piece split at every position does **not** trigger it on the small repro; byte by byte (many calls) does |
| **Cause** | suspected: the DLL re-parses the whole buffer on each call (see test 5, F05-1) and has a cached-DOCTYPE path (`l_use_cached_doctype`, `doctype_prefix_complete` in `src/xp_native_parser.e`); the "already delivered" bookkeeping seems to miss the `startdoctype` callback. Not confirmed |
| **Fix / Verification** | none yet / ⬜ |

### F02-2 · No events before an error in whole mode

| Field | |
|---|---|
| **Expected** | the events up to the error point, as Expat delivers them, in both modes |
| **Actual** | whole mode: none (xpact checks the whole buffer first, then delivers); chunked mode: as Expat |
| **Cause** | suspected: whole-buffer parsing with deferred callbacks. Check whether this is one of the known Expat differences #122–#126 |

## Limitations

- Only the main document is chunked; external entities are always read whole.
- Every-split test only for documents ≤ 4 KB (2,5xx of 2,585); larger ones only whole vs byte by byte.
- DLL path only.

## To do

- [ ] Issues for F02-1 … F02-3 (check F02-2 against #122–#126 first)
- [ ] Rerun with `xpact_assertions.dll`
