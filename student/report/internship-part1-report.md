# XPact: internship part 1, final report

> **Period:** September to November 2026 (commits 14 Oct to 16 Nov 2026) · **Branch:** `incremental-test` @ `295ce61` · **Repository:** [andersoxie/xpact](https://github.com/andersoxie/xpact)
> **Part 2:** resumes in a few weeks. Start with [CONTINUE-HERE.md](../CONTINUE-HERE.md) and [section 9](#9-plan-for-part-2) of this report.

**Legend:** ✅ done and verified · 🟡 partly done or waiting on someone · 🔴 open problem · ⏸ put aside by decision · ☐ not yet checked

---

## 1. At a glance

> XPact started as an Eiffel XML parser that **crashed on 1,360 of the W3C conformance cases** with its checks on, could not be built reliably and was not safe from several threads.
> It now **passes all 2,585 W3C cases with 0 failures in both builds**, gives **the same verdict as Expat 2.8.1** in every structured comparison, runs **on several CPU cores at once** (Gobo build), and has a **security-reviewed website**, a **SonarQube quality gate that passes with 0 issues**, and a complete record of every problem, fix and test result.

| 📊 Mileage | Number |
|---|---:|
| Commit contributions on GitHub (student profile, Aug-Nov 2026) | **790** |
| ↳ on andersoxie/xpact `main` (GitHub contributors) | 460 |
| ↳ on CodTanium/mass-xpact (the earlier fork, GitHub contributors) | 316 |
| ↳ unique commits across both repos, merges included / excluded | 509 / 347 |
| ↳ on `incremental-test`, excluding merges (used for the group table) | 343 |
| Pull requests merged by the student | **214** (of 250 in the repository in the period) |
| GitHub issues opened by the student | **177** |
| Issues closed after verification | **165** |
| Issues still open | 15 (listed in [section 4](#4-open-issues-all-15)) |
| Lines of code and scripts added (Eiffel, C, Python, PowerShell, C#, TypeScript) | **~47,500** |
| Lines of documentation and reports added | **~38,100** |
| Checklist items ticked in the docs | **458** |

| 🏆 Headline result | Before | After |
|---|---|---|
| W3C XML Conformance Suite (2,585 cases) | 1,360 crashes with assertions on; cases skipped | **2,585 / 2,585 run, 0 failed, 0 skipped** (both builds) |
| Same verdict as Expat 2.8.1, C API | not measured | **4,308 / 4,308** cases (C# P/Invoke tests) |
| Same verdict in pieces (G03, 14 ways of feeding) | not measured | **1,302 / 1,302** |
| W3C documents split at every position (Test 2) | 1,995 the same | **2,564 / 2,585** the same; 0 timeouts |
| Input in pieces (worst case) | **50 min** (re-parsed on every call) | **106 ms** |
| Whole documents | baseline | **4-7× faster** |
| xpact vs Expat (fair test, same C API) | not measured | median **~17× slower**, 0 checksum mismatches, every cell measured |
| Several threads through the DLL | **crash** (#274) | ✅ safe (ES: calls take turns) · ✅ Gobo: **4 threads 0.40 s vs 0.67 s on 1** |
| Gobo DLL speed vs EiffelStudio DLL | 0.59× | **0.92×** (parser alone 1.7× faster) |
| New test sources vs Expat | none | SVG 1.1 **525/525**, Kuhn UTF-8 **582/582**, DTD attacks **104/104**, libxml2 corpus 1,288/1,417 |
| Website security | not reviewed | 3 review rounds, **attack battery 27/27**, no real findings from ZAP, nuclei, Semgrep, CodeQL, Snyk or Trivy |
| Code quality | SonarQube not set up, C# never analysed | **Quality gate passes: 0 issues, 0 hotspots, new-code coverage 81.8 %** |

---

## 2. What we did, by group

Counts come from the GitHub issues, the merged PRs and the student's commits that name those issues. Commits here are the 343 non-merge commits on `incremental-test`; GitHub counts a commit once per repository and includes merges, which gives 790 on the profile. One commit can name issues from two groups.

| # | Group | Issues closed | PRs | Commits | Main results |
|---|---|---:|---:|---:|---|
| 1 | 🧩 **Parser correctness & XML conformance** | **23** | 22 | 65 | 0 W3C failures; invalid UTF-8 rejected; DTD defaults, tokenized attributes, BOMs, error codes as Expat |
| 2 | ⚡ **Speed & incremental parsing** | **6** | 5 | 14 | chunked input incremental (50 min → 106 ms); entity references linear; fewer allocations (1.07×); fair speed test vs Expat |
| 3 | 🧵 **Threads & Gobo Eiffel** | **6** | 5 | 14 | DLL thread-safe; Gobo DLL with the same results; global lock removed (Gobo); callback cost halved |
| 4 | 🧪 **Test harness & verification** | **21** | 20 | 39 | failing tests fail loudly; meta-tests; regression tests; C# DLL tests; G01/G03 Expat comparison; Test 2 on 16 cores (5.4×) |
| 5 | 🔧 **Build scripts & tooling** | **21** | 22 | 42 | reproducible builds (MSVC, paths, Python); no silent DLL rebuilds (SHA-256 shown); version numbers; script audit |
| 6 | 🏗️ **CI / Jenkins / DevOps** | **11** | 4 | 15 | Jenkins checks that really check; CodeQL + Dependabot; email on failure |
| 7 | 🌐 **Website features & hosting** | **11** | 8 | 15 | numbers and credits on the front page; Docker image; 10 MB uploads |
| 8 | 🛡️ **Website security** | **18** | 19 | 34 | memory cap, upload limits, slowloris, low-integrity worker, proxy and host checks, log forging, secret scan |
| 9 | 🧹 **Code quality (SonarQube, CodeQL)** | **12** | 16 | 26 | 0 issues, 0 hotspots, quality gate passes; C# analysed for the first time (76 issues resolved) |
| 10 | 📚 **Docs, planning & branch sync** | **36** | 32 | 94 | one live status page; weekly notes; error-report format; branch syncs with `main`; hand-in drafts |
| | **Total** | **165** | **214** | **343** | |

<details>
<summary><b>Issues closed in each group (click to open)</b></summary>

| Group | Issues |
|---|---|
| 1 Parser correctness | #3 #28 #38 #39 #40 #79 #122 #124 #125 #146 #154 #155 #156 #157 #158 #159 #165 #172 #173 #174 #175 #216 #273 |
| 2 Speed | #148 #209 #275 #352 #353 #407 |
| 3 Threads & Gobo | #274 #408 #409 #414 #418 #428 |
| 4 Test harness | #29 #32 #37 #45 #46 #48 #60 #117 #118 #121 #128 #142 #143 #153 #168 #169 #197 #213 #238 #252 #370 |
| 5 Build & tooling | #2 #4 #7 #10 #51 #53 #55 #73 #74 #179 #180 #265 #302 #306 #308 #318 #319 #401 #404 #405 #406 |
| 6 CI / DevOps | #56 #64 #88 #90 #93 #130 #131 #140 #262 #277 #369 |
| 7 Website features | #215 #218 #220 #222 #229 #231 #233 #236 #267 #345 #368 |
| 8 Website security | #224 #227 #255 #283 #284 #286 #295 #297 #299 #312 #316 #357 #358 #359 #360 #384 #424 #425 |
| 9 Code quality | #325 #326 #327 #328 #329 #330 #331 #332 #342 #371 #380 #397 |
| 10 Docs & sync | #5 #14 #16 #18 #20 #22 #24 #26 #33 #34 #35 #43 #66 #68 #70 #102 #104 #106 #108 #110 #113 #115 #132 #134 #137 #151 #183 #188 #250 #256 #270 #281 #290 #320 #346 #422 |

</details>

---

## 3. Timeline

| Weeks | Focus | Result |
|---|---|---|
| 1-2 | Orientation, reproduce the builds | ✅ workbench and finalized builds reproduced; first findings #2-#10 |
| 3 | Reliable test results (B01, B02) | ✅ failing tests return a nonzero exit; meta-tests prove it |
| 4 | Full check with assertions on | ✅ every build and test passes; MinGW, Python 3.10 and long-path traps found |
| 5-6 | Regressions and Expat comparison (C02, C03, C10) | ✅ all 2,585 W3C cases, 0 failed; 7 parser bugs fixed |
| 6-7 | Input in pieces, DTD details (G01, G03) | ✅ 1,302/1,302 the same as Expat; chunked input incremental |
| 7 | Website | ✅ upload, docs, conformance and benchmark pages; Docker image |
| 8 | Security, code quality, new test sources | ✅ 3 security rounds; SonarQube 0 issues; SVG, Kuhn, DTD attacks |
| 9 | Speed, threads, Gobo Eiffel | ✅ fair speed test; parser 1.07×; Gobo DLL multi-core, 0.92× ES |

---

## 4. Open issues (all 15)

| Issue | Area | Problem | State | Size |
|---|---|---|---|---|
| [#13](https://github.com/andersoxie/xpact/issues/13) | Parser | `XP_GC_CRITICAL_SECTION.execute` silently swallows exceptions from GC-suspended parses | 🔴 design question for the supervisor | L |
| [#123](https://github.com/andersoxie/xpact/issues/123) | Expat parity | no events before a malformed-UTF-8 error (Expat delivers them); 133 CDATA cases | 🔴 | M |
| [#126](https://github.com/andersoxie/xpact/issues/126) | Expat parity | default handler gets normalized line ends, not the raw CR | 🔴 about 41 call sites | L |
| [#170](https://github.com/andersoxie/xpact/issues/170) | Expat parity | error code differs from Expat on 14 W3C cases | 🔴 | M |
| [#171](https://github.com/andersoxie/xpact/issues/171) | Expat parity | error column is 0 where Expat points at the bad token | 🔴 design question | L |
| [#176](https://github.com/andersoxie/xpact/issues/176) | Expat parity | in pieces, `]]` of a forbidden `]]>` is delivered as text before the error | 🔴 | M |
| [#210](https://github.com/andersoxie/xpact/issues/210) | Website | upload/test XML, docs, conformance, benchmark pages: **built, not deployed** | 🟡 hosting is the supervisor's | S |
| [#211](https://github.com/andersoxie/xpact/issues/211) | Security | billion laughs: right error now, but ~1.5 s vs ~0.1 s for Expat | 🟡 | M |
| [#272](https://github.com/andersoxie/xpact/issues/272) | Speed | ISO-8859-1 input in pieces is quadratic (1 MB in 1 KB pieces: 46 s; UTF-8 linear) | 🔴 | M |
| [#293](https://github.com/andersoxie/xpact/issues/293) | Expat parity | entities nested more than 32 levels are rejected; Expat accepts them | 🔴 design question | S |
| [#304](https://github.com/andersoxie/xpact/issues/304) | Threads | is parallel parsing needed for 1.0? (answered for Gobo by #418) | 🟡 question | – |
| [#415](https://github.com/andersoxie/xpact/issues/415) | Build | `build_native_eiffel.ps1 -OutputDir` still writes `.obj` files into `build\native-eiffel` | 🔴 | S |
| [#420](https://github.com/andersoxie/xpact/issues/420) | Build | Dependabot: group updates per ecosystem (PR #421 works once on `main`) | 🟡 needs `main` | S |
| [#431](https://github.com/andersoxie/xpact/issues/431) | Threads | Gobo DLL stops scaling at 4 threads; 16 threads slower than 8 | 🔴 cause unknown | M |
| [#432](https://github.com/andersoxie/xpact/issues/432) | Threads | one parse uses one core; parallelism only across parses | 🟡 question | L |

Also known, from the earlier fork: **heap corruption under GC stress and load** (mass-xpact#20). It existed before this work, every build crashes at about the same rate under stress, and the cause is unknown.

---

## 5. Verifiable items not yet ticked

The repository's Markdown files have **458 ticked and 320 unticked** checkboxes. Many unticked ones are in frozen, archived reports. These are the ones that still matter:

<details open>
<summary><b>XPact parser and DLL</b></summary>

- ☐ #170 error codes (14 W3C cases), then #126 raw CR to the default handler
- ☐ #171 error columns and #13 GC exceptions (ask the supervisor first)
- ☐ #176 `]]>` in pieces and the rest of #123 (133 CDATA cases), together
- ☐ #272 ISO-8859-1 in pieces, then #123/#176, #126, #170
- ☐ Resume for Latin-1, ASCII, explicit and unknown encodings, and in external-entity child parsers
- ☐ Per-call overhead of `XML_Parse`: byte by byte is still about 14× slower than one call
- ☐ Carry text runs that a default handler also sees
- ☐ Trim `input_buffer` once the fallback is no longer needed (memory)
- ☐ Parser hot spots: `append_character`
- ☐ The 73 split-point differences in error documents: compare with Expat first
- ☐ The re-parse prototype `XP_INCREMENTAL_PARSE_SESSION`: ask the supervisor (F05-1)

</details>

<details open>
<summary><b>Gobo DLL and threads</b></summary>

- ☐ Profile the namespaces cells (0.74× ES) and the 256 B-64 KB pieces (~0.89×)
- ☐ Full 204-cell speed run of the new DLLs (only the 84 1 MB cells so far)
- ☐ W3C runner, C# and Python tests against the Gobo DLL
- ☐ #431 why scaling stops at 4 threads
- ☐ Gobo assertions variant of the DLL

</details>

<details open>
<summary><b>Tests and numbers</b></summary>

- ☐ Rerun the fair speed matrix (#275) on an idle PC before quoting final numbers
- ☐ Refresh the benchmark numbers on the website
- ☐ One W3C benchmark stage for the fixes since #172 (both builds)
- ☐ Rerun `website\scripts\test.ps1` after the Dependabot updates #393-#396
- ☐ Let the Docker memory-cap check require exit code 1 again
- ☐ The Postman collection has not been run in Postman (the xUnit tests cover the same requests)

</details>

<details open>
<summary><b>Supervisor decisions and access (one batch)</b></summary>

- ☐ Ask in one go: #304, #293, #211, #171, #13, deployment (#210), licence, assertions timeout, 10 MB limit
- ☐ SonarQube: 2 security hotspots need someone with review rights
- ☐ Repo settings: Dependabot alerts and secret scanning
- ⏸ Aikido: mark 14 checksum alerts as false positives

</details>

<details open>
<summary><b>Hand-in (27 Nov 2026)</b></summary>

- ☐ ✏️ Rewrite the reflection sections in my own words
- ☐ Rehearse the [demonstration](demonstration.md)
- ☐ A06: all weekly notes and result records complete (weeks 1-7 done)

</details>

---

## 6. Limits, step by step

Each step has a "Limits" section in its own report (50 reports have one). This is the summary.

| Step | What it proves | What it does not prove (limit) |
|---|---|---|
| **Build** (EiffelStudio 25.12, MSVC) | reproducible workbench and finalized builds, SHA-256 per DLL | Windows only for the DLL; Linux/macOS builds not checked; `-OutputDir` leak (#415) |
| **Eiffel test matrix** (4 lanes) | contracts hold with assertions on | tests cover what was written; no coverage numbers for Eiffel |
| **W3C suite** (2,585) | accept/reject matches the standard | 302 cases are "no crash only" (the suite has no expected output for them); verdict, not every event |
| **Expat comparison** (C#, G03, Test 2) | same verdict and events as Expat 2.8.1 | 21 Test 2 cases still differ (16 xpact-only, 5 both); error codes and columns differ (#170, #171) |
| **New test sources** | SVG, UTF-8, DTD attacks, libxml2 corpus | libxml2: 129 of 1,417 differ, each written up |
| **Speed** | fair test through the same C API, 0 checksum mismatches | one PC; 4 cells time out (elements-1MB-latin1, 1 B and 16 B pieces, #272); ~17× slower than Expat |
| **Threads (EiffelStudio DLL)** | safe from many threads | calls take turns: no speed-up from more threads |
| **Threads (Gobo DLL)** | several parses at once on several cores | one parse = one core (#432); stops scaling at 4 threads (#431); Gobo nightly 26.11.14 (supervisor qualified 26.11.12) |
| **Gobo DLL speed** | 0.92× ES on one thread, parser alone 1.7× | 1 MB cells only; namespaces 0.74× |
| **Memory and stress** | memory cap stops large documents in the website worker | heap corruption under GC stress (mass-xpact#20), cause unknown |
| **Website** | 48/48 backend tests, security battery 27/27, Docker image | not deployed; tested on `localhost` only; no frontend unit tests; no real load test on a server |
| **Security scans** | no real findings from 7 tools | scans are only as good as their rules; no external penetration test |
| **Code quality** | SonarQube gate passes | Eiffel is not analysed by SonarQube |
| **CI** | GitHub Actions on every PR, CodeQL | Jenkins dropped on 3 Nov; Eiffel builds and W3C runs are local, not in CI |

---

## 7. Left to do

### 7.1 XPact (parser, DLL, tools)
- 🔴 Close the Expat-parity gaps: #123, #126, #170, #171, #176, #293
- 🔴 ISO-8859-1 in pieces (#272), then resume for all encodings
- 🔴 Per-call overhead (byte by byte is 14× slower than one call)
- 🟡 Speed: from ~17× to under 5× slower than Expat (allocations, `append_character`, namespaces)
- 🟡 Billion laughs: stop as fast as Expat (#211); configurable limits for entity expansion
- 🟡 Gobo DLL: namespaces and medium pieces; scaling past 4 threads (#431); assertions variant
- 🟡 Decide on Gobo vs EiffelStudio as the shipping compiler
- 🔴 Build script `-OutputDir` (#415); Dependabot grouping (#420)
- 🔴 Find the cause of the heap corruption under GC stress (mass-xpact#20)

### 7.2 Website
- 🟡 Deploy: server, domain, HTTPS, `AllowedHosts` (supervisor, #210); image `website-2026-11-14-3` is ready
- ☐ Namespaces option in the validator (`XML_ParserCreateNS`)
- ☐ Compare with Expat live: a second worker that runs the same document through `libexpat.dll`
- ☐ Frontend unit tests; real load test on the server
- ☐ Refresh the benchmark numbers and add the Gobo results
- ☐ Rerun the website tests after the Dependabot updates

---

## 8. Road to commercial, industry-level use

What a company would expect from an XML parser it ships in its products, and where XPact stands.

| Area | Industry expectation | XPact today | Gap |
|---|---|---|---|
| **Conformance** | W3C suite passes; behaves like the reference (Expat, libxml2) | ✅ 2,585/2,585; same verdict as Expat | 🟡 error codes, columns, raw CR, CDATA events (#123-#176) |
| **Security** | safe against billion laughs, quadratic blowup, deep nesting, huge attributes; limits configurable; fuzzed continuously | ✅ attacks rejected; DTD attacks 104/104; differential fuzzing done | 🔴 billion laughs slow (#211); no configurable limits API; no continuous fuzzing (OSS-Fuzz style) |
| **Speed** | within 1-2× of Expat | 🟡 ~17× slower (ES), Gobo close to ES | 🔴 large gap; ISO-8859-1 in pieces quadratic |
| **Memory** | streaming with constant memory; no leaks; stable under stress | 🟡 incremental for UTF-8/16 | 🔴 heap corruption under GC stress; input buffer kept |
| **Threads** | one parser per thread, fully parallel | ✅ Gobo DLL parallel; ES DLL safe but serial | 🟡 scaling stops at 4 (#431) |
| **Platforms** | Windows, Linux, macOS; x64 and ARM64; static and shared builds | Windows x64 DLL | 🔴 Linux/macOS libraries, ARM64, packages |
| **API and ABI** | stable, versioned, documented; drop-in for Expat | ✅ Expat-style C API (`include/xpact.h`) | 🟡 version numbers exist (#265); no ABI policy; not every Expat function |
| **Packaging** | NuGet / vcpkg / Conan / pip / apt; signed binaries | Docker image for the website | 🔴 no library packages, no code signing |
| **Encodings** | UTF-8/16, Latin-1, ASCII, user encodings | ✅ UTF-8/16 incremental | 🟡 resume for Latin-1, ASCII, unknown encodings |
| **Quality process** | CI on every platform, coverage, static analysis, release notes | ✅ SonarQube 0 issues, CodeQL, Dependabot, issue-per-problem | 🔴 Eiffel builds and W3C not in CI; no Eiffel coverage |
| **Supply chain** | SBOM, signed releases, vulnerability policy (SECURITY.md), licence clear | 🟡 secret scan, Dependabot | 🔴 licence to decide; no SBOM, no signed releases |
| **Documentation** | API reference, user guide, migration from Expat, examples | ✅ project docs and reports; website docs pages | 🟡 API reference and Expat migration guide |
| **Support** | semantic versioning, changelog, long-term support branch | 🟡 version numbers | 🔴 changelog, release cadence, LTS |

**Suggested order to get there:** (1) security limits + #211 → (2) Expat-parity gaps → (3) speed and ISO-8859-1 → (4) Linux build + CI for Eiffel and W3C → (5) continuous fuzzing → (6) packaging, signing, licence, SBOM → (7) API reference and Expat migration guide.

---

## 9. Plan for part 2

| Priority | Work | Why first |
|---|---|---|
| 1 | Supervisor decisions in one batch (#304, #293, #211, #171, #13, licence, deployment) | several fixes wait for these answers |
| 2 | Deploy the website (#210) | finished work becomes visible |
| 3 | #272 ISO-8859-1 in pieces + #123/#176 | last quadratic case; Expat parity |
| 4 | Gobo DLL: #431, full run, W3C/C#/Python tests | makes the multi-core build ready to ship |
| 5 | Speed: namespaces, per-call overhead | towards a few times Expat's speed |
| 6 | Linux build and CI for Eiffel + W3C | first step to commercial use |

---

## 10. Where to find everything

| What | Where |
|---|---|
| Live status | [CONTINUE-HERE.md](../CONTINUE-HERE.md) |
| Plan and history | [PLAN.md](../PLAN.md) |
| Main hand-in report | [ActualReport.md](ActualReport.md) |
| All reports (one folder per issue) | [reports/README.md](../../reports/README.md) |
| Weekly notes | [student/notes/weekly/](../notes/weekly/) |
| Gobo DLL and threads | [reports/gobo-dll/README.md](../../reports/gobo-dll/README.md) |
| Open issues = to-do list | [GitHub issues](https://github.com/andersoxie/xpact/issues) |
