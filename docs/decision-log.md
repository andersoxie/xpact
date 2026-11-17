# Decision log

> Every project decision that changes how we work or what XPact does: **when, what, why, and where it is recorded.** Newest first.
> Map of all project knowledge: [PROJECT-KNOWLEDGE.md](PROJECT-KNOWLEDGE.md) · live status: [CONTINUE-HERE.md](../student/CONTINUE-HERE.md)

**Who:** S = student · SV = supervisor · S+SV = agreed

| Date | Decision | Why | Who | Record |
|---|---|---|---|---|
| 2026-11-17 | Docs are organised by five traceability areas (planning, history, testing, technical, knowledge) | one map from question to evidence | S | [PROJECT-KNOWLEDGE.md](PROJECT-KNOWLEDGE.md), #438 |
| 2026-11-17 | Unticked boxes in frozen reports and dated notes stay as they are; only live files get ticked, each with evidence | the frozen files are evidence of what was known then | S | #436 |
| 2026-11-16 | Global bridge lock removed **only in the Gobo build**; EiffelStudio build keeps it; `XPACT_GLOBAL_LOCK=1` restores it | Gobo's runtime is multi-threaded, EiffelStudio's is not (#304) | S | [#418](https://github.com/andersoxie/xpact/issues/418), [gobo-dll §4](../reports/gobo-dll/README.md) |
| 2026-11-16 | Callback strings are reused (fresh only when a callback re-enters) | profile: per-callback `C_STRING` finalizers were the cost | S | [#428](https://github.com/andersoxie/xpact/issues/428) |
| 2026-11-16 | Gobo GC tuning is set inside the DLL; environment variables still override | no setup needed by the caller | S | #428 |
| 2026-11-16 | The Gobo runtime starts on the first `XML_ParserCreate*`, not in `DllMain` | Boehm's marker threads hang under the Windows loader lock | S | [#414](https://github.com/andersoxie/xpact/issues/414) |
| 2026-11-16 | Eric Bezault's quoted `eif_misc.h` include adopted in `src/` | makes the shared Gobo ECF build on Windows | S+SV | [#409](https://github.com/andersoxie/xpact/issues/409) |
| 2026-11-16 | One live status page; issues are the to-do list; older to-do lists frozen in `student/archive/` | status was spread over 6+ files that disagreed | S | [#422](https://github.com/andersoxie/xpact/issues/422) |
| 2026-11-15 | No commits or GitHub actions until the student says so, per batch | the student reviews every batch | S | CONTINUE-HERE rules |
| 2026-11-12 | Aikido checksum alerts put aside (14, false positives) | not real findings; dashboard work only | S | PLAN.md |
| 2026-11-11 | Merge with a merge commit, never squash; `fix.ps1` follows | squash merges lost history and could not be reverted | S | [#318](https://github.com/andersoxie/xpact/issues/318), [CLAUDE.md](../CLAUDE.md) |
| 2026-11-11 | Build once, test many: frozen DLL (`XPACT_FROZEN_DLL=1`), SHA-256 shown | runners rebuilt the tested DLL silently | S | [#302](https://github.com/andersoxie/xpact/issues/302), [#319](https://github.com/andersoxie/xpact/issues/319) |
| 2026-11-11 | DLL thread safety by one global lock (calls take turns) | the EiffelStudio runtime is single-threaded; parallel parsing is a 1.0 question | S | [#274](https://github.com/andersoxie/xpact/issues/274), PR #303, [#304](https://github.com/andersoxie/xpact/issues/304) |
| 2026-11-11 | An Eiffel exception in a DLL call returns an error code instead of ending the process | a library must never kill its caller | S | [#273](https://github.com/andersoxie/xpact/issues/273) |
| 2026-11-10 | Semantic versions assigned afterwards (0.1.0-0.9.0) as git tags | nobody could tell which state had which fixes | S | [#265](https://github.com/andersoxie/xpact/issues/265), [CHANGELOG.md](../CHANGELOG.md) |
| 2026-11-10 | Website upload limit raised to 10 MB (parser limit) | the 1 MB site limit refused documents the parser accepts | S | [#267](https://github.com/andersoxie/xpact/issues/267) |
| 2026-11-08 | Work branch moves to `incremental-test`; `student-Mass` contained in it and deleted | one branch shared with the supervisor | S+SV | [CONTINUE-HERE.md §1](../student/CONTINUE-HERE.md) |
| 2026-11-03 | Jenkins dropped; issues are closed after local verification | Jenkins results could not be relied on and blocked work | S+SV | #262, #130 (closed as not planned), #277 |
| 2026-11-02 | Website hosting, HTTPS and domain belong to the supervisor | the server is the supervisor's | SV | [#210](https://github.com/andersoxie/xpact/issues/210) |
| 2026-10-27 | Run all 2,585 W3C cases, no skips (Option A) | skipped cases hid 7 parser bugs | S+SV | [#146](https://github.com/andersoxie/xpact/issues/146) |
| 2026-10-22 | Failing tests must return a nonzero exit code; meta-tests prove it | earlier "all green" results were not trustworthy | S | [#45](https://github.com/andersoxie/xpact/issues/45), [#46](https://github.com/andersoxie/xpact/issues/46) |
| 2026-10-20 | B03 (#3, #12, #13) put on hold | needs design input; other work first | S | [#26](https://github.com/andersoxie/xpact/issues/26) |
| 2026-10-14 | Never merge into `main` or touch it; Expat 2.8.1 is the reference behaviour | `main` is the supervisor's; Expat is the standard | SV | [CLAUDE.md](../CLAUDE.md), [README.md](../README.md) |

**Open decisions (supervisor):** parallel parsing for 1.0 and one parse per core (#304, #432) · entity depth > 32 (#293) · billion-laughs speed (#211) · error column and GC exceptions (#171, #13) · licence · deployment (#210) · 10 MB input limit.
