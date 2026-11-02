# 🖥️ PC2: continue from here

> **Note for Claude on the student's second PC (PC2).** Work moved here from PC1 on **2026-11-02**.
> Claude's memory from PC1 is not on this PC: this file is the handover. Read it first, then `student/PLAN.md` ("Next", item 12).
> Git marker: tag **`pc2-continue-here`** (the last work-in-progress commit).

## 1. State on 2026-11-02

- `student-Mass` has everything merged up to this note. `main` is never touched.
- Work in progress, **not merged**: branch **`test/227-memory-cap`** (tag `pc2-continue-here`), issue [#227](https://github.com/andersoxie/xpact/issues/227).
- Rules: the repo's `CLAUDE.md` and `student/VERSIONING.md`. One issue per problem, one PR per change into `student-Mass`, test evidence in the PR, verify before closing.

## 2. The student's request being worked on (website hardening before the supervisor hosts it)

| # | Point | State |
|---|---|---|
| 1 | Proxy: forwarded headers, so the rate limit sees the real visitor | ✅ done: [#224](https://github.com/andersoxie/xpact/issues/224), PR #225 |
| 2 | Website test #216 (`<root/>junk` gave 4 instead of 9) | ✅ done: [#216](https://github.com/andersoxie/xpact/issues/216), PR #226. Cause: stale DLL + `PreserveNewest` skipped an older-dated replacement |
| 3 | Memory cap test | 🟡 **in progress**: [#227](https://github.com/andersoxie/xpact/issues/227), branch `test/227-memory-cap` (see 3.1) |
| 4 | Load test | ⬜ to do |
| 5 | HTTPS through IIS or a reverse proxy | ⬜ to do: TLS is set up on the supervisor's server; prepare the app (HSTS/redirect behind the proxy) and write `website/docs/deployment.md` with the IIS steps |
| 6 | Workers under a low-privilege Windows account | ⬜ to do: the account is created on the supervisor's server; harden the worker in code (e.g. Job Object: no child processes) and document the account |

### 3.1 Memory cap: what is known
- The Job Object limit **is active** (flags `0x2500`, limit stored). Probe: `website/backend/tests/tools/job-memory-probe.ps1 -CapMb 40 -Kind elements|attr1mb|attrs|expand|tiny`.
- Under a 40–45 MB cap the worker **stays below the cap and finishes**: without a cap it peaks at 59–64 MB, but that is garbage-collector headroom.
- Measured peaks: tiny 27–28 MB; 1 MB attribute 40–43; 1,000 attributes 38–43; 1,000 × 1 KB entity expansion 28–29. **No document tried needs more than 40 MB.**
- The test `The_memory_cap_stops_a_worker_that_needs_more` **fails** on the branch (the document is accepted under the cap).
- Next: find a document that truly needs more memory, or test a cap below the worker's start-up size (~27 MB) and expect `crashed`; then finish the test, update `website/docs/security.md`, PR, merge, close #227.

## 3. Also open (from the same day)

- [ ] **Internship dates.** The website says "Sep–Nov 2026 (10 weeks)". The reports say "6 October – 27 November 2026 (eight weeks; build preparation from September)". The student says they started in September (ChatGPT for the first ~4 weeks, then Claude). **Ask the student for the exact start date**, then make the website (`website/frontend/src/data/site.ts`, `AUTHOR.role`), `student/report/ActualReport.md` and `ActualReportShorter.md` match, and add the ChatGPT → Claude use to the report's AI-use note. Use only real facts.
- [ ] `website/docs/api.md` and `security.md` list the allowed data names without `testing`.
- [ ] Optional: `website/docs/deployment.md` for the supervisor (Windows x64, `publish.ps1` → `dist/`, .NET 10, ~2–3 GB RAM, settings, open points, questions for him).
- [ ] The rest of `student/PLAN.md` item 12 (#197, #176/#123, #170, #126; #171/#13 wait for the supervisor). The supervisor runs the long tests on Jenkins.

## 4. Setting up PC2

1. Clone `https://github.com/andersoxie/xpact`, `git checkout student-Mass`.
2. Build the DLLs: `.\website\scripts\build-dll.ps1` (EiffelStudio 25.12 + MSVC, `ISE_C_COMPILER=msc_vc140`, the same as Jenkins).
3. Website checks: `.\website\scripts\test.ps1` (should be 20/20 on `student-Mass`; 21 tests on `test/227-memory-cap`, where the new memory-cap test fails until finished).
4. Run the site: `.\website\scripts\dev.ps1` → http://localhost:5173.
