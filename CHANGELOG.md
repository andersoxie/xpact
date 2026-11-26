# XPact versions

XPact uses [semantic versions](https://semver.org): `MAJOR.MINOR.PATCH`.
Everything before **1.0.0** is a pre-release: the open blockers (thread safety, the 10 MB input limit) are not fixed yet.

The versions up to 0.9.0 were assigned **afterwards** (2026-11-10) to commits that already existed, so every earlier state has a name. Each version is a git tag (`v0.9.0` …) on that commit.

`XML_ExpatVersion()` keeps returning `expat_2.8.1`: that is the **Expat API version XPact copies**, not XPact's own version. XPact's own version is in [`VERSION`](VERSION).

## Overview

| Version | Date | Commit | In one line |
|---|---|---|---|
| [Unreleased](#unreleased-on-incremental-test-after-0100) | - | `incremental-test` | (nothing yet)  |
| [0.10.1](#0101--2026-11-26) | 2026-11-26 | `v0.10.1` | Website: Google Search Console verification meta tag (image `website-2026-11-26-1`) |
| [0.10.0](#0100--2026-11-19) | 2026-11-19 | `v0.10.0` | **Milestone:** thread-safe DLL, Gobo DLL, 1.07× faster parser, SonarQube 0 issues, Gobo XML comparison, one live status page |
| [0.9.0](#090--2026-11-10) | 2026-11-10 | `1b8696f` | Launch candidate: website hardening tests, .NET tests in Jenkins, `main` = `incremental-test` |
| [0.8.0](#080--2026-11-09) | 2026-11-09 | `68abdcb` | Boogie proofs of two parser loops; main's Gobo benchmark work merged |
| [0.7.0](#070--2026-11-09) | 2026-11-09 | `f067a9d` | Final parser fully retested; website release and Docker image |
| [0.6.0](#060--2026-11-05) | 2026-11-05 | `45d2f53` | Speed work: incremental parsing; the final parser source |
| [0.5.0](#050--2026-11-02) | 2026-11-02 | `1b3c862` | The XPact website and the 11-area test campaign |
| [0.4.0](#040--2026-10-31) | 2026-10-31 | `b0ef442` | Output matches Expat on the W3C cases (#154–#165, #194–#199); in `main` via #177 |
| [0.3.0](#030--2026-10-28) | 2026-10-28 | `293918f` | All 2,585 W3C cases run, 7 parser bugs fixed |
| [0.2.0](#020--2026-10-23) | 2026-10-23 | `9e1747d` | Build and test-runner fixes; first student merge into `main` (#72) |
| [0.1.0](#010--2026-10-14) | 2026-10-14 | `fee611a` | Baseline: the supervisor's XPact and the W3C benchmark runner |

## Unreleased (on `incremental-test` after 0.10.0)

Nothing yet.

## 0.10.1 – 2026-11-26

**Website only**, on `main` (git tag `v0.10.1` on the merge commit). Easy-to-read history: [VERSION-HISTORY.md](VERSION-HISTORY.md).

- **Added:** the Google Search Console verification meta tag in `website/frontend/index.html`, so Google can verify that we own https://xpact.bsharp.se/.
- **Changed:** Jenkins deploys image `website-2026-11-26-1` (`ci/Jenkinsfile.website-deploy`). That image is `website-2026-11-14-3` plus only this tag: same code, same DLLs (the [release notes](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-26-1) list the file-by-file check).
- **Undo:** `git revert -m 1 <merge commit of v0.10.1>` on `main`, or run the Jenkins job with `IMAGE_TAG=website-2026-11-14-3`.

## 0.10.0 – 2026-11-19

**Milestone** on `incremental-test` (git tag `v0.10.0` on the merge commit of the milestone pull request). The Eiffel parser classes changed only for speed (#407); the DLL bridge changed.

- **DLL:** an Eiffel exception inside a call (e.g. out of memory) returns `XML_ERROR_NO_MEMORY` / `XML_ERROR_UNEXPECTED_STATE` instead of ending the process without a trace; `XPACT_EXCEPTION_TRACE=1` prints the trace (#273, PR #301).
- **DLL:** safe from several threads, each with its own parsers: calls into the single-threaded Eiffel runtime take turns; no single-thread cost (#274, PR #303). Parallel parsing is an open question (#304).
- **Website:** memory cap fails closed (#295), per-visitor worker cap and queue timeout/cap with 429/503 (#297), worker with no privileges at Low integrity, started suspended (#299).
- **Speed:** fair test against native Expat 2.8.1 through the same C API, median 18× slower, 0 checksum mismatches (#275, PR #276).
- **Tooling:** `run_benchmarks.ps1 -UseExistingNativeDll -NoDocsUpdate` (#302); evidence logs under `reports/` are committed (#306); benchmark scripts stop early on the Windows Store python alias, `XPACT_PYTHON` (#308).
- **Website:** an untrusted reverse proxy is logged, proxy ranges allowed, settings validated (#312, PR #313); pages show the fair speed result, thread and exception status and current limits (PR #314); Docker image `website-2026-11-11-1` shipped (PR #315, #317).
- **Tooling:** `fix.ps1` merges with a merge commit into `incremental-test`, refuses `main`, reverts merge commits (#318, PR #321); `build_native_eiffel.ps1` prints the DLL's SHA-256 before/after and `XPACT_FROZEN_DLL=1` stops any runner from rebuilding it (#319, PR #322).
- **SonarQube (2026-11-12):** 196 issues → 0, duplication 14 % → 0 % (#325-#332, PRs #333-#340): evidence folders excluded from the scan; website accessibility (real `figcaption`, screen-reader text, labelled editor) and React fixes; Python scripts split into smaller functions with no behaviour change. SHA-1 for git blob ids marked `usedforsecurity=False` (#342, PR #343): hotspots 3 → 2, both to be reviewed as Safe.
- **Website:** build `website-2026-11-12-1` with the accessibility and React fixes; release and Docker image `ghcr.io/andersoxie/xpact-website:website-2026-11-12-1` = `latest` (digest `sha256:08b77a5b…`) (#345, PR #348).
- **`main`:** synced with `incremental-test` on 2026-11-12 (PR #344, merge commit).
- **Speed (2026-11-16):** four allocation changes in the parser, DLL median 1.07×, elements 1.16×, results unchanged ([#407](https://github.com/andersoxie/xpact/issues/407), PR #411).
- **Gobo Eiffel (2026-11-16):** shared Gobo ECF builds on Windows with Eric Bezault's quoted `eif_misc.h` include ([#409](https://github.com/andersoxie/xpact/issues/409), PR #417); `xpact.dll` built with Gobo + msc, identical results ([#414](https://github.com/andersoxie/xpact/issues/414), PR #416); global bridge lock removed in the Gobo build, 4 threads 0.40 s vs 0.61 s ES ([#418](https://github.com/andersoxie/xpact/issues/418), PR #430); callback strings reused and GC tuning inside the DLL, Gobo 0.92× ES on one thread, ES callbacks 10-25 % faster ([#428](https://github.com/andersoxie/xpact/issues/428), PR #429).
- **Docs (2026-11-16/17):** one live status page ([#422](https://github.com/andersoxie/xpact/issues/422)); thread limits #431/#432 (PR #433); overview report ([#434](https://github.com/andersoxie/xpact/issues/434), PR #435); checkbox review ([#436](https://github.com/andersoxie/xpact/issues/436), PR #437); traceability map and decision log ([#438](https://github.com/andersoxie/xpact/issues/438)).
- **Security (2026-11-16/18):** visitor values written to the log on one line, CodeQL log forging ([#424](https://github.com/andersoxie/xpact/issues/424), PR #427, explained in PR #444); Gitleaks secret scan on every push and PR ([#425](https://github.com/andersoxie/xpact/issues/425), PR #426).
- **Dependencies (2026-11-16):** Dependabot groups minor and patch updates per ecosystem ([#420](https://github.com/andersoxie/xpact/issues/420), PR #421); test SDK, xUnit runner, coverlet, Vite, actions/checkout, setup-python and CodeQL action updated (PRs #388-#396).
- **Comparison (2026-11-18):** xpact against Gobo's pure-Eiffel XML parser on every suite: W3C 1,974/1,974 vs 1,910, fuzzing 99.996 % vs 97.6 % same as Expat, 3.4-8.6× faster ([#442](https://github.com/andersoxie/xpact/issues/442), PR #443).
- **Docs (2026-11-16/17):** hand-in drafts: short report, reflection, demonstration, handover (PR #419); strategic action plan [docs/Xpact-future-plan.md](docs/Xpact-future-plan.md) ([#440](https://github.com/andersoxie/xpact/issues/440), PR #441).
- **Findings:** #211 rechecked (right error, ~1.5 s); #293 entity depth > 32 rejected as "syntax error"; #316 under a 40 MB cap the container worker can end in a stack overflow instead of "out of memory".

## 0.9.0 – 2026-11-10

Launch candidate. Parser source unchanged since 0.6.0.

- Website: the worker memory cap is tested with a document that reaches it (#227); load test, ~31–40 requests/s, no failures up to 32 visitors at once (#255).
- Jenkins runs the C# DLL tests (4,308 cases, both DLLs) and the website backend tests (21) (#262, #263).
- Local SonarQube scan script (#131, still open: the token is invalid).
- Week 8 notes and status files (#256).
- `main` and `incremental-test` are the same commit.

## 0.8.0 – 2026-11-09

- Boogie models prove the start-tag and UTF-16 decoder loops and find both old loop bugs in the code from before their fixes (#252, #253). Three facts the proofs need are not stated by any contract (open finding).
- `main`'s Gobo / WSL benchmark work merged in (#235, #251).

## 0.7.0 – 2026-11-09

- All 11 test areas and the repository suites rerun on the final parser (#239): W3C 2,585 cases with 0 failures in both builds, 3.9 million fuzzed inputs with 0 crashes, 4,308 / 4,308 C# DLL tests, no memory leak. See `student/results/AlotOfTests-2026-11-08/`.
- Website releases `website-2026-11-09` … `-4`; Docker image built on GitHub (#241).

## 0.6.0 – 2026-11-05

The final parser source (unchanged up to 0.9.0).

- Incremental parsing: resume from a checkpoint instead of re-parsing the buffer; resumed UTF-16 decoding and text runs. Worst cases from ~50 min to ~106 ms.
- Allocation and scanning speed-ups (#31–#57 in mass-xpact); Eiffel inlining for the production DLL.
- Fixes: billion-laughs rule with code 43 (#60), unread external entities as Expat (#64, #69), position between calls (#68), loop variants (#72), default handler references (#3), invalid UTF-16 surrogate (#12).
- Acceptance run against the 0.4.0-era base: `reports/acceptance-253c81e-vs-45d2f53/`.

## 0.5.0 – 2026-11-02

- The XPact website: upload or paste XML, docs, conformance and benchmark pages (#210, #212).
- AlotOfTests: 11 test areas against Expat (2026-10-28) (#214).

## 0.4.0 – 2026-10-31

- W3C output fixes so events match Expat: attribute defaults from external DTDs and entities, attribute normalization, public identifiers, BOM, parameter entities, DTD callbacks in pieces (#154–#165).
- More Expat behaviour: empty system literal, `#FIXED` defaults, subset declarations before a bracket error, junk after the document (code 9), mismatched end tags (#194–#199).
- Merged into `main` by the supervisor as PR #177.

## 0.3.0 – 2026-10-28

- All 2,585 W3C cases run with no skips; 7 parser bugs fixed (#146).
- Internal entity references no longer cost time proportional to the document (#148).
- Dual regression lane (#153); DLL smoke tests back in CI (#142, #144).

## 0.2.0 – 2026-10-23

- Builds work on the student PC and on Jenkins (MSVC `msc_vc140` backend, PATH limits, workbench lanes).
- The Eiffel test runner exits non-zero on a failure and keeps going after an exception (B01, B02).
- Start-tag loop variant fix (#3), a CR in `normalized_input` (#59).
- C# DLL test program (#41).
- First student merge into `main` (PR #72).

## 0.1.0 – 2026-10-14

Baseline at the start of the internship: the supervisor's XPact (Eiffel XML parser with the Expat C API) and the W3C XML conformance benchmark runner (PR #1).
