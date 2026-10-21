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
