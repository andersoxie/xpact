# Results

Evidence for **task work that is not a code fix**: investigations, orientation
notes, measurements and data sets, e.g. `A01-orientation/` or the
[`xmlconf-crashes-2026-10-14/`](xmlconf-crashes-2026-10-14/) analysis.

**Fixes do not go here.** A change to code, scripts or configuration keeps its
report and logs in `reports/issue-NNNN/` (see
[`reports/README.md`](../../reports/README.md) and
[`VERSIONING.md`](../VERSIONING.md)). If a task here leads to a fix, link this
folder from the fix's report.

One folder per task, named after its task ID, e.g. `A01-orientation/`. Link the
folder from the issue. Each folder starts with a `README.md` like this:

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
