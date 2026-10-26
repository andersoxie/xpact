# The whole project in plain words

> **Updated 2026-10-26 (week 4).** Read sections 1-3 once. After that you
> mostly need [section 7, what to do next](#7-what-you-do-next). The live
> status is in [PLAN.md](PLAN.md); this page explains how it all fits.
> ✅ works · 🔴 broken · 🟡 waiting

---

## 1. What this project is

xpact is an XML parser written in **Eiffel**. It pretends to be **Expat**, a
famous XML parser written in C, so C programs can use xpact without noticing.

```
C program  --XML_Parse()-->  xpact.dll  -->  Eiffel parser
           <--callbacks (start tag, end tag, text, ...)--
```

A parser has two jobs: **accept** correct XML and report the right events,
and **reject** broken XML with an error. libexpat 2.8.1 is the reference:
when you are unsure what the right answer is, Expat's answer counts.

## 2. Your job, and what is not your job

| ✅ Your job: testing and evidence | ❌ Not your job |
|---|---|
| Find inputs that make xpact go wrong | Repairing the parser (`src/`): the developers do that |
| Make them as small as possible | Merging into `main` (never) |
| Turn them into tests that fail now and pass when fixed | |
| Check the developers' fixes | |

To finish the 10 weeks you need: a reproducible baseline, an agreed set of
regression tests, one reviewed contribution, and a clear handover and report.

## 3. The one idea behind all the builds

Eiffel code has **contracts** (assertions): checks inside the code, like
"this loop must get closer to its end every round". When a check is false,
the program stops. That is **good**: it found a bug.

Every program can be built in two independent ways, so there are 4 builds:

| | assertions **off** (checks removed) | assertions **on** (checks run) |
|---|---|---|
| **workbench** (`W_code`, debug-style) | fast to compile | fast to compile |
| **finalized** (`F_code`, optimised) | like a release | release + checks |

- The compiler is `ec`; `ec -finalize` makes a finalized build.
- ⚠️ **Trap:** `ec -finalize` throws the assertions away unless you also give
  `-keep`. So "assertions on + finalized" without `-keep` is secretly off (K2).
- The policy: **assertions on is the build that matters.**

Why results differ so much: the W3C suite gives 0 crashes with assertions off
and 1,360 with assertions on. The bugs are in both builds; only the "on"
build checks for them.

## 4. The builds: which file makes which program

An `.ecf` file is a project file; a *target* inside it is one build of it.

| ECF file | Targets | Program, used for |
|---|---|---|
| `tests\xpact_tests.ecf` | `xpact_tests` (off), `xpact_tests_assertions` (on) | `xpact_tests.exe`: **the main test program** (`tests\xp_test_root.e`) |
| `benchmarks\xpact_benchmarks.ecf` | `xpact_benchmarks` (off), `…_assertions` (on) | `xpact_benchmarks.exe`: speed tests, and what the W3C runner calls (`--conformance-file FILE`) |
| `tests\xpact_native_library.ecf` | `xpact_native_library` (off), `…_assertions` (on) | `xpact.dll` / `xpact_assertions.dll`: **the C library** |
| `tests\xpact_native_runtime.ecf` | `…runtime` (on), `…_no_assertions` (off) | native runtime smoke test |
| `xpact.ecf` | `xpact` | `xpact.exe` command line tool (`--parse-file` only) |

Build output goes to `EIFGENs\` and `build\`; git ignores both.

## 5. The scripts and programs: which ones matter

Run from `C:\xpact\xpact-student-Mass` in PowerShell. For anything finalized
or native, load the C compiler once per window (see the [setup guide](report/setup-guide.md)):
`. .\scripts\import_msvc_environment.ps1`

**Use now**

| What | What it does |
|---|---|
| `scripts\run_eiffel_test_matrix.ps1` | Builds `xpact_tests` in the 4 builds and runs them. `-AssertionMode All\|Off\|On`, `-BuildMode All\|Workbench\|Finalized`. Finalized uses `-keep` (#48), every test runs even after a contract failure (#60), a failure exits nonzero in every build (#45). Set `XPACT_META_FAIL=assert` or `exception` to make it fail on purpose (B02, #46) |
| `scripts\run_w3c_conformance.py` | The official W3C suite (2,585 cases) against `xpact_benchmarks.exe`. Python is not on `PATH`, see [README](README.md#tools-on-this-pc-2026-10-21) |
| `tests\dotnet\XpactDllTests` 🆕 | **Tests the DLL like a C program:** 3,360 cases, every callback set and chunking. A crash only ends one case. See its [README](../tests/dotnet/XpactDllTests/README.md) |

**Use later (weeks 5-7)**

| What | What it does |
|---|---|
| `scripts\build_native_eiffel.ps1` | Builds the C library: `-BuildTier Production` (`xpact.dll`, default) or `Assertions` (`xpact_assertions.dll`) |
| `scripts\run_native_runtime_smoke.ps1` | Quick check that the DLL works from C |
| `scripts\run_chunked_crc_harness.ps1` | Feeds XML in chunks to xpact and/or Expat |
| `scripts\run_libexpat_adapter.ps1` | xpact vs Expat (G03) |

**Ignore for now:** `run_benchmarks.ps1`, `run_large_xml_benchmarks.ps1`,
`run_chunked_crc_corpus.ps1`, `run_incremental_shim_audit.ps1`,
`run_native_abi_tests.ps1`, `run_contributed_examples.ps1`, `build_native.ps1`,
`package_windows_release.ps1`, `run_phase1.ps1`.

**Your own tools:** `student\baseline\run_baseline.ps1` (the baseline, `-LogDir`
for a rerun) and `student\tools\fix.ps1` (broken in PowerShell 5.1: do its
steps by hand, [VERSIONING.md](VERSIONING.md#fixps1-in-windows-powershell-51)).

## 6. What works and what is broken

✅ **Works** (checked 2026-10-26 on `student-Mass` @ `e8c5cb3`, MSVC, assertions on and off,
[report](../reports/issue-0110/report.md)):

| What | Result |
|---|---|
| Eiffel test matrix, 4 lanes | all `xpact Phase 1 tests: ok` |
| Both DLLs and their smoke tests | ok (the old smoke crash, draft 07 / K3, is gone) |
| C# DLL tests | 3,360 / 3,360 on both DLLs, 0 crashes |
| W3C suite, both finalized builds | 1,727 / 1,727 |
| Python tests (3.14, long paths on) | 178 OK |

Fixed since 2026-10-22: #28 (CR), #3 (B03, `/>`), #38 (start handler), #39 (invalid UTF-8),
#40 (chunk ending with `<`), the DLL smoke crash and the 47 W3C crashes (#79, PR #80).

🟡 **Waiting** (the full list is in [PLAN.md, Known problems](PLAN.md#-known-problems-living-list)):

| | What | Why it matters |
|---|---|---|
| #73, #74, #79 | Fixed on the student PC, not yet confirmed on Jenkins | Jenkins is the supervisor's reference |
| #13 | The GC wrapper swallows exceptions (on hold) | an error inside it shows up as a different error |
| - | Jenkins "Eiffel Tests" turns green without printing a result | a green stage there proves nothing yet |

**Why the crashes mattered so much:** they stopped the run early and hid every other
bug behind them. With them gone, every test above now runs to the end.

## 7. What you do next

| | Step | Why | How |
|---|---|---|---|
| 1 | ✅ **B02** ([#46](https://github.com/andersoxie/xpact/issues/46)): one test that must fail | if a failing test still says "ok", no green result means anything | done 2026-10-22: `XPACT_META_FAIL`, every lane exits nonzero ([results](results/B02-meta-tests/README.md)) |
| 2 | ✅ **B01** ([#45](https://github.com/andersoxie/xpact/issues/45)): failures give a nonzero exit code | same reason | done 2026-10-22 with draft 06 (#60) ([results](results/B01-nonzero-exit/README.md)) |
| 3 | **Ask the supervisor** | decisions are theirs | [`for superviser.txt`](for%20superviser.txt), questions at the end |
| 4 | **G01** (week 4): 50-100 W3C cases | an agreed regression set | from `results.tsv`: passes and failures, both builds. Not started (2026-10-26) |
| 5 | **Expat comparison** (C03, C10, G03) | the error codes still need a real reference | needs an Expat 2.8.1 build |

✅ Already done of the five tests chosen on 2026-10-21: 1 (#28 regression
test), 3 (C02), 4 (C03, xpact side), 5 (C10, xpact side), all through the
[DLL tests](results/dll-tests-2026-10-22/README.md), and 2 (B02, #46) on 2026-10-22.

## 8. How to do one piece of work (every time)

1. One GitHub issue per problem or task, with a milestone and labels.
2. Branch `fix/<issue>-<name>` from `student-Mass` (never work on `main`).
3. Write down the **expected** result **before** you run anything.
4. Run it. Save the log. Write down the actual result and the exit code.
5. Report in `reports\issue-NNNN\report.md`, logs next to it.
6. Pull request into `student-Mass`; **you** review and squash-merge it.
7. Check the result, then close the issue by hand; update [PLAN.md](PLAN.md) and the weekly note.

Every result records: the input (or its hash), the git commit, the build and
assertion setting, callbacks, chunk sizes, expected vs actual, the exact
command, the exit code. "It finished" or "it printed ok" is **not** proof.

## 9. Where things are

| File | What |
|---|---|
| [`CLAUDE.md`](../CLAUDE.md) | Your rules for reports, issues and pull requests |
| [`docs/xpact-student-introduction.md`](../docs/xpact-student-introduction.md) | The assignment: plan, task register |
| [PLAN.md](PLAN.md) | Live plan, known problems, next steps |
| [`for superviser.txt`](for%20superviser.txt) | One page for the supervisor |
| [baseline/BASELINE.md](baseline/BASELINE.md) | Week 2 results, K1-K5 |
| [results/](results/README.md) | Evidence of test runs |
| [`reports/README.md`](../reports/README.md) | Every fix and task, with its report |
| `src\xp_parser.e` | The parser (read, don't change) |
| `tests\xp_test_root.e` | The main tests (you add tests here) |
| `tests\native\`, `tests\dotnet\` | Programs that test the DLL |

## 10. Words

| Word | Meaning |
|---|---|
| assertion / contract | A check written in the code; when it fails, possibly a bug |
| loop variant | A number that must go down every loop round; if not, assertions-on builds stop (#28, B03) |
| workbench / finalized | Debug-style build / optimised build |
| `-keep` | Keep assertions in a finalized build |
| lane / cell | One of the 4 build combinations in the matrix |
| ECF / target | Project file / one build defined in it |
| DLL | The C library (`xpact.dll`, `xpact_assertions.dll`) |
| callback / handler | Your code that the parser calls for each event |
| chunk | A piece of the input given to one `XML_Parse` call |
| final / non-final | "This is the last piece" or "more is coming" |
| well-formed / not-wf | Correct XML / broken XML (must be rejected) |
| regression test | A test that keeps a fixed bug from coming back |
| exit code | 0 = success, anything else = failure |
| A01…H06, K1…K5 | Task IDs from the guide / known problems from week 2 |
| stacked pull request | A pull request whose base is another open pull request's branch |
