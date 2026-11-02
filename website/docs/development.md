# Development

[← website README](../README.md)

## Tools

| Tool | Version used | For |
|---|---|---|
| .NET SDK | 10.0.300 | API, worker, tests |
| Node.js / npm | 24.19 / 11.17 | frontend |
| EiffelStudio | 25.12 (`msc_vc140`) | building `xpact.dll` |
| Visual Studio C++ tools | VS 18 (MSVC) | building `xpact.dll` |
| Python | 3.11+ (3.15 used) | `scripts/export-data.py` |

## Everyday work

```powershell
.\website\scripts\build-dll.ps1     # once, or after a parser change
.\website\scripts\dev.ps1           # API on :5080 (new window) + Vite on :5173 with hot reload
```

Vite forwards `/api` to the API, so the browser sees one origin, as in production.

## Change …

| What | Where |
|---|---|
| a page | `frontend/src/pages/*.tsx` |
| colours, spacing, dark mode | `frontend/src/styles/tokens.css` (tokens only) |
| an example document | `frontend/src/data/samples.ts` |
| links (repo, issues, board) | `frontend/src/data/site.ts` |
| a limit | `backend/src/Xpact.Api/appsettings.json` |
| what the worker reports | `backend/src/Xpact.Worker/` and `Xpact.Contracts/ValidationResult.cs`, then `frontend/src/api/types.ts` |
| the conformance / benchmark numbers | add the new report, point `scripts/export-data.py` at it, run it |

## Check before committing

```powershell
.\website\scripts\test.ps1      # backend end-to-end tests + frontend type check and build
```

Record the result in [testing.md](testing.md).

## Publish

```powershell
.\website\scripts\publish.ps1
.\website\dist\Xpact.Api.exe --urls http://localhost:5099
```

> Port 8080 is often taken: on the student PC, Apache `httpd` listens there and answers instead of the site.
