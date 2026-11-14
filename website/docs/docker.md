# Running the website in Docker

[← documentation](README.md) · [Dockerfile](../Dockerfile) · issue [#233](https://github.com/andersoxie/xpact/issues/233)

## Quick start: pull the ready image

The image is built by GitHub Actions ([`website-docker.yml`](../../.github/workflows/website-docker.yml)) on Windows Server 2022 and published as **`ghcr.io/andersoxie/xpact-website`**. On a Windows host with Docker in **Windows containers** mode (Windows Server 2022, or Windows 10/11 Pro):

```powershell
docker pull ghcr.io/andersoxie/xpact-website:latest
docker run -d --name xpact -p 80:8080 --memory 4g --restart unless-stopped `
  -e AllowedHosts=xpact.example.com ghcr.io/andersoxie/xpact-website:latest
```

Open `http://<server>/`. ⚠️ **`AllowedHosts` is required** when the site is reached by any name other than `localhost`: without it every request gets **400 Bad Request** (verified 2026-11-14). Use your real domain (several: `a.com;b.com`). For a public site, follow [Hosting on the internet](#hosting-on-the-internet-safely).

| Tag | Content |
|---|---|
| `latest` | the newest website build |
| `website-2026-11-14-3` | `incremental-test` after #383 + worker callback hardening (second-opinion review of the "unsafe" hotspots); same DLLs |
| `website-2026-11-14-2` | `incremental-test` @ `e0c3eab`: SonarQube clean-up of the backend (#371), client address in the log, coverage settings (#370); same DLLs |
| `website-2026-11-14-1` | `incremental-test` @ `9e3cb7a`: security fixes #357–#360 (upload flood, slow clients, DLL search path) |
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

## Hosting on the internet safely

Checklist for a public server (Windows Server with the Containers feature). Background: [security scan 2026-11-14](../../reports/security-scan-2026-11-14/README.md).

| # | Do this | Why |
|---|---|---|
| 1 | Use an image built **after 2026-11-13** (release `website-2026-11-14-3` or newer). Do not use `website-2026-11-12-1` or older | Older images lack the upload-flood, slow-client and DLL-search-path fixes (#357–#360) |
| 2 | `-e AllowedHosts=<your domain>` | Otherwise every visitor gets 400 (host filter, #283) |
| 3 | Serve HTTPS only, through a proxy. Easiest: **Cloudflare Tunnel** (free; `cloudflared` on the host, no inbound port opened, server IP hidden, free DDoS protection). Or IIS + a Let's Encrypt certificate (win-acme) | The container itself speaks plain HTTP on 8080 |
| 4 | Do not open the container port (`-p …:8080`) in the server's firewall when a proxy or tunnel is used: only the proxy should reach it | Otherwise visitors can skip the proxy |
| 5 | Tell the site which proxy to trust: a tunnel or IIS on the host reaches the container through Docker's network, so `-e Xpact__KnownNetworks__0=172.16.0.0/12` ([details](#behind-a-reverse-proxy)) | Otherwise all visitors share one rate limit |
| 6 | If a Cloudflare/Azure WAF is turned on: **exclude `/api/validate` from the XSS rules** (CRS 941xxx / "XSS" managed rules) | Measured 2026-11-14 with OWASP CRS 4.25: every pasted XML document was blocked (403). A WAF does not stop XML attacks anyway: the parser and the worker sandbox do |
| 7 | `--isolation=hyperv` if the host has the Hyper-V role | The container gets its own kernel: stronger walls around the native DLL that parses untrusted files. ⬜ Not tested yet with this image: run the [checks below](#check-after-the-first-run) once |
| 8 | `--memory 4g --cpus 2 --restart unless-stopped` | Caps what one container can take from the server; restarts after a crash or reboot |
| 9 | Pull a fresh image every month (Windows patch Tuesday), or rebuild | Windows Server Core security patches come with the base image |
| 10 | Keep the logs: `docker logs xpact` is lost when the container is removed | Needed to see abuse; the site logs refusals (rate limit, full queue, bad requests) |

Full example (Cloudflare Tunnel or IIS on the same host, forwarding to `http://localhost:5099`):

```powershell
docker run -d --name xpact --isolation=hyperv --memory 4g --cpus 2 --restart unless-stopped `
  -p 5099:8080 `
  -e AllowedHosts=xpact.example.com `
  -e Xpact__KnownNetworks__0=172.16.0.0/12 `
  ghcr.io/andersoxie/xpact-website:website-2026-11-14-3
```

What is already built in (no setting needed): not an administrator in the container, each document parsed in a separate low-rights worker with a 512 MB cap and 10 s timeout, upload size limit, rate limit (30/min per visitor), slow-client cut-off, security headers (CSP, HSTS on HTTPS, `X-Frame-Options`, `nosniff`), no server banner, no error details to visitors. Scans 2026-11-14: Snyk (NuGet, npm), Semgrep, Trivy (Dockerfile), nuclei: 0 vulnerabilities.

## Settings

Every setting in [`appsettings.json`](../backend/src/Xpact.Api/appsettings.json) can be set with an environment variable (`__` between levels):

```powershell
docker run -d -p 5099:8080 `
  -e Xpact__RequestsPerMinute=60 `
  -e Xpact__TimeoutSeconds=10 `
  -e Xpact__KnownProxies__0=10.0.0.5 `
  xpact-website
```

### Behind a reverse proxy

The site must know each visitor's real address, or the rate limit (30 per minute) and the per-visitor worker share (2 of 4) apply to **all visitors together**. Which setting you need:

| Setup | Setting |
|---|---|
| IIS on the same machine (ASP.NET Core Module), or nginx on the same machine | nothing: a proxy on this machine is trusted automatically |
| A proxy on another machine with a fixed address | `Xpact__KnownProxies__0=<its address>` (more: `__1`, `__2`, …) |
| A proxy whose address changes (load balancer, a Docker network: IIS on the host in front of this container) | `Xpact__KnownNetworks__0=<range>`, e.g. `172.16.0.0/12` for Docker's default networks |

If it is not set up, the server log says so once per proxy address: *"X-Forwarded-For from … was ignored: that address is not trusted …"*. A mistyped address stops the start with a message naming it.

## Check after the first run

Checked by the `Website Docker image` workflow on every PR that touches the Dockerfile or the workflow (#284). First full pass: 2026-11-11, [run 42928039862](https://github.com/andersoxie/xpact/actions/runs/42928039862) (image `website-2026-11-09-4`, windows-2022): both builds available, `<root/>junk` rejected with code 9, `healthy`, and a 40 MB cap stops a nested-entity document (`crashed`) while the site keeps serving. With `website-2026-11-11-1` (#273) the same document gives **`rejected`, code 1 (out of memory)** on a normal PC, but inside the container still `crashed`: there the worker dies of a stack overflow before the heap limit is reached ([#316](https://github.com/andersoxie/xpact/issues/316)). Both mean the cap stopped the document; the workflow accepts either and checks that the site keeps serving.

- [x] `docker build` succeeds (base image tag matches the host)
- [x] `docker ps` shows the container as `healthy`
- [x] `curl.exe http://localhost:5099/api/info` shows both builds `"available":true`
- [x] `curl.exe -X POST http://localhost:5099/api/validate -H "Content-Type: application/xml" --data "<root/>junk"` gives `rejected`, code 9 (the worker and DLL run inside the container)
- [x] The memory cap still works inside the container (the worker's Job Object is nested in the container's own job)
