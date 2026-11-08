# Running the website in Docker

[← documentation](README.md) · [Dockerfile](../Dockerfile) · issue [#233](https://github.com/andersoxie/xpact/issues/233)

> ⚠️ **Not tested yet.** The student PC (Windows 11 Home) cannot run Windows containers. The image still has to be built and run once on a Windows Server or Windows Pro machine; see [Check after the first run](#check-after-the-first-run).

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

- [ ] `docker build` succeeds (base image tag matches the host)
- [ ] `docker ps` shows the container as `healthy`
- [ ] `curl.exe http://localhost:5099/api/info` shows both builds `"available":true`
- [ ] `curl.exe -X POST http://localhost:5099/api/validate -H "Content-Type: application/xml" --data "<root/>junk"` gives `rejected`, code 9 (the worker and DLL run inside the container)
- [ ] The memory cap still works inside the container (the worker's Job Object is nested in the container's own job)
