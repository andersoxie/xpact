# Handover

> ✏️ **DRAFT** written by the AI assistant on 2026-11-16. The student checks and completes it before the hand-in on 27 November 2026.
> Repo: [andersoxie/xpact](https://github.com/andersoxie/xpact), work branch **`incremental-test`** @ `0c7e114`. Setup on a new PC: [CONTINUE-HERE.md §4](CONTINUE-HERE.md#4-setup-on-a-new-pc).
> Full report: [ActualReport.md](report/ActualReport.md) · short: [ActualReportShorter.md](report/ActualReportShorter.md) · status tracker: [PLAN.md](PLAN.md) · to-do with times: [TOOODOOO.txt](../TOOODOOO.txt).

## 1. Where things are

| What | Where |
|---|---|
| Parser and DLL bridge | `src/`, `native/`; build: `.\website\scripts\build-dll.ps1` (EiffelStudio 25.12 + `msc_vc140`) |
| Gobo build of the DLL | `reports\gobo-dll\build_gobo_dll.ps1` ([report](../reports/gobo-dll/README.md)) |
| Tests | Eiffel matrix `scripts\run_eiffel_test_matrix.ps1`, W3C `scripts\run_benchmarks.ps1`, C# `tests\dotnet\XpactDllTests`, Python `tests\python` |
| Every fix and its evidence | `reports/issue-NNNN/` (index: [reports/README.md](../reports/README.md)) |
| Website | `website/` ([docs](../website/docs/)); image `ghcr.io/andersoxie/xpact-website:website-2026-11-14-3`; hosting checklist: [docker.md](../website/docs/docker.md#hosting-on-the-internet-safely) |
| Rules for changes | [VERSIONING.md](VERSIONING.md), repo `CLAUDE.md` |

## 2. Open work (13 issues on 2026-11-16)

### Can be done without a decision

| # | What | Time |
|---|---|---|
| [#272](https://github.com/andersoxie/xpact/issues/272) | ISO-8859-1 in pieces is quadratic; copy the UTF-16 resume path | 1-2 days |
| [#123](https://github.com/andersoxie/xpact/issues/123), [#176](https://github.com/andersoxie/xpact/issues/176) | Events before a UTF-8 error; `]]` before a `]]>` error in pieces (do together) | 1-2 days each |
| [#126](https://github.com/andersoxie/xpact/issues/126) | Default handler gets normalized line ends, not the raw CR | 1-2 days |
| [#170](https://github.com/andersoxie/xpact/issues/170) | Error code differs from Expat on 14 W3C cases | 2-3 days |
| [#415](https://github.com/andersoxie/xpact/issues/415) | `build_native_eiffel.ps1 -OutputDir` still writes `.obj` into `build\native-eiffel` | hours |
| [#418](https://github.com/andersoxie/xpact/issues/418) | Gobo DLL: remove the global bridge lock (parallel C API) | days |
| Gobo follow-ups | Rerun the Gobo vs EiffelStudio thread test with msc (Eric Bezault's advice on #304); profile callback cost; GC tuning inside the DLL | ½-1 day each |
| Speed | Rerun the fair speed matrix (#275) on an idle PC before quoting final numbers | 1-2 h machine time |
| Dependabot | PRs #393-#396 (C# test packages): run the tests, merge one by one (#388-#392 merged by the supervisor, 16 Nov) | 30 min each |
| Docker | Let the memory-cap check require exit code 1 again | 1 h |

### Needs the supervisor's decision

| # | Question |
|---|---|
| [#304](https://github.com/andersoxie/xpact/issues/304) | Is parallel parsing needed for 1.0? (EiffelStudio runtime does not scale; Gobo does) |
| [#293](https://github.com/andersoxie/xpact/issues/293) | Entity depth > 32: remove the limit, or keep it with its own error code? |
| [#211](https://github.com/andersoxie/xpact/issues/211) | Billion laughs stopped with the right error, but ~1.5 s vs Expat ~0.1 s: acceptable? |
| [#171](https://github.com/andersoxie/xpact/issues/171), [#13](https://github.com/andersoxie/xpact/issues/13) | Error column; GC section swallows exceptions: fix or accept? |
| [#210](https://github.com/andersoxie/xpact/issues/210) | Hosting: server, domain, HTTPS, **`AllowedHosts`**; repo Settings → Dependabot alerts + secret scanning; "Automatically delete head branches" |
| Other | 10 MB input limit; licence file; raise the 10 s timeout for the assertions build? |

## 3. Known traps

- Never let a runner rebuild the DLL you are testing: set `XPACT_FROZEN_DLL=1` after the build (#319).
- In Windows PowerShell 5.1 run `publish.ps1` in its own process; avoid `2>&1` on native tools.
- `python` may be the Microsoft Store alias: set `XPACT_PYTHON` (#308).
- Windows 11 Home cannot run Windows containers: Docker checks run in GitHub Actions (`website-docker.yml`).
- `main` and `incremental-test` differ (8 commits only on `main`, from the supervisor); merge with a merge commit, never squash.

## 4. Review comments

| From | Comment | Done |
|---|---|---|
| *(none received by 2026-11-16)* | | |
