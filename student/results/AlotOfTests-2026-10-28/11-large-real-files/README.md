# 11 · Large files

> **Question:** Is xpact fast and stable on big, realistic files?
> **Status:** ✅ run (2026-10-28) · ✅ stable, the same events as Expat on every file it accepts · 🔴 too slow when streamed, and files over 10 MB are rejected (F05-1) · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

[run.py](run.py) generates four kinds of realistic files (in `inputs/`, not for git) at 1, 5, 9 and 20 MB:

| Shape | Looks like |
|---|---|
| `records` | OpenStreetMap: many small elements with many attributes |
| `text` | Wikipedia: long mixed text with markup, entities, CDATA, comments |
| `ns` | Atom/SOAP: namespaces on every element (namespace parser) |
| `nested` | configuration files: 5–40 levels deep, short text |

Each file runs four ways, each in a fresh process with a 300 s limit:
- **whole** or **64 KB chunks** (how applications stream a file);
- **no handlers** (the parser alone) or **all handlers** (the event stream is hashed and compared with Expat).

| Result | |
|---|---|
| ✅ Crashes | **0** |
| ✅ Events | **identical to Expat** (same hash) in every run where xpact accepted the file |
| 🔴 Over 10 MB | **rejected** ("out of memory"): the 10 MiB input limit, whole and streamed |
| 🔴 Streamed (64 KB chunks) | 9 MB: **4–5 minutes** or timeout; Expat under 1 s |
| 🟡 Whole document | 20–100 × slower than Expat |

## Times (seconds), handlers on

| File | xpact whole | xpact 64 KB chunks | Expat whole | Expat 64 KB chunks |
|---|---:|---:|---:|---:|
| records 1 MB | 0.51 | 3.6 | 0.04 | 0.04 |
| records 5 MB | 2.6 | **95** | 0.18 | 0.19 |
| records 9 MB | 5.5 | **278** | 0.33 | 0.39 |
| records 20 MB | ❌ REJECT (limit) | ⏱ > 300 | 1.0 | 1.0 |
| ns 1 MB | 1.3 | 10.6 | 0.09 | 0.09 |
| ns 5 MB | 6.8 | **214** | 0.52 | 0.35 |
| ns 9 MB | 9.9 | ⏱ > 300 | 0.96 | 0.74 |
| ns 20 MB | ❌ REJECT (limit) | ⏱ > 300 | 2.1 | 2.2 |
| nested 1 MB | 0.65 | 4.6 | 0.06 | 0.05 |
| nested 5 MB | 3.0 | **102** | 0.28 | 0.35 |
| nested 9 MB | 6.9 | ⏱ > 300 | 0.65 | 0.53 |
| nested 20 MB | ❌ REJECT (limit) | ⏱ > 300 | 1.5 | 1.3 |
| text 1 MB | 0.57 | 3.8 | 0.06 | 0.05 |
| text 5 MB | 2.3 | **84** | 0.29 | 0.26 |
| text 9 MB | 4.6 | ⏱ > 300 (no handlers) · not run (with handlers) ¹ | 0.46 | 0.06 (no handlers) |
| text 20 MB | ❌ REJECT (limit) | not run ¹ | 1.2 | not run ¹ |

¹ Skipped on purpose to save time: the result is already known from the other shapes (timeout or rejected).

**Without handlers** (the parser alone), the picture is the same: records 9 MB whole 2.3 s vs Expat 0.07 s; streamed 224 s vs 0.10 s.

**The streamed time grows with the square of the size:** records 1 → 5 MB is ×26, 5 → 9 MB ×2.9. Expat stays linear. The cause is confirmed in the code (F05-1, [test 5](../05-security-limits/README.md)): every `XML_Parse` call re-parses the whole buffer.

Memory, records 9 MB with handlers: xpact 195 MB, Expat 118 MB (both include the Python harness).

Per run: [logs/large-xpact-all-shapes.tsv](logs/large-xpact-all-shapes.tsv) · console: [logs/run-xpact-all-shapes.txt](logs/run-xpact-all-shapes.txt)

## ⚠ Problem in my own test, fixed

The first `text` files were **broken XML**: the generator cut a paragraph after 50 characters, sometimes in the middle of `&amp;`. Both parsers rightly rejected them ("not well-formed"), so those rows say nothing about xpact. The generator now cuts at whole words; the output was checked with Expat, and the `text` shape was run again: [logs/run-xpact-text.txt](logs/run-xpact-text.txt) (stopped after the first streamed 9 MB run), [logs/run-xpact-text-20mb.txt](logs/run-xpact-text-20mb.txt) (20 MB whole only). The old broken rows are still in `large-xpact-all-shapes.tsv`; ignore the `text-*` lines there.

## Limitations

- Generated files that look like real data, not downloaded real files.
- The timings include the Python ctypes harness; the "no handlers" rows show the parser alone.
- One PC; other tests may have been running at the same time for some rows.

## To do

- [ ] Real downloaded files (an OpenStreetMap extract, a Wikipedia dump) once F05-1 and the 10 MB limit are decided
- [ ] Assertions build
