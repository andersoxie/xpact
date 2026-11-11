# Running the website in Docker

[← documentation](README.md) · [Dockerfile](../Dockerfile) · issue [#233](https://github.com/andersoxie/xpact/issues/233)

## Quick start: pull the ready image

The image is built by GitHub Actions ([`website-docker.yml`](../../.github/workflows/website-docker.yml)) on Windows Server 2022 and published as **`ghcr.io/andersoxie/xpact-website`**. On a Windows host with Docker in **Windows containers** mode (Windows Server 2022, or Windows 10/11 Pro):

```powershell
docker pull ghcr.io/andersoxie/xpact-website:latest
docker run -d --name xpact -p 80:8080 --memory 4g --restart unless-stopped ghcr.io/andersoxie/xpact-website:latest
```

Open `http://<server>/`. For HTTPS, put IIS or another reverse proxy in front and set `Xpact__KnownProxies__0` ([Settings](#settings)).

| Tag | Content |
|---|---|
| `latest` | the newest website build |
| `website-2026-11-09-3` | `incremental-test` @ `c9f74cd`: old one-line footer credit removed; same DLLs and results ([release](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-09-3)) |
| `website-2026-11-09-2` | `incremental-test` @ `f9c9e97`: footer credit, plain result lines; same DLLs and results ([release](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-09-2)) |
| `website-2026-11-09` | `incremental-test` @ `307744b`, test results of 2026-11-08 ([release](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-09)) |

> ✅ **Tested in CI** (2026-11-09, [run 42541400409](https://github.com/andersoxie/xpact/actions/runs/42541400409)): the image builds on `windows-2022`, `/api/health` answers, both builds report `"available": true`, `<root/>junk` → `rejected` code 9, `<a x="1">hi</a>` → `accepted`, the home page loads.
> ⬜ **Not tested yet:** a Windows Server 2025 host (needs `--build-arg WINDOWS_TAG=ltsc2025` and a rebuild), the memory cap inside the container, a run behind a reverse proxy.

**New website version:** build the DLLs and the site on a PC with EiffelStudio (`build-dll.ps1`, `publish.ps1`), zip `website\dist` as `xpact-website-dist.zip`, attach it to a new GitHub release, set `WEBSITE_RELEASE` in the workflow to the new tag and push to `incremental-test`.

## Overview

| | |
|---|---|
| **What is in the image** | `Xpact.Api.exe`, `Xpact.Worker.exe`, `native/xpact.dll`, `native/xpact_assertions.dll`, `data/*.json`, `wwwroot/` (the React site): the `website/dist` folder from [`publish.ps1`](../scripts/publish.ps1) |
| **Base image** | `mcr.microsoft.com/dotnet/aspnet:10.0-windowsservercore-ltsc2022` (ASP.NET Core 10 on Windows Server Core) |
| **Port** | `8080` inside the container |
| **User** | `ContainerUser` (not an administrator) |
| **Health check** | `GET /api/health` every 30 s |

## Why a Windows container

| Fact | Consequence |
|---|---|
| `xpact.dll` is a Windows DLL built with Eiffel and MSVC (`msc_vc140`) | A Linux image cannot load it without a port |
| The worker caps memory with a Windows Job Object | Needs Windows |
| The DLLs import only `KERNEL32`, `WS2_32` and `SHELL32` (`dumpbin /dependents`); the C runtime is linked in | No VC++ runtime to install; Server Core has `SHELL32`, Nano Server may not, so Server Core is used |
| The DLLs need Eiffel + MSVC to build | They are built on the host and copied in; the image is built from `website/dist`, not from source |

## Build and run

On a Windows host with Docker in **Windows containers** mode:

```powershell
.\website\scripts\build-dll.ps1          # XPact DLLs into website\backend\native
.\website\scripts\publish.ps1            # everything into website\dist
docker build -f website\Dockerfile -t xpact-website website\dist
docker run -d --name xpact -p 5099:8080 --memory 4g xpact-website
```

Then open `http://localhost:5099`.

| Option | Why |
|---|---|
| `--build-arg WINDOWS_TAG=ltsc2025` | The base image must match the host's Windows version: `ltsc2022` = Windows Server 2022, `ltsc2025` = Windows Server 2025 |
| `--memory 4g` | Up to 4 workers × 512 MB (`MaxConcurrentWorkers` × `WorkerMemoryMb`) plus the API. With Hyper-V isolation the default can be much lower |
| `-p 5099:8080` | Any free host port; on the student PC Apache already uses 8080 |

## Settings

Every setting in [`appsettings.json`](../backend/src/Xpact.Api/appsettings.json) can be set with an environment variable (`__` between levels):

```powershell
docker run -d -p 5099:8080 `
  -e Xpact__RequestsPerMinute=60 `
  -e Xpact__TimeoutSeconds=10 `
  -e Xpact__KnownProxies__0=10.0.0.5 `
  xpact-website
```

Behind a reverse proxy (IIS, nginx) on another address, add that address to `Xpact__KnownProxies__0`, or the rate limit counts all visitors as one ([security.md](security.md)).

## Check after the first run

Checked by the `Website Docker image` workflow on every PR that touches the Dockerfile or the workflow (#284). First full pass: 2026-11-11, [run 42928039862](https://github.com/andersoxie/xpact/actions/runs/42928039862) (image `website-2026-11-09-4`, windows-2022): both builds available, `<root/>junk` rejected with code 9, `healthy`, and a 40 MB cap stops a nested-entity document (`crashed`) while the site keeps serving.

- [x] `docker build` succeeds (base image tag matches the host)
- [x] `docker ps` shows the container as `healthy`
- [x] `curl.exe http://localhost:5099/api/info` shows both builds `"available":true`
- [x] `curl.exe -X POST http://localhost:5099/api/validate -H "Content-Type: application/xml" --data "<root/>junk"` gives `rejected`, code 9 (the worker and DLL run inside the container)
- [x] The memory cap still works inside the container (the worker's Job Object is nested in the container's own job)
