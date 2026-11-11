# Issue #286: website quality (Lighthouse, OWASP ZAP, W3C validator, ESLint)

| Item | Value |
|---|---|
| Issue | [#286](https://github.com/andersoxie/xpact/issues/286) (label `bug`) |
| Branch | `fix/website-quality`, from `incremental-test` @ `7667a16` |
| DLLs | `xpact.dll` `4513b4a2…`, `xpact_assertions.dll` `eb126628…` (2026-11-08 build, parser not changed) |
| Machine | student PC, Windows 11 Home, .NET SDK 10, Node 22, Edge (headless) |
| Site | `website/scripts/publish.ps1`, `Xpact.Api.exe --urls http://localhost:5099`, `ASPNETCORE_ENVIRONMENT=Production` |
| Status | ✅ fixed and checked locally |

## Summary

| Check | Before | After |
|---|---|---|
| Lighthouse performance (5 pages, mobile / desktop) | 91-94 / 87-100 | 99-100 / 98-100 |
| Lighthouse accessibility | 89-91 (dark) | **100** on all 5 pages, light **and** dark |
| Lighthouse best practices / SEO | 100 / 100 | 100 / 100 |
| OWASP ZAP 2.17.0 quick scan | 2 medium (CSP) | **0** medium, 0 high (3 informational) |
| W3C HTML validator (vnu 24, 6 rendered pages) | 0 errors, 11 warnings | **0 errors, 0 warnings** (`vnu-html-after.txt`) |
| W3C CSS validator (vnu `--css`) | 0 errors | 0 errors |
| ESLint 9 (typescript-eslint, react-hooks, jsx-a11y) | 0 problems, 18 files | 0 problems |
| Backend tests | 22 / 22 | 23 / 23 (+ compression test; header test extended) |

Evidence in this folder: `lighthouse-before.txt`, `lighthouse-after.txt` (before the last two fixes: Project headings and the light grey text), `lighthouse-accessibility-both-themes-after.txt` (final), `zap-report.txt`, `zap-report-after.txt`.

## Fixes

| Finding | Fix | Where |
|---|---|---|
| Colour contrast: active menu item 3.99, blue buttons 3.63 (dark), grey text 4.24 (light) | Text accent `#5b9cf0` (dark) / `#1f6cc4` (light); a separate button colour `--accent-strong`; light grey `#6b6a65` (all ≥ 4.5:1) | `styles/tokens.css`, `styles/app.css` |
| Links in text told apart by colour only | Links inside paragraphs, lists, tables and the footer are underlined | `styles/app.css` |
| Heading order (h1 → h3) on Project | Card titles are `h2` with the `h3` size | `pages/Project.tsx`, `pages/Home.tsx` |
| Layout shift 0.26 on Home (data loaded later pushed the intro cards down) | The intro cards come before the loaded sections | `pages/Home.tsx` |
| No text compression (~214 KB) | Brotli/gzip response compression | `Program.cs` |
| No cache policy | `/assets/*` (hashed names): 1 year, immutable; everything else: `no-cache` | `Program.cs` (`SiteFiles`) |
| One 305 KB script for every page | Validator, Docs, Benchmarks and Project load on first visit (`React.lazy`) | `App.tsx` |
| ZAP: CSP directives without fallback | `base-uri 'self'; form-action 'self'; object-src 'none'` | `Program.cs` |
| ZAP: `style-src 'unsafe-inline'` (security.md finding 7) | Removed. React sets style props through the DOM, which CSP allows; no CSP error in the console (best practices 100) and the pages look the same | `Program.cs` |
| `Server: Kestrel` header; no `Permissions-Policy`, `Cross-Origin-Opener-Policy` | Server header off; both headers added, plus `Cross-Origin-Resource-Policy` | `Program.cs` |
| Same `<title>` on every page | One title per page | `components/Layout.tsx` |
| No `robots.txt` | Added (pages allowed, `/api/` not) | `public/robots.txt` |
| vnu: sections without a heading; `aria-label` on a plain `span` | Stats grids are `div`; tick icons get `role="img"` | `pages/Home.tsx`, `pages/Benchmarks.tsx` |
| Home page said "mass-xpact#84" | Now "issue #272" | `pages/Home.tsx` |

## Not changed

- **Stylelint** (`stylelint-config-standard`): 145 notes, all formatting preferences (empty lines, `#fff` vs `#ffffff`, `Roboto` case). No bug; not changed.
- **"Unused JavaScript"** (~160 KB, mostly React itself): the remaining main script is 272 KB (87 KB gzip). Smaller only with a lighter framework.
- **Sitemap**: needs the real domain (absolute URLs). Add it with the domain at deployment.
- Unknown pages return the app with status 200 (the app shows "Page not found"). Normal for a single-page app.

## Not possible from this PC (the site is not public yet)

PageSpeed Insights, GTmetrix, WebPageTest, Google Search Console, Bing Webmaster Tools, Rich Results Test, SSL Labs, Mozilla Observatory, SecurityHeaders.com and BrowserStack need a public URL. Lighthouse is the engine behind PageSpeed Insights; the header checks were done locally. Run these once the supervisor has deployed the site with HTTPS.

## Limitations

- One PC, Edge only (Chromium). No Firefox/Safari test.
- ZAP's spider only finds `/` (a single-page app); the active scan did not attack `POST /api/validate`. The API's own tests cover bad input, limits and the rate limit.
- Automated accessibility checks do not find every problem; no screen-reader test was done.

## Verification

- `website/scripts/test.ps1`: backend 23 / 23 passed, frontend type check and build passed.
- Lighthouse, ZAP and vnu reruns on the fixed site: see Summary and the files in this folder.
- After merging #288 and #287 together (merge commit `6da9a54`): `website/scripts/test.ps1` **27 / 27** backend tests passed, frontend build passed.
