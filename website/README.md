# XPact website

A website where anyone can **upload or paste an XML document and see what XPact does with it**: accepted or rejected, the error with its line and column, and the parser events. It also explains the parser, shows the W3C conformance and benchmark results, and links to the project.

> 🟢 **Status (2026-11-11):** working locally, `scripts\test.ps1` passes (42 / 42 backend tests + frontend build, `incremental-test` @ `af7eaf1`); Lighthouse 100, ZAP 0 medium, W3C HTML 0 errors ([#286](../reports/issue-0286/report.md)). Docker image `ghcr.io/andersoxie/xpact-website:website-2026-11-11-1` built from release `website-2026-11-11-1` (PR #315). 🟡 Under a 40 MB memory cap the container worker can end in a stack overflow ([#316](https://github.com/andersoxie/xpact/issues/316)). ⬜ Not deployed online yet (HTTPS, domain: [#210](https://github.com/andersoxie/xpact/issues/210)).
>
> Earlier: 20 / 20 backend tests and browser QA of all 5 pages with 0 console errors, 2026-11-06, final parser `45d2f53`.

---

## 1. Quick start

You need: Windows x64, .NET SDK 10, Node.js 20+, and the XPact build tools (EiffelStudio + MSVC, the same as for the parser).

```powershell
# from the repository root
.\website\scripts\build-dll.ps1        # build xpact.dll + xpact_assertions.dll, copy them into the website
.\website\scripts\publish.ps1          # build the site, the API and the worker into website\dist
.\website\dist\Xpact.Api.exe --urls http://localhost:5099
```

Open **http://localhost:5099** and press **Validate**.

| I want to … | Run |
|---|---|
| work on the site with hot reload | `.\website\scripts\dev.ps1` → http://localhost:5173 |
| run every check | `.\website\scripts\test.ps1` |
| refresh the numbers from the reports | `python website\scripts\export-data.py` |
| reuse DLLs that are already built | `.\website\scripts\build-dll.ps1 -SkipBuild` |

---

## 2. How it works

```
Browser (React + TypeScript)
   │  POST /api/validate  (file, pasted text or raw XML)
   ▼
Xpact.Api  (ASP.NET Core)      size limit · rate limit · picks the build
   │  starts one process per document, document on stdin
   ▼
Xpact.Worker                   Job Object: 512 MB cap, killed after 10 s
   │  P/Invoke, Expat C API
   ▼
xpact.dll / xpact_assertions.dll   the XPact parser (Eiffel compiled to C)
```

A crash inside the parser ends only that worker; the server reports `crashed` and keeps running. External entities are never loaded.

---

## 3. Folders

| Folder | What is in it |
|---|---|
| [`frontend/`](frontend/) | React + TypeScript site (Vite). Pages: Home, Validator, Documentation, Benchmarks, Project |
| [`backend/src/Xpact.Api/`](backend/src/Xpact.Api/) | REST API, limits, worker management, serves the built site |
| [`backend/src/Xpact.Worker/`](backend/src/Xpact.Worker/) | Isolated process that calls `xpact.dll` and prints one JSON result |
| [`backend/src/Xpact.Contracts/`](backend/src/Xpact.Contracts/) | The JSON result shared by the worker and the API |
| [`backend/tests/`](backend/tests/) | End-to-end tests through the real worker and DLL |
| [`backend/requests/`](backend/requests/) | `.http` file and Postman collection |
| [`data/`](data/) | Conformance, benchmark, comparison and testing numbers, exported from `reports/` and `student/results/` |
| [`scripts/`](scripts/) | Build, run, test, publish, export |
| [`docs/`](docs/) | Architecture, API, security, development, Docker, testing, roadmap |
| [`guide.txt`](guide.txt) | The original design guide this site follows |

---

## 4. More detail

| Document | For |
|---|---|
| [docs/architecture.md](docs/architecture.md) | how the parts fit together, and why |
| [docs/api.md](docs/api.md) | every endpoint, field and error |
| [docs/security.md](docs/security.md) | limits, isolation, what was tested |
| [docs/development.md](docs/development.md) | running, changing and publishing the site |
| [docs/docker.md](docs/docker.md) | the Windows Docker image: `docker pull ghcr.io/andersoxie/xpact-website`, build, run, settings |
| [docs/testing.md](docs/testing.md) | test record: revision, configuration, commands, results |
| [docs/roadmap.md](docs/roadmap.md) | the guide's 7 phases, with ✅ / ⬜ |
| [#211](https://github.com/andersoxie/xpact/issues/211) · [report](../reports/issue-0211/report.md) | the parser problem found while building the site (nested entity expansion) |
| [#210](https://github.com/andersoxie/xpact/issues/210) · [report](../reports/issue-0210/report.md) | the issue and report for the website itself |
