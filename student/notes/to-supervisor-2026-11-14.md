# To the supervisor: hosting the XPact website (2026-11-14)

> Message for Anders. Everything below is ready on `incremental-test`. Copy the "Message" part into an email or chat.

## Message

Hi Anders,

The XPact website is ready to host as a Docker image. Below are the things I need from you, with links and a short reason for each.

### 1. ✅ The Docker image: please host it
- Image: `ghcr.io/andersoxie/xpact-website:website-2026-11-14-3` (same as `latest`)
- Release: https://github.com/andersoxie/xpact/releases/tag/website-2026-11-14-3
- Needs: Windows Server with the Containers feature (2022 by default; 2025 needs a rebuild with `--build-arg WINDOWS_TAG=ltsc2025`).

```powershell
docker pull ghcr.io/andersoxie/xpact-website:website-2026-11-14-3
docker run -d --name xpact --isolation=hyperv --memory 4g --cpus 2 --restart unless-stopped `
  -p 5099:8080 -e AllowedHosts=YOUR-DOMAIN -e Xpact__KnownNetworks__0=172.16.0.0/12 `
  ghcr.io/andersoxie/xpact-website:website-2026-11-14-3
```

> Why: this is the newest version, with all security fixes (upload flood, slow clients, DLL search path).
> Older images (`website-2026-11-12-1` and before) do not have these fixes.
> It passed its smoke tests on Windows Server 2022 in GitHub Actions.

### 2. ⚠️ Set `AllowedHosts` to your domain
- `-e AllowedHosts=xpact.example.com` (several: `a.com;b.com`)

> Why: the site only answers the host name `localhost` by default.
> Without this setting every visitor gets "400 Bad Request".
> It stops attacks that use fake host names.

### 3. 🔒 Put HTTPS in front (Cloudflare Tunnel or IIS)
- Checklist: https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely
- Easiest: a free Cloudflare Tunnel (`cloudflared` on the host → `http://localhost:5099`). Or IIS with a Let's Encrypt certificate (win-acme).
- Do not open port 5099 in the firewall; only the tunnel/proxy should reach it.

> Why: the container speaks plain HTTP only.
> A tunnel gives HTTPS, hides the server's address and needs no open port.
> The `KnownNetworks` setting above lets the site see each visitor's real address (fair rate limits).

### 4. ⚠️ If you turn on a web firewall (Cloudflare WAF / Azure WAF)
- Exclude `/api/validate` from the XSS rules.

> Why: in my test (OWASP rule set 4.25) the firewall blocked **every** pasted XML document.
> It also did not stop XML attacks; the parser and the locked-down worker do that.
> So the exception costs no safety.

### 5. 🛡️ GitHub: turn on two free security switches
- https://github.com/andersoxie/xpact/settings/security_analysis → **Dependabot alerts** and **Secret scanning**: Enable.

> Why: they warn about libraries with known holes and about passwords committed by mistake.
> Only a repo admin can turn them on.
> CodeQL and weekly Dependabot updates already run (PR #373).

### 6. 📄 The full security report (for reading)
- https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/README.md

> Why: it shows what was tested and what was found, with exact results (SonarQube: 0 issues; I review the hotspots myself).
> Final build: 48/48 backend tests, 27/27 attack tests, no real findings from ZAP, nuclei, Semgrep, CodeQL, Snyk, Trivy or npm/NuGet audits.
> Not tested: the container on a real server (my PC cannot run Windows containers); please run the checks in docker.md once.

Thanks!
