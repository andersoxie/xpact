# Results

Evidence for **task work that is not a code fix**: investigations, orientation
notes, measurements and data sets, e.g. `A01-orientation/` or the
[`xmlconf-crashes-2026-10-14/`](xmlconf-crashes-2026-10-14/) analysis.

**Fixes do not go here.** A change to code, scripts or configuration keeps its
report and logs in `reports/issue-NNNN/` (see
[`reports/README.md`](../../reports/README.md) and
[`VERSIONING.md`](../VERSIONING.md)). If a task here leads to a fix, link this
folder from the fix's report.

## What is here

| Folder | Date | What | Issue |
|---|---|---|---|
| [`xmlconf-crashes-2026-10-14/`](xmlconf-crashes-2026-10-14/README.md) | 2026-10-14 | 53 W3C cases crash `xpact.exe` with contract violations (old PowerShell runner, workbench) | draft [21](../github/issues/21-finding-xmlconf-crashes.md) |
| [`w3c-conformance-2026-10-21/`](w3c-conformance-2026-10-21/README.md) | 2026-10-21 | W3C suite with the Python runner, assertions off and on: 1,491/1,727 passed off; 1,360 crashes on; 9-byte repro of the CR crash | [#29](https://github.com/andersoxie/xpact/issues/29), [#28](https://github.com/andersoxie/xpact/issues/28) |
| [`A02-baseline/`](A02-baseline/README.md) | 2026-10-22 | Week 2 baseline rerun in the git clone at `1799b35`: every step as expected; the assertions-on lanes now stop at the #28 regression test | [#33](https://github.com/andersoxie/xpact/issues/33) |
| [`dll-tests-2026-10-22/`](dll-tests-2026-10-22/README.md) | 2026-10-22 | C02, C03, C10 (part) through the DLL's C API: 3,360 cases on `xpact_assertions.dll` (637 pass, 1,329 crash), the same with only the B03 fix (928 pass, 672 crash) and `xpact.dll` (1,200 pass). Three new findings | [#37](https://github.com/andersoxie/xpact/issues/37) · [#38](https://github.com/andersoxie/xpact/issues/38), [#39](https://github.com/andersoxie/xpact/issues/39), [#40](https://github.com/andersoxie/xpact/issues/40) |
| [`xmlconf-verdicts/`](xmlconf-verdicts/README.md) | 2026-10-26 | The 2026-10-14 xmlconf results re-scored with the runner's rules: 676 of 854 "failures" were wrong rules; the 233 real problems all pass today | [#117](https://github.com/andersoxie/xpact/issues/117) |
| [`expat-2.8.1/`](expat-2.8.1/README.md) | 2026-10-26 | xpact vs Expat 2.8.1 through the C API: 4,308 cases on Expat's `libexpat.dll` and both xpact DLLs; all verdicts the same; 5 findings | [#121](https://github.com/andersoxie/xpact/issues/121) · [#122](https://github.com/andersoxie/xpact/issues/122)-[#126](https://github.com/andersoxie/xpact/issues/126) |
| [`C03-chunks/`](C03-chunks/README.md) | 2026-10-26 | C03: chunking vs Expat; 6 byte-exact fixtures | [#121](https://github.com/andersoxie/xpact/issues/121) |
| [`C10-utf8/`](C10-utf8/README.md) | 2026-10-26 | C10 (part): malformed UTF-8 vs Expat; 42 byte-exact fixtures | [#121](https://github.com/andersoxie/xpact/issues/121) |
| [`C02-final-input/`](C02-final-input/README.md) | 2026-10-26 | C02: the #38-#40 inputs as permanent tests (DLL smoke test, Eiffel suite); proven to fail with the fixes undone | [#128](https://github.com/andersoxie/xpact/issues/128) |
| [`G01-corpus/`](G01-corpus/README.md) | 2026-10-26 | G01: corpus manifest of 93 W3C cases (83 counted, 10 marked), with hashes, dependencies and reviewed expected outcomes; all pass today | [#118](https://github.com/andersoxie/xpact/issues/118) |
| [`A04-loaded-library/`](A04-loaded-library/README.md) | 2026-10-31 | A04: 16 runners under a load watcher, every loaded DLL identified by SHA-256: **15 load the expected library**, no stale copy anywhere; Expat's C tests without `-XpactLibrary` link the bridge-only DLL | [#168](https://github.com/andersoxie/xpact/issues/168) · [#179](https://github.com/andersoxie/xpact/issues/179), [#180](https://github.com/andersoxie/xpact/issues/180) |

Add a row for every new folder.

## A new folder

One folder per task, named after its task ID (e.g. `A01-orientation/`) or after
its topic and date (e.g. `w3c-conformance-2026-10-21/`). Link the folder from
the issue. Each folder starts with a `README.md` like this:

```markdown
# A02 - Reproduce assertions-enabled workbench and finalized builds

Issue: #<n>   Revision: <git rev-parse HEAD>

## Configuration
Build: workbench / finalized (-keep)   Assertions: pre/post/check/invariant on
Compiler: ISE_C_COMPILER=<value>   Callbacks: <which>   Chunks: <sizes>

## Runs
| # | Command | Input (or sha256) | Expected | Actual | Exit |
|---|---|---|---|---|---|
| 1 | `...` | `...` | nonzero | 0 | 0 |

## Observations
Facts only.

## Possible explanations
Clearly marked as not yet confirmed.
```

Put the full logs next to it (`before.log`, `after.log`, ...). Store byte-exact
inputs, such as invalid UTF-8, as files and never as copied text.
