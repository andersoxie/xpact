---
title: Fix xmlconf verdict rules (invalid -> accept; skip error, external entities, XML 1.1)
labels: group:G-verification, D2-guided, P1, type:task
milestone: Week 4 - Input matrix
---
## Goal
Make `scripts/run_xmlconf_conformance.ps1` use the same non-validating verdict rules as the teacher's Python runner (`scripts/run_w3c_conformance.py`).

## Why
In the baseline from 2026-10-14, 854 of 2,168 cases mismatched. But the runner expects REJECT for `invalid` cases, which a non-validating parser should accept (guide, "Read the expected outcome correctly"). It also runs cases that need external entities and XML 1.1. So the 854 figure cannot be compared with the Python runner.

Breakdown: not-wf 527 (129 need external entities), invalid 197, valid 115 (86 need external entities), error 15.

Earlier observations (error report, sections 6.2, 6.3 and 7.1):
- The Python runner appeared to pass while this runner reported 852 failures. The verdict rules are the main difference.
- `rmt-e2e-2a` (duplicate ATTLIST token `(one|one)`) is accepted. It is an *invalid* case, so a non-validating parser is **right** to accept it. With the fixed rules it should pass.
- 53 cases crash rather than reject, and 45 of them are counted as passes (see the crash finding). The fixed runner must report crashes separately.

## Update 2026-10-21

The Python runner was run for the first time (#29,
`student/results/w3c-conformance-2026-10-21/`). With its rules, 1,727 of the
2,585 catalog cases apply and 858 are skipped with a reason. Assertions off:
1,491 passed, 236 failed (220 `not-wf` accepted, 9 `invalid` and 7 `valid`
rejected), 0 crashes. Assertions on: 1,360 crashes, 1,357 of them #28. These
are the numbers to compare this runner with after the fix.

## Done when
- [ ] `invalid` -> expected ACCEPT; `error` -> no required verdict (reported, not counted as a failure)
- [ ] Cases that need external entities or XML 1.1 are skipped and counted separately
- [ ] Totals reconcile: passed + failed + skipped = cases
- [ ] Before/after summary compared with the Python runner in `student/results/xmlconf-verdicts/`
