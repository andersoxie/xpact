# DLL tests through the C API, 2026-10-22

Task [#37](https://github.com/andersoxie/xpact/issues/37) · program [`tests/dotnet/XpactDllTests/`](../../../tests/dotnet/XpactDllTests/README.md) · report [`reports/issue-0037/`](../../../reports/issue-0037/report.md)

## At a glance

3,360 cases: every input × 6 callback sets × every chunking (whole, split at every byte, byte by byte).

| DLL | Assertions | ✅ pass | ❌ fail | 💥 crash | ⏱ timeout |
|---|---|---:|---:|---:|---:|
| `xpact_assertions.dll` (current `student-Mass`) | on | 637 | 1,394 | 1,329 | 0 |
| `xpact_assertions.dll` + B03 fix (#12) | on | 928 | 1,760 | 672 | 0 |
| `xpact.dll` (current `student-Mass`) | off | 1,200 | 2,160 | 0 | 0 |

What the runs show (each problem is its own issue; "confirmed" = shown by these runs):

| | Problem | Status | Issue |
|---|---|---|---|
| 🔴 | With a **start handler**, `<root>` and `<root><child></root>` are **accepted**, and with start+end handlers the end event of a valid document never comes (C01 shortcut) | confirmed, all DLLs | [#38](https://github.com/andersoxie/xpact/issues/38) |
| 🔴 | **Invalid UTF-8 is accepted** in text, attributes, names, comments, PIs and CDATA | confirmed, all DLLs | [#39](https://github.com/andersoxie/xpact/issues/39) |
| 🔴 | A non-final `XML_Parse` call whose data **ends with `<`** crashes the assertions DLL | trigger confirmed; cause in the code suspected | [#40](https://github.com/andersoxie/xpact/issues/40) |
| 🟠 | Every input with `/>` crashes the assertions DLL: B03 | **confirmed** with a B03-fixed DLL | [#3](https://github.com/andersoxie/xpact/issues/3) |
| 🟠 | A CR with no callbacks crashes the assertions DLL: #28 through the DLL | confirmed | [#28](https://github.com/andersoxie/xpact/issues/28) |
| ⚪ | Error codes differ from libexpat's for `<root>` (5, not 3) and `<root/>junk` (4, not 9) | **not judged**: the libexpat codes here are reference values, not an Expat run | G03 |

---

## Revision

| | |
|---|---|
| Source | `student-Mass` @ `42d6b40` (parser unchanged by the later commits `97e7344`, which the runs print as "Commit") |
| Program | `tests/dotnet/XpactDllTests/` as committed with this folder |
| `xpact_assertions.dll` | built 2026-10-22 00:44 by the A02 rerun, `scripts\build_native_eiffel.ps1 -BuildTier Assertions`; SHA-256 `8cc96794…e88bb` |
| `xpact.dll` | built 2026-10-21 16:25, `-BuildTier Production`; SHA-256 `62a2706b…92bc2` |
| B03-fixed DLL | `42d6b40` + the one-line B03 change from `d9f662f` ([`b03-fix.diff`](assertions-b03fix/b03-fix.diff)), built in a separate worktree `C:\xpact\xpact-b03-check` ([`build.log`](assertions-b03fix/build.log)); SHA-256 `38c2b2c7…3679a`. **Not committed:** a test build only |

Full hashes are at the top of each `summary.txt`.

## Configuration

Windows 11, Windows PowerShell 5.1, .NET SDK 10.0.300 (x64), EiffelStudio
25.12.9.8922 with `ISE_C_COMPILER=msc_vc140`, MSVC 14.51.
`XML_ParserCreate(NULL)`, no namespaces. Each child process runs cases one
after the other on the thread that loaded the DLL; 8 child chains side by
side (`--jobs 8`); timeout 30 s, a TIMEOUT case is retried alone.

## Commands and results

```powershell
dotnet build tests\dotnet\XpactDllTests -c Release
$t = "build\dotnet\XpactDllTests\bin\Release\net10.0\XpactDllTests.exe"
& $t --out build\dotnet-dll-tests\assertions-2026-10-22                                   # exit 1, 200 s
& $t --dll C:\xpact\xpact-b03-check\build\native-eiffel-b03\xpact_assertions.dll `
     --out build\dotnet-dll-tests\assertions-b03fix-2026-10-22                            # exit 1, 215 s
& $t --dll build\native-eiffel\xpact.dll --out build\dotnet-dll-tests\production-2026-10-22  # exit 1, 0.3 s
```

| Run | Summary | Every case | Crash outputs |
|---|---|---|---|
| assertions | [summary.txt](assertions/summary.txt) | [results.tsv](assertions/results.tsv) | [crash-examples/](assertions/crash-examples/) |
| assertions + B03 fix | [summary.txt](assertions-b03fix/summary.txt) | [results.tsv](assertions-b03fix/results.tsv) | [crash-examples/](assertions-b03fix/crash-examples/) |
| assertions off | [summary.txt](production/summary.txt) | [results.tsv](production/results.tsv) | none |

`crash-examples/` keeps one complete crash output per kind of crash (all
1,329 are 3 MB and differ only in the case). The others are in
`build\dotnet-dll-tests\<run>\crashes\` on this PC (not in git).

**How to read a `summary.txt`:** section 2 has one line per input with the
whole-document result for each callback set (`ok`, `ACCEPT!`/`REJECT!` =
wrong verdict, `EVENTS!` = wrong events, `CRASH`) and how many chunked runs
went wrong. Section 3 groups the crashes by their Eiffel trace.

### Repeatability ✅

The first full run (00:55, before two fixes in the program itself) and the
committed run (01:50) on the same `xpact_assertions.dll` agree on the result
of **all 3,360 cases**; the same for `xpact.dll`. Not repeatable: whether a
crash prints an Eiffel trace. 17 crashes had a trace in one run and none in
the other. So crash counts *by trace* move a little between runs (e.g. 811
or 815 without a trace); conclusions below use only whether a case crashes.

## Parser events

Every event of every case is in the `events` column of `results.tsv`,
bytes escaped as `\xHH`. Examples from `xpact.dll`:

| Case | Result | Events |
|---|---|---|
| `c02-valid-pair/start+end/whole` | ACCEPT | `start:root` (no `end:root`) |
| `c02-valid-pair/start+end/bytes` | ACCEPT | `start:root` · `end:root` |
| `c02-incomplete/start+end/whole` | **ACCEPT** | `start:root` |
| `c02-incomplete/start+end/bytes` | REJECT 5 | `start:root` |
| `c02-mismatched/start+end/bytes` | REJECT 7 | `start:root` · `start:child` |
| `cr-crlf/chardata/whole` | ACCEPT | `text:\x0a` (CR LF became LF ✅) |
| `c02-valid-pair/default/whole` | ACCEPT | `default:<root>` · `default:</root>` |

## Findings

### 1. 🔴 Start handler: the rest of the document is not parsed (C01) · [#38](https://github.com/andersoxie/xpact/issues/38)

**Confirmed** on all three DLLs. When the **final** `XML_Parse` call
completes the first start tag and a start handler is set, xpact reports that
start event and returns OK without parsing the rest:

- 24 wrong ACCEPTs: `<root>` and `<root><child></root>` with `start` or
  `start+end`, whole and split before the end of the first start tag
  (`xpact.dll`, `results.tsv` column `verdict`);
- 30 accepted documents with the end event missing (`<root></root>`,
  `<root>hi</root>`, CR and é in text, comment, PI, CDATA, all `start+end`).

When the start tag is complete *before* the final call (byte by byte, or a
later split), the result is right. Without a start handler, right too.

### 2. 🔴 Invalid UTF-8 accepted almost everywhere · [#39](https://github.com/andersoxie/xpact/issues/39)

**Confirmed** on `xpact.dll`: 2,106 of 2,148 cases with a bad sequence are
accepted. The only ones rejected are `C3 28` in an element name (42 cases),
because `(` is not a name character, not because the UTF-8 is checked. The
control `C3 A9` is accepted everywhere, as it should be. On the assertions
DLLs the same, except where the case crashes first.

### 3. 🔴 Chunk that ends with `<` crashes the assertions DLL · [#40](https://github.com/andersoxie/xpact/issues/40)

**Confirmed** trigger, on both assertions DLLs: a non-final `XML_Parse` call
whose last byte is `<` (`split@1` of any input; any split right before an
end tag, comment, PI or CDATA; every byte-by-byte run). With the B03 fix,
**512** cases crash with

```
XP_PARSER  find_markup_declaration_end @4  index_in_bounds: Loop invariant violated.
… markup_prefix_end … incomplete_markup_prefix_start … XP_NATIVE_PARSER should_defer_reparse_callbacks
```

and **132** more with the same trigger crash with **no** trace. All 672
crashes of the B03-fixed DLL are accounted for: 644 have a `<` at the end of
a non-final chunk (512 with this trace, 132 without), 28 are CR inputs with
no callbacks (finding 5), none is anything else (split points in
[`assertions-b03fix/results.tsv`](assertions-b03fix/results.tsv)).
That the 132 without a trace have the same cause is **suspected**, not
shown: the trace may be lost the way #13 describes. `xpact.dll` does not
crash on any of them, so the loop invariant is what fails; whether the
parser's result is wrong as well is **unknown**.

### 4. 🟠 B03 reaches the DLL · [#3](https://github.com/andersoxie/xpact/issues/3)

On the current `xpact_assertions.dll` every input with `/>` crashes, mostly
with **no** trace: `<root/>` itself, `<root/>junk`, CR after the root, every
attribute and element-name case (84 of the 86 whole-document crashes; the
other 2 are CR cases, finding 5). A
few show `XP_NATIVE_PARSER direct_start_tag_attributes … a_end_index - i:
Non-decreasing loop variant`, the B03 routine. With **only** the B03 change
applied, **none** of those whole-document crashes is left (crashes 1,329 →
672; without a trace 811 → 158). **Confirmed:** B03 is the cause of those
crashes. The C smoke test `xpact_assertions_eiffel_dll_smoke.exe` still
crashes with `0xC0000028` with the B03 fix ([`build.log`](assertions-b03fix/build.log)),
so B03 does **not** explain K3 (draft 07) on its own.

### 5. 🟠 The CR bug through the DLL · [#28](https://github.com/andersoxie/xpact/issues/28)

With no callbacks set, CR LF, a lone CR, a CR after the root and a CR in an
attribute crash both assertions DLLs; with the B03 fix the trace shows
`XP_PARSER normalized_input @8 a_input.count - i + 1: Non-decreasing loop
variant` (#28). With any callback set, the same inputs pass, as #28 predicts.

### 6. ⚪ Error codes (not judged)

| Input | libexpat reference | `xpact.dll` |
|---|---|---|
| empty | 3 no element found | 3 ✅ |
| `<root>` | 3 no element found | 5 unclosed token |
| `<root><child></root>` | 7 mismatched tag | 7 ✅ |
| `<root/>junk` | 9 junk after document element | 4 invalid token |

The reference codes come from libexpat's documented behaviour, **not** from
running Expat 2.8.1. Check them in G03 before reporting a difference.

## Known failures of the program itself

None open. Two were found and fixed before these runs (see the
[report](../../../reports/issue-0037/report.md#two-problems-in-the-program-itself-found-and-fixed-before-committing)):
cut-off crash traces, and crashes reported as TIMEOUT. The TIMEOUT recheck
from the first attempt is in [`timeout-recheck-2026-10-22-0134.txt`](timeout-recheck-2026-10-22-0134.txt).

## Limitations: what these runs do not prove

- Only 4 handlers (start, end, character data, default); no `XML_ParseBuffer`,
  `XML_StopParser`, `XML_ResumeParser`, namespaces, DTDs or entities.
- One-byte and two-chunk splits only; no random chunk sizes.
- A passing case checks the verdict, start/end events and joined character
  data, not positions, attributes or default-handler text.
- Error codes and positions are recorded but not judged.
- Every run is on one PC with one compiler; the B03-fixed DLL is a local build.
