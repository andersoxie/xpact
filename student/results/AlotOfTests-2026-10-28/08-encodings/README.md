# 8 · Encodings

> **Question:** Does xpact handle input encodings and broken byte sequences correctly?
> **Status:** ✅ run (2026-10-28) · ✅ 141 of 146 · 🔴 2 problems + 1 belongs to F01-7 · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

146 small documents, each through `xpact.dll` and Expat, **whole and byte by byte**.
Compared: verdict, error code, and the events of accepted documents.

| Group | Cases | Result |
|---|---:|---|
| UTF-8 with and without BOM, UTF-16 LE/BE with BOM, ISO-8859-1, US-ASCII | 6 | ✅ all, same events as Expat |
| UTF-16 without BOM, `UTF-16LE` declaration, odd length, unpaired surrogates | 5 | ✅ 4 · 🔴 1 error code (F08-2) |
| Broken UTF-8 (overlong, surrogates, > U+10FFFF, F5/FF bytes, lone continuation, cut off, U+FFFE/FFFF, control 0x01) × text, attribute, comment, PI, CDATA, name | 90 | ✅ **all rejected**, also byte by byte |
| C1 control U+0085 (legal in XML 1.0 text) | 6 | ✅ |
| Boundary code points U+007F … U+10FFFF in text, attribute, CDATA | 27 | ✅ same events as Expat |
| Character references `&#x0;` … `&#x110000;`, `&#99999999999;` | 9 | ✅ |
| Unknown encoding without a handler (`windows-1252`, `x-nonsense`) | 2 | ✅ REJECT "unknown encoding", as C Expat (¹) |
| Encoding given to `XML_ParserCreate` | 3 | 🔴 F08-1 |
| UTF-8 BOM + `encoding="UTF-16"` | 1 | 🔴 accepted, see F01-7 |

(¹) Python's `pyexpat` installs its own unknown-encoding handler that uses Python codecs, so it accepts `windows-1252` and crashes the worker on `x-nonsense`. C Expat without a handler reports error 18, like xpact.

Per case: [logs/encodings-xpact.tsv](logs/encodings-xpact.tsv) · console: [logs/run-xpact.txt](logs/run-xpact.txt)

## Problems

### 🔴 F08-1 · The encoding passed to `XML_ParserCreate` is ignored

| Field | |
|---|---|
| **Environment** | `xpact.dll` from `w9-latest` (`student-Mass` `293918f`), Python 3.14 ctypes harness, Expat = `pyexpat` 2.7.3 |
| **Command** | `python run.py` (cases `create-*`); repro below |
| **Expected** | Expat: "the encoding given to `XML_ParserCreate` overrides the document's own encoding declaration" |
| **Actual** | xpact uses the declaration: <br>UTF-8 bytes `C3 A9` with `XML_ParserCreate("ISO-8859-1")`: Expat `Ã©`, xpact `é` <br>Latin-1 byte `E9` with `XML_ParserCreate("UTF-8")`: Expat REJECT (invalid UTF-8), xpact ACCEPT <br>UTF-8 document with `XML_ParserCreate("UTF-16")`: both reject, but xpact gives error 19 (incorrect encoding), Expat 4 |
| **Cause** | unknown. `src/xp_native_parser.e` has `explicit_encoding_overrides_declaration`, but it seems to apply only to encodings xpact does not support itself |
| **Fix / Verification** | none yet / ⬜ |

### 🔴 F08-2 · Unpaired UTF-16 high surrogate at the end: other error code

`FF FE` + `<d>` + `00 D8` + `</d>` (UTF-16LE): xpact `XML_ERROR_INVALID_TOKEN` (4), Expat `XML_ERROR_NO_ELEMENTS` (3). Both reject; this is only the error code. Cause unknown.

### ➡ Belongs to F01-7: BOM and declaration that disagree

UTF-8 BOM followed by `encoding="UTF-16"`: Expat REJECT "encoding specified in XML declaration is incorrect", xpact ACCEPT. Same family as the W3C cases `hst-lhs-007` and `hst-lhs-008` ([test 1](../01-w3c-output-comparison/README.md)).

## Limitations

- An unknown-encoding **handler** (`XML_SetUnknownEncodingHandler` with a conversion table) is not tested yet: it needs a C callback structure.
- External entities in other encodings are covered by the W3C suite (test 1), not here.
- DLL path only.

## To do

- [ ] Issues for F08-1, F08-2
- [ ] Unknown-encoding handler test
- [ ] Rerun with `xpact_assertions.dll`
