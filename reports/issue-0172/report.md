# Report: issue #172: a whole document gives no events before a forbidden character

> **Issue:** [#172](https://github.com/andersoxie/xpact/issues/172) F02-2 · G03-3 · found by G03 ([#169](https://github.com/andersoxie/xpact/issues/169)) and by the W3C-in-pieces test ([#165 report](../issue-0165/report.md), 139 documents)
> **Branch:** `fix/172-whole-document-events-before-char-error`, from `student-Mass` @ `5af2321`
> **Status:** ✅ cause confirmed · ⬜ fix not written yet · ⬜ not verified

## In short

Before xpact parses anything, `normalized_input` (`src/xp_parser.e`) walks the **whole** input. It converts line ends and checks that every character is an XML `Char`, and it stops with "invalid XML character" at the first forbidden one. A whole document therefore fails before the first callback. In pieces, the forbidden character isn't in the buffer yet while the start tag is parsed, so `start doc` arrives first. Expat checks characters as it tokenizes, so it gives the events in front of the character in every mode.

| Same document, 7 kinds | xpact whole | xpact split just before the character | Expat 2.8.1 (whole and split) |
|---|---|---|---|
| events before the error | ❌ none, in all 7 | ✅ the same as Expat, in all 7 | reference |
| error code | ✅ 4 | ✅ 4 | 4 |
| error position | ❌ 1:0 | ❌ 1:0 | the character (e.g. 1:8); separate issue [#171](https://github.com/andersoxie/xpact/issues/171) |

So xpact's event code already gives Expat's events. Only the up-front whole-input check hides them.

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | a document parsed whole reports no events before an error for a forbidden character; in pieces it does, as Expat does in every mode |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `5af2321`. DLLs built today from source identical to `5af2321` (no `.e`/`.ecf`/`.c`/`.h` change since `412b09d`): `xpact_assertions.dll` (assertions on, SHA-256 `2e7ab85cd3b4a5d0…`) and `xpact.dll` (production, `39dc11139d02f95a…`), MSVC finalized. Reference: `libexpat.dll` Expat 2.8.1 (`R_2_8_1`, `36a2532e2181ab8b…`, the same as in G03). Python 3.14.0. |
| **3. Command** | `python -I student\results\G03-comparison\compare.py --tag baseline172-assertions --xpact-dll build\native-eiffel\xpact_assertions.dll` (and `normal` with `xpact.dll`); `python -I reports\issue-0172\tools\probe.py <xpact dll> build\libexpat-R_2_8_1\build\libexpat.dll` |
| **4. Expected** | the events in front of the forbidden character, then error 4, as Expat |
| **5. Actual** | whole: no events, error 4 at 1:0 |
| **6. Error output** | none; the verdict is right ([probe](logs/probe-baseline-assertions.txt)) |
| **7. Investigation** | see below |
| **8. Cause** | ✅ **confirmed**, see below |
| **9. Fix** | planned, see below; not written yet |
| **10. Verification** | not yet |

## Investigation

1. **Baseline, G03 comparison** ([assertions log](logs/baseline-compare-assertions.txt), [normal log](logs/baseline-compare-normal.txt), [runs](logs/g03-baseline/)). `o-p02fail15` and `o-p02fail27` show "events differ", as in the issue. The assertions run has the same 34 differing cases as the committed G03 run. The committed normal run kept only its summary, so its list can't be compared. Both DLLs have the same summary: xpact is the same in all chunkings in 90 cases, Expat in 92.
2. **Where the error comes from.** "invalid XML character" is raised in about 20 places in `xp_parser.e`. Only `normalized_input` (line 6468) runs **before** parsing: every entry point (document, external entity, DTD subset; 9 call sites) calls it on its whole input and parses only if it found no error. The UTF-16 decoder (`utf_16_as_utf_8`) does not check `Char` at all, so for UTF-16 the check is also in `normalized_input`.
3. **Experiment** ([tools/probe.py](tools/probe.py), [assertions](logs/probe-baseline-assertions.txt), [normal](logs/probe-baseline-normal.txt), identical). There are 7 small documents with a forbidden character: in content, after a child, in an attribute, in a comment, before the root, after the root, and UTF-16LE like `o-p02fail15`. Each one runs whole, and split into two `XML_Parse` calls right before the character. In all 7, xpact split gives exactly Expat's events, and xpact whole gives none (where Expat gives none, before the root and in an attribute, xpact matches).

## Cause

✅ **Confirmed:** the whole-input character check in `normalized_input` raises the error before any callback. The experiment shows that the same parser fed the same bytes, cut at the character, delivers Expat's events.

## Planned fix (not written yet)

The fix makes the forbidden character act like the end of the input received so far:
1. `normalized_input` no longer fails at the first forbidden character. It remembers where the character is, and the text in front of it becomes the input.
2. The document entry used by the native DLL parses that text as a **non-final** piece, the same path the split experiment uses, and then raises "invalid XML character" (error 4).
3. External entities and DTD subsets keep the current behavior, at least in this first change. That keeps the fix to one entry point; their Expat behavior needs its own check.

Checks after the fix: G03 (`o-p02fail15`, `o-p02fail27` become `match` or "error position differs" only; nothing else changes), the probe (whole equals split), W3C 2585/2585 for both builds, the W3C-in-pieces test (the 139 F02-2 documents), the Python suite, and Expat's C tests (38 expected failures). The error position (1:0) is **not** part of this fix; it belongs to #171/#122.

## Limitations

- Only the native DLL's document path is planned; external entities and DTD subsets are left as they are.
- The plan is not yet checked against the W3C-in-pieces test (about 25 minutes per build, because of F05-1).
