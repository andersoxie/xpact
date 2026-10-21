# XpactDllTests

Tests the xpact DLL the way a C program uses it: through the Expat C API
(`XML_ParserCreate`, `XML_Parse`, the handler setters, `XML_GetErrorCode`).
Written in C# so cases are easy to add; the calls go straight into the DLL
with P/Invoke, nothing is wrapped or changed on the way.

The Eiffel tests (`tests/xp_test_root.e`) and the W3C runner call the Eiffel
parser directly. They never go through the C bridge, the chunk handling in
`XP_NATIVE_PARSER` or the callback adapter. This program does.

## What it tests

| Group | Task | Inputs | Expected |
|---|---|---|---|
| `c02` | C02 | The guide's first test matrix: `<root/>`, `<root></root>`, `<root>hi</root>`, empty input, `<root>`, `<root><child></root>`, `<root/>junk` | Only the first three are accepted |
| `cr` | #28 | CR LF, lone CR, CR after the root, CR in an attribute | Accepted; character data is a single LF |
| `utf8` | C10 (part) | `C3 28`, `C0 AF`, `ED A0 80`, `F4 90 80 80` in text, attribute, element name, comment, PI and CDATA; plus valid `C3 A9` (é) as a control | Bad sequences rejected; é accepted |

Every input runs with each callback set from C02 (`none`, `start`, `end`,
`start+end`, `chardata`, `default`) and each chunking from C03:

- `whole`: one final `XML_Parse` call;
- `split@k`: bytes `[0,k)` non-final, then the rest final, for every `k`;
- `bytes`: one non-final call per byte, then an empty final call.

That is 3,360 cases. A case **passes** when the verdict is right (accepted
or rejected) and, for an accepted document, the start/end events and the
joined character data are right. The error code is **not** judged: the
summary lists it next to libexpat's code for the same input, to be confirmed
against Expat 2.8.1 in G03.

## Crashes

An Eiffel contract violation inside the DLL cannot travel back through C, so
the process dies (for example `0xC0000409`). The program therefore never
loads the DLL itself: it starts child copies of itself (`--child`) that run
the cases and report each one on stdout. If a child dies during a case, that
case is a **CRASH**, its output is saved in `crashes\<case number>.txt`, and
a new child continues with the next case. A case that hangs is killed after
`--timeout` seconds (default 30) and counts as **TIMEOUT**.

Windows takes about 5 seconds to clean up a crashed process, so `--jobs`
child processes run side by side (default: number of CPUs, at most 8). When
several crash at once, one sometimes needs longer than the timeout to end:
on 2026-10-22, 11 cases (timeout 10 s, compiler running) and 4 cases
(timeout 30 s, idle) gave TIMEOUT, and every one of them crashed in 3-6 s
when run alone. So at the end of a run, **each TIMEOUT case is retried once
on its own**; the summary lists those cases, and `results.tsv` has the first
result in the `note` column. A case that is still TIMEOUT after the retry is
a real hang.

The crashes do not come with a Windows dialog: an Eiffel exception that
reaches the top of the DLL makes the runtime panic ("main entry point
vanished") and it ends the process with `0xC0000409`. Some crashes print
no Eiffel trace at all; they are reported as just the exit code.

## Build and run

Needs the .NET 10 SDK. `bin` and `obj` go to `build\dotnet\` (ignored by git).

```powershell
dotnet build tests\dotnet\XpactDllTests -c Release
$t = "build\dotnet\XpactDllTests\bin\Release\net10.0\XpactDllTests.exe"

& $t                                     # everything, xpact_assertions.dll
& $t --dll build\native-eiffel\xpact.dll # the assertions-off DLL
& $t --group c02 --chunks whole --verbose
& $t --only c02-incomplete/start --verbose --isolate
& $t --list                              # case ids only
& $t --help
```

The DLL is built by `scripts\build_native_eiffel.ps1 -BuildTier Assertions`
(or `Production` for `xpact.dll`). Record which one you tested: the summary
prints its path, date and SHA-256.

Exit code: 0 = all passed, 1 = at least one FAIL, CRASH or TIMEOUT,
2 = the run could not be done.

## Output

In `build\dotnet-dll-tests\<dll>-<time>\` (or `--out`):

- `summary.txt`: what is printed at the end, explained below;
- `results.tsv`: one row per case: input bytes, verdict, error code, line,
  column, which call failed, every event;
- `crashes\`: the full output of each crashed case.

Sections of the summary:

1. pass/fail/crash per group and chunking;
2. one line per input: the whole-document result for each callback set
   (`ok`, `ACCEPT!`/`REJECT!` = wrong verdict, `EVENTS!` = wrong events,
   `CRASH`), then how many chunked runs went wrong;
3. crash reasons;
4. chunked runs whose verdict or error code differ from the whole document
   (C03: chunking must not change the answer);
5. error codes of rejected documents next to libexpat's;
6. the first 30 failures.

## Adding a case

Add an `InputCase` in `Catalog.Inputs()`: name, group, exact bytes, expected
verdict, libexpat's error code, and for accepted documents the expected
element events and character data (`null` = do not check). Every callback set
and chunking is generated from it.

## Limits

- Only the start, end, character data and default handlers are tested.
- `XML_ParseBuffer`, `XML_StopParser` and namespaces are not used yet.
- All calls run on the thread that loaded the DLL, where `DllMain` started
  the Eiffel runtime.
