# XPact versions

XPact uses [semantic versions](https://semver.org): `MAJOR.MINOR.PATCH`.
Everything before **1.0.0** is a pre-release: the open blockers (thread safety, the 10 MB input limit) are not fixed yet.

The versions up to 0.9.0 were assigned **afterwards** (2026-11-10) to commits that already existed, so every earlier state has a name. Each version is a git tag (`v0.9.0` …) on that commit.

`XML_ExpatVersion()` keeps returning `expat_2.8.1`: that is the **Expat API version XPact copies**, not XPact's own version. XPact's own version is in [`VERSION`](VERSION).

## Overview

| Version | Date | Commit | In one line |
|---|---|---|---|
| [Unreleased](#unreleased-on-incremental-test-after-090) | 2026-11-11 | `incremental-test` | DLL exception guard and thread safety, website hardening and new Docker image, fair speed test, script safety |
| [0.9.0](#090--2026-11-10) | 2026-11-10 | `1b8696f` | Launch candidate: website hardening tests, .NET tests in Jenkins, `main` = `incremental-test` |
| [0.8.0](#080--2026-11-09) | 2026-11-09 | `68abdcb` | Boogie proofs of two parser loops; main's Gobo benchmark work merged |
| [0.7.0](#070--2026-11-09) | 2026-11-09 | `f067a9d` | Final parser fully retested; website release and Docker image |
| [0.6.0](#060--2026-11-05) | 2026-11-05 | `45d2f53` | Speed work: incremental parsing; the final parser source |
| [0.5.0](#050--2026-11-02) | 2026-11-02 | `1b3c862` | The XPact website and the 11-area test campaign |
| [0.4.0](#040--2026-10-31) | 2026-10-31 | `b0ef442` | Output matches Expat on the W3C cases (#154–#165, #194–#199); in `main` via #177 |
| [0.3.0](#030--2026-10-28) | 2026-10-28 | `293918f` | All 2,585 W3C cases run, 7 parser bugs fixed |
| [0.2.0](#020--2026-10-23) | 2026-10-23 | `9e1747d` | Build and test-runner fixes; first student merge into `main` (#72) |
| [0.1.0](#010--2026-10-14) | 2026-10-14 | `fee611a` | Baseline: the supervisor's XPact and the W3C benchmark runner |

## Unreleased (on `incremental-test` after 0.9.0)

Not tagged yet. The Eiffel parser classes are unchanged; the DLL bridge changed.

- **DLL:** an Eiffel exception inside a call (e.g. out of memory) returns `XML_ERROR_NO_MEMORY` / `XML_ERROR_UNEXPECTED_STATE` instead of ending the process without a trace; `XPACT_EXCEPTION_TRACE=1` prints the trace (#273, PR #301).
- **DLL:** safe from several threads, each with its own parsers: calls into the single-threaded Eiffel runtime take turns; no single-thread cost (#274, PR #303). Parallel parsing is an open question (#304).
- **Website:** memory cap fails closed (#295), per-visitor worker cap and queue timeout/cap with 429/503 (#297), worker with no privileges at Low integrity, started suspended (#299).
- **Speed:** fair test against native Expat 2.8.1 through the same C API, median 18× slower, 0 checksum mismatches (#275, PR #276).
- **Tooling:** `run_benchmarks.ps1 -UseExistingNativeDll -NoDocsUpdate` (#302); evidence logs under `reports/` are committed (#306); benchmark scripts stop early on the Windows Store python alias, `XPACT_PYTHON` (#308).
- **Website:** an untrusted reverse proxy is logged, proxy ranges allowed, settings validated (#312, PR #313); pages show the fair speed result, thread and exception status and current limits (PR #314); Docker image `website-2026-11-11-1` shipped (PR #315, #317).
- **Tooling:** `fix.ps1` merges with a merge commit into `incremental-test`, refuses `main`, reverts merge commits (#318, PR #321); `build_native_eiffel.ps1` prints the DLL's SHA-256 before/after and `XPACT_FROZEN_DLL=1` stops any runner from rebuilding it (#319, PR #322).
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
