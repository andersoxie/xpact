# 10 · Python's own XML tests on top of xpact

> **Question:** Can xpact replace Expat under a real application? CPython's `pyexpat` module is one of the biggest Expat users.
> **Status:** ✅ run (2026-10-28) · ✅ `pyexpat` builds and runs on xpact · 🔴 36 failures + 2 errors in 976 CPython tests (7 groups), the same in the assertions build · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

1. CPython **v3.14.0**'s `Modules/pyexpat.c` (sparse clone in `download/`, not for git) was compiled **unchanged** and linked against `xpact.lib` instead of Expat ([build-pyexpat.ps1](build-pyexpat.ps1), one-line header shim [shim/expat.h](shim/expat.h)).
2. Python then really uses xpact: `pyexpat.EXPAT_VERSION` = `expat_2.8.1` (xpact's version string), and `ElementTree`, SAX and minidom parse through it.
3. CPython's own test suites for XML ran twice: with Python's Expat (baseline) and on xpact. The Python installation itself is not changed.

| | Python's Expat 2.7.3 | **xpact** |
|---|---|---|
| Test files | 10 of 10 OK | 6 of 10 OK |
| Tests run | 975 | 976 |
| ❌ Failures + errors | **0** | **36 + 2** |
| Assertions build (`xpact_assertions.dll`) | | identical failures |
| Skipped | 29 | 43 (¹) |

✅ Pass on xpact: `test_minidom`, `test_pulldom`, `test_xml_dom_minicompat`, `test_xml_dom_xmlbuilder`, `test_xmlrpc`, `test_plistlib`
❌ Fail on xpact: `test_pyexpat` (9), `test_sax` (3), `test_xml_etree` (13), `test_xml_etree_c` (13, the same tests)

(¹) The C accelerator `_elementtree` refuses the xpact `pyexpat` (19 extra "requires _elementtree" skips), probably because of its compile-time Expat version check (2.7.3 vs 2.8.1). So `test_xml_etree_c` ran the pure-Python ElementTree.

Logs: [logs/run-baseline.txt](logs/run-baseline.txt), [logs/run-xpact.txt](logs/run-xpact.txt)

## The 38 failures and errors in 7 groups

| # | Group | Tests | What CPython expects (Expat) | What xpact does |
|---|---|---|---|---|
| 🔴 F10-1 | **Unparsed entities go to the wrong handler** | `test_pyexpat` `ParseTest` ×3 | `<!ENTITY u SYSTEM "x" NDATA n>` → `UnparsedEntityDeclHandler` (Expat prefers it when set) | `EntityDeclHandler` |
| 🔴 F10-2 | **`XML_SetUnknownEncodingHandler` not used** | `test_encoding` ×2, `test_bug_xmltoolkit62` ×2 | Python's handler maps 8-bit encodings (`iso-8859-15`, `cp437`, `windows-1252` …) and the document parses | "unknown encoding"; for `windows-1252` the curly quotes are **lost from the text** |
| 🔴 F10-3 | **Reparse deferral and incremental events differ** | `XMLPullParserTest` ×5 ×2, `test_flush_reparse_deferral_*` ×4 (etree + SAX) | events appear after the `feed()` that completes them; with deferral, nothing appears before `flush()` | an `end` event comes one `feed()` late; with deferral, `start` comes too early |
| 🔴 F10-4 | **Skipped entity not passed to the default handler** | `test_bug_xmltoolkit55` ×2 | `&ldots;` (undeclared, external DTD not read) is passed to `DefaultHandlerExpand`, and ElementTree raises "undefined entity" | no call, so no error: the reference disappears silently |
| 🔴 F10-5 | **Error codes and positions** | `MalformedInputTest` ×2, `test_error_code` ×2, `test_error_position` ×2, `test_iterparse` ×2, `test_entity` ×2 | e.g. `foo` → `XML_ERROR_SYNTAX` (2) at column 0; `<a/>junk` → "junk after document element" col 12 | `XML_ERROR_INVALID_TOKEN` (4); other column; "invalid token" col 15; "error in processing external entity reference" instead of "undefined entity" |
| 🟡 F10-6 | **Text split into other pieces** | `BufferTextTest`, `ChardataBufferTest` ×2, `test_sax CDATAHandlerTest` | `"2\n3"` in one `CharacterData` call; buffer flushes counted | `"2"`, `"\n"`, `"3"` as three calls; one flush less/more. Allowed by Expat's API, but tests and applications that assume one call per line break notice it |
| 🔴 F10-7 | **`UseForeignDTD`: other arguments to the external-entity handler** | `ForeignDTDTests.test_use_foreign_dtd` | `(base, systemId)` = `(None, None)` | `(None, 'foreign.dtd')` |

Every group above is a separate problem for an issue. **F10-5** overlaps with the error-code differences of tests 2, 4 and 7 (compare #122–#126).

## Problem report (shared fields)

| Field | |
|---|---|
| **Environment** | Windows 11, CPython 3.14.0 (v3.14.0 `ebf955d`, MSC 1944 x64); `xpact.dll` / `xpact.lib` from `w9-latest` (`student-Mass` `293918f`); MSVC 19.51 |
| **Command** | `powershell -File build-pyexpat.ps1`, then `sh run-tests.sh baseline` and `sh run-tests.sh xpact` |
| **Expected** | the same test result as with Python's Expat: 975 tests, 0 failures |
| **Actual** | 36 failures (table above) |
| **Investigation** | baseline with the same test files and the same Python; the failing assertions read one by one |
| **Cause** | unknown for each group; F10-3 is probably the DLL's whole-buffer design (see test 5, F05-1) |
| **Fix / Verification** | none yet / ⬜ rerun `run-tests.sh xpact` |

## Limitations

- `_elementtree` (the C accelerator) does not load on the xpact build, so its code path is not tested.
- `test_xml_etree_c` therefore repeats `test_xml_etree`; 13 of the 38 are the same tests counted twice.
- Assertions build: [logs/run-xpact_assertions.txt](logs/run-xpact_assertions.txt), the same failures.

## To do

- [ ] Issues for F10-1 … F10-7
- [x] Rerun with the assertions build: identical
- [ ] Find why `_elementtree` refuses the module (version check in `Modules/_elementtree.c`)
