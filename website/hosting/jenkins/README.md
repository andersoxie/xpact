# Hosting the website on a Jenkins server

[← Docker documentation](../../docs/docker.md) · [Dockerfile](../../Dockerfile)

A step-by-step guide for running the ready image `ghcr.io/andersoxie/xpact-website` on your own server, deployed by a Jenkins pipeline.

> ⬜ **Not tested yet:** the Jenkinsfile below has not been run. The manual commands in step 2 come from [docker.md](../../docs/docker.md).

## 1. Check the server first (most common blocker)

The image is a **Windows container**: `xpact.dll` is a Windows DLL and the worker uses Windows Job Objects. It does **not** run on a Linux host or a Linux Jenkins agent.

| Requirement | How to check |
|---|---|
| Windows Server 2022 (the image is `ltsc2022`) | `winver` |
| Docker in **Windows containers** mode | `docker info --format "{{.OSType}}"` prints `windows` |
| A Jenkins agent on that Windows machine | Manage Jenkins → Nodes: give it a label, e.g. `windows-docker` |

- **Windows Server 2025:** rebuild the image with `--build-arg WINDOWS_TAG=ltsc2025`, or run with `--isolation=hyperv`.
- **Linux server:** the image cannot run there; use a Windows agent or a Windows VM.

## 2. Manual test (before Jenkins)

```powershell
docker pull ghcr.io/andersoxie/xpact-website:website-2026-11-14-3
docker run -d --name xpact --memory 4g --cpus 2 --restart unless-stopped `
  -p 5099:8080 `
  -e AllowedHosts="localhost;xpact.example.com" `
  -e Xpact__KnownNetworks__0=172.16.0.0/12 `
  ghcr.io/andersoxie/xpact-website:website-2026-11-14-3
```

Check:

```powershell
docker ps                                          # STATUS shows (healthy)
curl.exe http://localhost:5099/api/info            # both builds "available":true
curl.exe -X POST http://localhost:5099/api/validate -H "Content-Type: application/xml" --data "<root/>junk"   # rejected, code 9
```

Replace `xpact.example.com` with the real domain. `localhost` is in the list so the checks on the server itself are not refused by the host filter.

## 3. Jenkins pipeline (`Jenkinsfile`)

```groovy
pipeline {
  agent { label 'windows-docker' }
  environment {
    IMAGE     = 'ghcr.io/andersoxie/xpact-website:website-2026-11-14-3'
    SITE_HOST = 'xpact.example.com'
  }
  stages {
    stage('Pull') {
      steps { powershell 'docker pull $env:IMAGE' }
    }
    stage('Replace container') {
      steps {
        powershell '''
          if (docker ps -aq -f "name=^xpact$") { docker rm -f xpact }
          docker run -d --name xpact --memory 4g --cpus 2 --restart unless-stopped `
            -p 5099:8080 `
            -e "AllowedHosts=localhost;$env:SITE_HOST" `
            -e Xpact__KnownNetworks__0=172.16.0.0/12 `
            $env:IMAGE
        '''
      }
    }
    stage('Smoke test') {
      steps {
        powershell '''
          $ok = $false
          for ($i = 0; $i -lt 30; $i++) {
            try { Invoke-WebRequest http://localhost:5099/api/health -UseBasicParsing -TimeoutSec 5 | Out-Null; $ok = $true; break }
            catch { Start-Sleep 2 }
          }
          if (-not $ok) { docker logs xpact; throw "Health check failed" }
          Invoke-RestMethod -Method Post -Uri http://localhost:5099/api/validate `
            -ContentType 'application/xml' -Body '<root/>junk' | ConvertTo-Json
        '''
      }
    }
  }
}
```

## 4. Common problems

| Symptom | Cause | Fix |
|---|---|---|
| `no matching manifest` / `image operating system "windows" cannot be used` | Docker in Linux mode, or a Linux host | Switch to Windows containers or use a Windows host |
| `The container operating system does not match the host` | `ltsc2022` image on a 2025 host | Rebuild with `WINDOWS_TAG=ltsc2025`, or `--isolation=hyperv` |
| **400 Bad Request** on every page | The name used is not in `AllowedHosts` | List every name, separated by `;` |
| All visitors share one rate limit | The proxy is not trusted | `Xpact__KnownNetworks__0=172.16.0.0/12` (or `Xpact__KnownProxies__0`) |
| 403 when pasting XML | WAF XSS rules | Exclude `/api/validate` from the XSS rules |
| The pipeline cannot run `docker` | The Jenkins service account has no Docker access | Run the agent as a user in `docker-users`, or give the service account access |

## 5. Going public

- Serve HTTPS through a proxy: Cloudflare Tunnel, or IIS + win-acme.
- Do **not** open port 5099 in the firewall; only the proxy should reach it.
- Pull a fresh image monthly (Windows Patch Tuesday).

Full checklist: [docker.md → Hosting on the internet safely](../../docs/docker.md#hosting-on-the-internet-safely).
