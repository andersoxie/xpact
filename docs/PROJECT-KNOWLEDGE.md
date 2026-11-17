# Project knowledge and traceability

> **One map of the whole XPact project.** Every question someone can ask about the project, and the place in the repository that answers it.
> State **2026-11-17** · branch `incremental-test` · live status: [CONTINUE-HERE.md](../student/CONTINUE-HERE.md) · overview with numbers: [Comprehensive Overview Summary](Comprehensive-Overview-Summary-of-the-Project.md) · decisions: [decision-log.md](decision-log.md)

**Legend:** ✅ current and complete · 🟡 exists, partly current or waiting on someone · 🔴 missing

| # | Area | The question it answers | Main places | State |
|---|---|---|---|---|
| 1 | [Planning and requirements](#1-planning-and-requirements) | What are we building? What needs to be done? | GitHub issues, PLAN, roadmap | ✅ 15 open issues = the to-do list |
| 2 | [Development history](#2-development-history) | What changed, who changed it and why? | commits, PRs, CHANGELOG | ✅ every change has an issue + PR |
| 3 | [Testing and verification](#3-testing-and-verification) | Does it work? What failed? What was fixed? | reports/, results, benchmarks | ✅ W3C 2,585 / 0 failed |
| 4 | [Technical documentation](#4-technical-documentation) | How does everything fit together? | docs/, website/docs, setup guide | 🟡 no API reference yet |
| 5 | [Project history and knowledge](#5-project-history-and-knowledge) | What have we learned? What decisions were made? | investigation reports, decision log, weekly notes | ✅ |

---

## 1. Planning and requirements
*What are we building? What needs to be done?*

| Artifact | Where | Notes |
|---|---|---|
| 🎯 Goal and scope | [README.md](../README.md), [student introduction](xpact-student-introduction.md) | Eiffel XML parser with an Expat-compatible C API; task register A01-H06 |
| ✅ To-do list (issues) | [open issues](https://github.com/andersoxie/xpact/issues) | **15 open** on 2026-11-17: #13, #123, #126, #170, #171, #176, #210, #211, #272, #293, #304, #415, #420, #431, #432 |
| 🏷️ Labels | `bug`, `test`, `build`, `documentation`, `regression`, `investigation`, `type:finding`, `type:task`, `group:*`, `P0`/`P1`, `D1`-`D4` | recorded in [student/github/](../student/github/README.md) |
| 📅 Milestones and plan | [PLAN.md](../student/PLAN.md) (10-week plan, task status, history) | weeks 1-9 ✅, week 10 (handover) 🟡 |
| ➡️ What to do next | [CONTINUE-HERE.md §3](../student/CONTINUE-HERE.md#3-next-in-this-order), [HANDOVER.md §2](../student/HANDOVER.md) | with time estimates |
| 🗺️ Roadmap | website: [roadmap.md](../website/docs/roadmap.md) · parser: [overview §7-§9](Comprehensive-Overview-Summary-of-the-Project.md#7-left-to-do) | incl. the road to commercial use |
| 📋 Requirements | W3C XML 1.0 conformance; same behaviour as Expat 2.8.1 ([libexpat-parity.md](libexpat-parity.md), [libexpat-api-compatibility.md](libexpat-api-compatibility.md)) | |
| ❓ Questions for the supervisor | #304, #293, #211, #171, #13, licence, deployment ([HANDOVER.md](../student/HANDOVER.md)) | 🟡 to send in one batch |

## 2. Development history
*What changed, who changed it and why?*

| Artifact | Where | Numbers |
|---|---|---|
| 📝 Commits | `git log origin/incremental-test` | student: **790** GitHub commit contributions (460 xpact + 316 mass-xpact), 343 non-merge on `incremental-test` |
| 🌿 Branches | work branch **`incremental-test`**; one branch per fix (`fix/…`, `docs/…`, `perf/…`); `main` only by the supervisor | rules: [VERSIONING.md](../student/VERSIONING.md), [CLAUDE.md](../CLAUDE.md) |
| 🔀 Pull requests | [merged PRs](https://github.com/andersoxie/xpact/pulls?q=is%3Apr+is%3Amerged) | **214** by the student; merge commits only since 2026-11-12 (#318) |
| 👀 Code reviews | PR descriptions carry the test evidence; [TODO_CODE_REVIEW.md](../TODO_CODE_REVIEW.md) (July review); SonarQube and CodeQL on every PR | review comments from the supervisor: none received by 2026-11-17 |
| 🏷️ Versions | [CHANGELOG.md](../CHANGELOG.md), git tags `v0.1.0`-`v0.9.0` | next: tag the Unreleased section |
| 🔗 Issue → PR → report index | [reports/README.md](../reports/README.md) | one row per fix: issue, PR, branch, report |

**Trace one change, end to end (example #418):** issue [#418](https://github.com/andersoxie/xpact/issues/418) (why) → branch `fix/418-gobo-no-global-lock` → PR [#430](https://github.com/andersoxie/xpact/pull/430) (test evidence) → merge commit `49a8b2c` → report [gobo-dll §4](../reports/gobo-dll/README.md) → issue closed after local verification.

## 3. Testing and verification
*Does it work? What failed? What was fixed?*

| Test | Where | Latest result |
|---|---|---|
| ✅ W3C conformance (2,585 cases) | `scripts/run_w3c_conformance.py`, [reports/latest-2026-10-28](../reports/latest-2026-10-28/README.md) | **0 failed, 0 skipped**, both builds (rerun 2026-11-16, #407) |
| ✅ Same verdict as Expat | C# `tests/dotnet/XpactDllTests`, [G03](../student/results/G03-comparison/README.md) | 4,308 / 4,308 · 1,302 / 1,302 |
| ✅ W3C in pieces (Test 2) | `reports/issue-0165/tools/run.py --jobs 16` | 2,564 / 2,585 the same; result file `1feb6129…` unchanged |
| ✅ Eiffel test matrix | `scripts/run_eiffel_test_matrix.ps1` | 4 lanes pass |
| ✅ Python suite | `tests/python` | 239 tests |
| ✅ Speed | [fair speed](../student/results/fair-speed-2026-11-10/README.md), [perf-allocations](../reports/perf-allocations/README.md), [gobo-dll](../reports/gobo-dll/README.md) | ~17× slower than Expat; Gobo 0.92× ES; 4 threads 0.40 s |
| ✅ Website | `website/scripts/test.ps1`, [testing.md](../website/docs/testing.md), [security.md](../website/docs/security.md) | backend 48/48; attack battery 27/27 |
| ✅ Code quality | SonarQube ([setup](../reports/security-scan-2026-11-14/)), CodeQL, Dependabot, Gitleaks | gate passes: 0 issues, 0 hotspots, 81.8 % |
| 🟡 CI/CD | GitHub Actions (Python harness, website Docker, CodeQL) | Jenkins dropped 2026-11-03; Eiffel and W3C run locally |
| 📂 Error reports and logs | [reports/error-reports/](../reports/error-reports/), `reports/issue-NNNN/` | format: [CLAUDE.md](../CLAUDE.md) §1 |
| 📏 Baseline | [student/baseline/BASELINE.md](../student/baseline/BASELINE.md) | week 2 |
| 🔴 Known failures | the 15 open issues ([overview §4](Comprehensive-Overview-Summary-of-the-Project.md#4-open-issues-all-15)) | plus heap corruption under GC stress (mass-xpact#20) |

## 4. Technical documentation
*How does everything fit together?*

| Artifact | Where | State |
|---|---|---|
| 🏛️ Architecture | [design-overview.md](design-overview.md), website [architecture.md](../website/docs/architecture.md) | ✅ |
| 🧩 Diagrams | [docs/bon/](bon/) (BON class diagrams), mermaid diagrams in the reports | 🟡 not updated for the Gobo build |
| 🔌 API | [include/xpact.h](../include/xpact.h) (Expat 2.8.1 surface), [libexpat-api-compatibility.md](libexpat-api-compatibility.md), website [api.md](../website/docs/api.md) | 🔴 no generated API reference |
| 🛠️ Setup | [setup-guide.md](../student/report/setup-guide.md), [CONTINUE-HERE.md §4](../student/CONTINUE-HERE.md), website [development.md](../website/docs/development.md), [docker.md](../website/docs/docker.md) | ✅ |
| 🧱 Builds | [implementation-builds.md](implementation-builds.md), [platform-builds.md](platform-builds.md), Gobo: [gobo-dll](../reports/gobo-dll/README.md) | ✅ Windows; Linux 🔴 |
| 📖 Plain-words guide | [student/GUIDE.md](../student/GUIDE.md) | ✅ |

## 5. Project history and knowledge
*What have we learned? What decisions were made?*

| Artifact | Where | Notes |
|---|---|---|
| 🔍 Investigation reports | [reports/](../reports/README.md) (one folder per issue), [student/results/](../student/results/README.md), [initial investigation](../student/history/xpact-investigation-report-2026-10-13.md) | each with problem, cause (confirmed/suspected), fix, verification |
| ⚖️ Decision log | [decision-log.md](decision-log.md) | every decision with date, reason and where it is recorded |
| 🗓️ Work logs | [weekly notes](../student/notes/weekly/) (weeks 1-10), [docs/notes/](notes/README.md) | |
| 🐞 Known issues | [open issues](https://github.com/andersoxie/xpact/issues), [PLAN.md, Known problems](../student/PLAN.md) | |
| 🎓 Reports for the hand-in | [ActualReport.md](../student/report/ActualReport.md), [short](../student/report/ActualReportShorter.md), [overview](Comprehensive-Overview-Summary-of-the-Project.md), [HANDOVER.md](../student/HANDOVER.md) | hand-in 27 Nov 2026 |
| 🧊 Archive | [student/archive/](../student/archive/) (frozen to-do lists, e.g. TOOODOOO.txt) | read-only |

### Lessons learned (short)
- **Check the test, not only the code.** Several "green" results were not testing what they claimed (B01, #48, #130). Meta-tests and exit codes came first.
- **One frozen build, many tests.** Runners that rebuilt the DLL silently made results untraceable (#302, #319).
- **Measure on an idle PC, on charger, median of 3.** Battery power once made timings 2.5× slower.
- **Profile before guessing.** The Gobo callback cost was GC finalizers, not the suspected `eif_protect` (#428).
- **Keep expected and observed separate; mark causes as confirmed or suspected.** That kept the reports trustworthy.
