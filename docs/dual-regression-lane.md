# Dual regression lane

This lane runs small functional regressions with our parser and the pinned
Finnian Xpact-core implementation, **whole and chunked, with event traces**. It
is the step 4 checkpoint of the dual-implementation plan: elements, attributes,
text, malformed input and chunked input through one adapter per parser.

It reuses the build infrastructure of the [dual catalog](dual-catalog-lane.md)
and [dual W3C](dual-w3c-lane.md) lanes (`build_implementations.py`, profile
`regression`).

As of 13 November 2026 this is an implemented Windows EiffelStudio/MSVC lane.
Its recorded parser results below are dated student-PC measurements; the new
Gobo qualification does not rerun this lane. The main Jenkins dual stage runs
catalog and W3C campaigns, so this regression command remains a separate check.

## Run it

Use the prerequisites in [Pinned implementation builds](implementation-builds.md)
(Python 3.11 or newer on `PATH` as `python`). From the repository root:

```powershell
.\scripts\run_dual_regression.ps1            # -Offline when the pinned core checkout is cached
```

Each invocation creates a new `build/dual-regression/<run-id>/` and prints it.
It builds four executables (both parsers, assertions on and off, finalized),
runs every case, and writes:

| File | Content |
|---|---|
| `summary.md` | results per build and group, the lifecycle table, every case that is not PASS with its error |
| `cases.tsv` | one row per build, case and chunking: input, expected and observed verdict, expected and observed events, error |
| `lifecycle.tsv` | one row per build and lifecycle step |
| `fixtures/` | the byte-exact inputs |
| `run.json` | status, build errors, executables and their SHA-256 |

Exit code: 0 = every xpact case passed; 1 = xpact failures; 2 = the run could not
complete (for example xpact did not build). Xpact-core results are reported, not
judged, as in the other lanes. One engine's build failure does not hide the
other engine's results.

## Cases and chunkings

61 inputs. Expected results are written in `scripts/run_dual_regression.py`,
independently of both parsers; agreement between the parsers is not counted.

| Group | Inputs | From |
|---|---|---|
| `c02` | `<root/>`, `<root></root>`, `<root>hi</root>`, empty, `<root>`, `<root><child></root>`, `<root/>junk` | C02, C# DLL tests (#37) |
| `cr` | CR LF, lone CR, CR after the root, CR in an attribute | #28 |
| `basic` | nested elements, two attributes, duplicate and unquoted attribute, entities, character references, whitespace, undefined entity | step 4 checkpoint |
| `utf8` | 6 malformed sequences and `é`, each in text, attribute, name, comment, PI, CDATA | C10 (part), #121 |

Every input runs as `whole`, `split@k` for every k, `bytes` (one non-final call
per byte, then an empty final call, as Expat callers often finish) and
`bytes-final` (the last byte final, no empty call): 910 runs per build.

Accepted documents must give exactly the expected `start:`/`end:`/`text:`
events; adjacent character data is joined because the API may divide it.
Rejected documents are judged on the verdict only (positions and error codes
are compared with Expat in the C# DLL tests, #121).

`--lifecycle` runs ten steps on **one reused parser**: valid, mismatched, valid,
incomplete, valid, partial then final, malformed UTF-8, valid, empty, valid.

## Adapters

| | xpact | Xpact-core |
|---|---|---|
| Parser | `XP_NATIVE_PARSER` (the incremental parser behind the DLL) | `XT_XML_PARSER_BASE` raw events |
| Chunks | `parse (chunk, is_final)` unchanged | each chunk copied into its own `XT_UTF_8_CODEC`, kept until the run ends |
| Events | the handler's event log (`start:`, `end:`, `text:`) | `on_element_start`, `on_element_end`, `on_content` |
| Reuse | `reset` before every run | `reset` before every run; the caller's GC state restored |

## Results on the student PC, 26 October 2026

EiffelStudio 25.12.9.8922 Standard, MSVC 19.51, Windows 11, `student-Mass` @ `36509b8`.
Rerun on 28 October on the integrated branch (`main` #150 with #146, #148 and #151,
@ `2e6de7a`): every result below is the same, lifecycle included.

| Build | Runs | PASS | Wrong verdict | Wrong events | Crash | Timeout |
|---|---:|---:|---:|---:|---:|---:|
| xpact, assertions on | 910 | 910 | 0 | 0 | 0 | 0 |
| xpact, assertions off | 910 | 910 | 0 | 0 | 0 | 0 |
| Xpact-core, assertions on | 910 | 887 | 23 | 0 | 0 | 0 |
| Xpact-core, assertions off | 910 | 887 | 23 | 0 | 0 | 0 |

All ten lifecycle steps give the expected verdict for both parsers.

Xpact-core's 23 wrong verdicts are two observed behaviours:

1. **An empty final call after byte-by-byte input** gives `No element found`
   (error 3) for every valid document without a CR (14 runs, `bytes`). The same
   documents pass when the last byte itself is final (`bytes-final`). Expat 2.8.1
   accepts the empty final call in the C# DLL tests (#121).
2. **A chunk that is only a CR byte** is rejected with status `Status_error` but
   error code 0 (`Error_none`) (8 runs: the four `cr-*` inputs in `bytes` and
   `bytes-final`, and `cr-last-byte` split after `<r/>`). Example: `<r/>`
   non-final, then `\r` final. When the CR is itself the final chunk
   (`cr-last-byte`, `bytes-final`) the result is `No element found` (1 run).

**Suspected cause (code reading, not traced):** in `XT_XML_PARSER_BASE.parse`,
`Result` starts as 0, which is `Status_error`, and is only set by `parse_buffer`
when the chunk produced UTF-8 bytes (`utf_8_copied_count > 0`). An empty chunk,
and a lone CR the codec holds back for a possible LF, produce none, so `parse`
returns its default without parsing the buffered remainder. This contradicts its
postcondition `error_code_set_on_error`, which is not checked because the core
library's own assertions are off. These are observations; this lane does not
change the pinned parser.

## Does the lane catch real regressions?

Each check below temporarily changed `src/` in a local build, ran the lane, and
restored `src/` (`git diff src/` empty afterwards).

| Mutation | Result |
|---|---|
| CR not normalized to LF (#28 undone) | ✅ caught: 21 `WRONG-EVENTS` for xpact (`text:\x0d`), exit 1 |
| #40 fix undone (`find_markup_declaration_end` start index) | ❌ not caught in that recorded finalized build: `index_in_bounds` was absent in the inspected `F_code`, and no visible outcome changed. The workbench Eiffel suite catches it (#128). This observation does not establish a rule for every finalized build |
| One malformed-UTF-8 check skipped in `normalized_input` | not visible: other checks on the native path still reject the input, so no verdict changed |

Both regression assertion targets explicitly request loop assertions. Separate
13 November finalized probes detect loop invariants and variants with
EiffelStudio 25.02 and Gobo 26.11.12; see [assertion qualification](gobo-assertions.md).
The older missed mutation therefore needs investigation in its exact build and
call path rather than a blanket conclusion about finalization. Keep the workbench
assertion matrix as additional coverage; this documentation review did not rerun
the mutation or the regression campaign.

## Not covered

Namespaces, DTDs, external entities, error codes and positions (see #121), the
default handler, suspension and resume, native DLLs and .NET.

## Verification

```powershell
python -m unittest discover -s tests/python -p test_dual_regression.py -v
```

14 tests: escaping identical to the Eiffel trace, unique cases, expectations,
chunkings, judging, trace parsing, crash isolation per chunking, and reports.
