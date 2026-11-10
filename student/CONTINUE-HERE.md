# Continue here

> Short and current: state on **2026-11-10** (week 8 of 8). Start with `git fetch --all`, then read
> [PLAN.md](PLAN.md) ("Next", "Known problems") and [week-08](notes/weekly/week-08.md).
> Rules: the repo's `CLAUDE.md` and [VERSIONING.md](VERSIONING.md).

## 1. Branches

- Work branch: **`incremental-test`** on andersoxie/xpact (`origin`), since 2026-11-08. Not `student-Mass`.
- `student-Mass` is fully contained in `incremental-test` (0 missing; `incremental-test` has 153 more).
- `main` has 2 commits not in `incremental-test` (PR #254, Jenkins plots, 9 Nov). The student plans to merge
  `incremental-test` into `main` on 2026-11-11. Claude never merges into or pushes to `main`.
- CodTanium/mass-xpact is a mirror of andersoxie/xpact since 2026-11-09 (default `incremental-test`).

## 2. State

| Area | State |
|---|---|
| Full test rerun 2026-11-08 | ✅ no regression ([results](results/AlotOfTests-2026-11-08/README.md)); parser source unchanged since |
| PR #251 (`main` into `incremental-test`) | ✅ Python tests 226 OK (212 before) |
| PR #253, issue #252 (Boogie models) | ✅ merged; finds both old loop bugs, proves current code; 3 unstated facts open |
| Website | ✅ built, Docker image `website-2026-11-09-*`; 🟡 not deployed |
| mass-xpact#84 slow ISO-8859-1 in pieces | 🔴 still present (0.116 / 0.421 / 1.634 s for 64/128/256 KB) |
| mass-xpact#73 DLL crash without trace | 🔴 still present (code unchanged) |
| mass-xpact#20 heap corruption | ❔ not reproduced, inconclusive; cause unknown |
| mass-xpact#75 thread safety | 🔴 not fixed |
| SonarQube #131 | 🟡 student has a token; local scan tried 2026-11-10 |

The 9 open mass-xpact issues were closed as "not planned" without verification; the rows above are rechecks.

## 3. Next

- [x] `main` = `incremental-test` (2026-11-10).
- [ ] **Fair speed test, xpact vs native Expat 2.8.1 (run on PC2, idle PC).** Scope chosen 2026-11-10: core matrix.
  - Open an issue first. One C harness that loads `libexpat.dll` or `xpact.dll` through the same `expat.h` API (LoadLibrary), event checksum so both do the same work.
  - Matrix: 5 shapes (elements, attributes, text, DTD + entities, namespaces) × 10 KB / 1 MB / 10 MB × whole, 64 KB, 4 KB, 256, 16, 1 byte × callbacks on/off, UTF-8; UTF-16 and ISO-8859-1 on one shape; assertions DLL on a subset. Median of 5+, alternating, warm-up.
  - Expat DLL: `build\` is not committed; build it with `reports\issue-0121\expat-build.cmd` (Release). Build xpact once, record SHA-256 of all three DLLs.
  - Starting points: `benchmarks/libexpat_c_benchmark.c`, `benchmarks/xpact_native_c_benchmark.c`. Estimate ~1 day work, 1–2 h machine time.
- [ ] Website: [#227](https://github.com/andersoxie/xpact/issues/227) memory-cap test (in progress), load test, worker account (code part); HTTPS and deployment [#210](https://github.com/andersoxie/xpact/issues/210) are the supervisor's.
- [ ] Open issues on andersoxie (12): #227, #210, #197, #211, #176, #171, #170, #126, #123, #131, #130, #13.
- [ ] Refile mass-xpact #84, #73, #75 on andersoxie (one issue each).
- [x] Reports updated to 2026-11-10 (weeks 1–8); update again if anything changes before 27 Nov.

## 4. Setup on a new PC

1. Clone `https://github.com/andersoxie/xpact`, `git checkout incremental-test`.
2. Build the DLLs: `.\website\scripts\build-dll.ps1` (EiffelStudio 25.12 + MSVC `msc_vc140`).
3. Website checks: `.\website\scripts\test.ps1`; run the site: `.\website\scripts\dev.ps1`.
4. Skip the 45-minute W3C-in-pieces test unless a fix touches chunked input.
