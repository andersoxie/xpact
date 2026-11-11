# Architecture

[← website README](../README.md)

The website follows the five components of [guide.txt](../guide.txt). The rule from the guide is kept throughout: **XPact stays independent**. The website is one client of the parser, and nothing in the parser depends on it.

## 1. Components

| # | Component | Technology | Folder | Responsibility |
|---|---|---|---|---|
| 1 | Frontend | React 19 + TypeScript, Vite, plain CSS with tokens | `frontend/` | Pages, upload, editor, results, charts |
| 2 | Backend | ASP.NET Core (.NET 10), minimal APIs | `backend/src/Xpact.Api/` | Upload checks, limits, REST API, serving the site |
| 3 | Worker | .NET console process, P/Invoke | `backend/src/Xpact.Worker/` | Parse one document in isolation |
| 4 | Parser | Eiffel compiled to C | `xpact.dll`, `xpact_assertions.dll` | The actual XML parsing |
| 5 | Results | JSON responses, logs, exported report data | `data/`, API logs | What the site shows |

## 2. One request, step by step

1. **Frontend:** the browser sends the document. An uploaded file goes as `multipart/form-data` with its **original bytes**, so UTF-16 or ISO-8859-1 files reach the parser unchanged. Pasted text goes as JSON (UTF-8).
2. **API:**
   - checks the rate limit (30 / min per IP), the size (≤ 10 MB), the build name and the chunk size
   - at most 2 workers per IP at once (more → 429), then waits for a free worker slot (max 4 at once) for at most 15 s, in a queue of at most 32 (else 503)
3. **API → worker:**
   - starts `Xpact.Worker.exe` in an empty working folder, at below-normal priority, inside a **Windows Job Object** (512 MB memory cap; the job kills the process when its handle closes)
   - writes the document to the worker's stdin
4. **Worker → parser:**
   - loads the chosen DLL and calls `XML_ParserCreate(NULL)`, then sets the start, end, character-data, comment and PI handlers
   - calls `XML_Parse`: once (whole), or once per piece (chunks)
   - on an error, it reads `XML_GetErrorCode`, `XML_ErrorString` and the line, column and byte index
5. **Worker → API:** one JSON line on stdout (see [api.md](api.md#the-result)).
6. **API:** adds the total time and returns the JSON. If the worker exits without a result, the verdict is `crashed`; if it is still running after 10 s, it is killed and the verdict is `timeout`.
7. **Frontend:** shows the verdict, the error position (and marks that line in the editor), the timings and the events.

## 3. Why a separate worker process?

- **Crash isolation.** A failed Eiffel contract in the assertions build ends the process (it cannot travel back through C). In-process, that would take the web server down. The same pattern is used by the repository's C# DLL tests (`tests/dotnet/XpactDllTests`).
- **Resource limits.** Memory and time can be capped per document with a Job Object and a kill.
- **Clean state.** Every document gets a fresh parser and a fresh process, so no state leaks between visitors.

The cost is about 100 ms of process start-up per request, which is fine for an interactive tool.

## 4. Where the numbers come from

The Benchmarks page never hard-codes results. [`scripts/export-data.py`](../scripts/export-data.py) reads:

| Output | Source in the repository |
|---|---|
| `data/conformance.json` | `reports/latest-2026-10-28/w3c/summary.json`, `…/dll-entity-lane/summary.json` |
| `data/benchmarks.json` | `docs/benchmarks.md` (first results table) |
| `data/comparison.json` | `student/results/G03-comparison/README.md` |
| `data/testing.json` | `student/results/AlotOfTests-2026-10-28/` (test logs and READMEs), `reports/issue-0165/logs/test2/` |

Each file keeps a link to its source report; the page shows that link.

## 5. Deployment (not done yet)

`scripts/publish.ps1` produces `website/dist/`: one folder with the API, the worker, the DLLs, the data and the built site in `wwwroot/`. As the guide suggests, a **Windows VM** is the simplest first host, because the DLL needs the Windows x64 build. Azure App Service (Windows) should also work, but is not tested. See [roadmap.md](roadmap.md).
