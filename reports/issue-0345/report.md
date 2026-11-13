# #345 · Website build `website-2026-11-12-1`

| | |
|---|---|
| Status | ✅ shipped: release + Docker image `ghcr.io/andersoxie/xpact-website:website-2026-11-12-1` = `latest` (digest `sha256:08b77a5b…`) |
| Issue | [#345](https://github.com/andersoxie/xpact/issues/345) |
| Source | `incremental-test` @ `a840029` (same files as `main` after PR #344) |
| Release | [website-2026-11-12-1](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-12-1) (prerelease, asset `xpact-website-dist.zip`, 4.3 MB) |
| Workflow change | PR [#348](https://github.com/andersoxie/xpact/pull/348) (`26cbcb7`): `WEBSITE_RELEASE: website-2026-11-12-1` |

## What changed since `website-2026-11-11-1`

- Accessibility (#328): screen-reader text for the ✅/⬜ ticks, a real chart caption (`figcaption`), a labelled editor area, unambiguous label text.
- React clean-up (#329): read-only props, stable keys, theme lookup tables.
- Same DLLs as before: `xpact.dll` `ADAE03D2…`, `xpact_assertions.dll` `75F43A5B…` (DLL source unchanged since `2935a8a`, so no rebuild) and the same result data.

## Steps

1. `website\scripts\publish.ps1` (run as its own process) → `website\dist`, plus `BUILD-INFO.txt` with the commit and DLL hashes.
2. Smoke test of the published `dist` on the student PC (`Xpact.Api.exe --urls http://localhost:5099`).
3. Zip `website\dist` → `xpact-website-dist.zip`; GitHub release created by the student (the permission classifier blocks Claude from `gh release create`).
4. PR #348 sets `WEBSITE_RELEASE`; its workflow run builds and tests the image; the merge publishes it.

## Verification

| Check | Command / run | Result |
|---|---|---|
| Website tests | `website\scripts\test.ps1` (before the build) | ✅ 42/42, `tsc` + `vite build` |
| Health and builds | `GET /api/health`, `GET /api/info` on the published `dist` | ✅ `ok`; `production=True`, `assertions=True` |
| Verdicts | `POST /api/validate` | ✅ `<a x="1">hi</a>` accepted · `<root/>junk` rejected code 9 · `<a><b></a>` (assertions, 1-byte pieces) rejected code 7 |
| Pages | `GET /` | ✅ 200, title "XPact XML Parser"; `sr-only` in the main bundle, `figcaption` in the Benchmarks bundle |
| Image (PR) | run [43138345877](https://github.com/andersoxie/xpact/actions/runs/43138345877) | ✅ download, build, smoke test in the container, memory cap in the container; publish skipped (PR) |
| Image (publish) | run [43138936736](https://github.com/andersoxie/xpact/actions/runs/43138936736) on `26cbcb7` | ✅ same checks, then pushed `website-2026-11-12-1` and `latest`, both digest `sha256:08b77a5bed50…` |

Not checked: the site online (not deployed, #210); a Windows Server 2025 host.
