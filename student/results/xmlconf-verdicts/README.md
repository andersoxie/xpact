# xmlconf verdict rules: old baseline re-scored (2026-10-26)

> **Issue:** [#117](https://github.com/andersoxie/xpact/issues/117) (draft 12, "Fix xmlconf verdict rules")
> · **Date:** 2026-10-26 · **Code:** `student-Mass` @ `76f539e` · Nothing was run again and no runner changed.

## In short

| | |
|---|---|
| ❓ The question | On 2026-10-14 the old PowerShell runner reported **854 of 2,168** W3C cases as failures. How many were real parser bugs, and how many were wrong verdict rules? |
| 🔍 How | The same 2,168 observations, scored again with the rules of `scripts/run_w3c_conformance.py` (the runner Jenkins uses) |
| ✅ Answer | **676 of the 854 were wrong rules**: 144 `invalid` documents correctly accepted, 529 cases that must not be counted (old editions, XML 1.1, external entities, `error`), 3 crashes mis-scored. Under the right rules the real problems were **233** (173 malformed documents accepted, 47 crashes, 13 good documents rejected) |
| ✅ Today | **All 233 pass today**, in both finalized builds (assertions off and on) |

## The rules, side by side

From the student guide, "Read the expected outcome correctly":

| Catalog type | Old PowerShell runner | `run_w3c_conformance.py` (correct) |
|---|---|---|
| `valid` | ACCEPT | ACCEPT |
| `invalid` | **REJECT** ❌ (a non-validating parser must accept well-formed XML that only breaks DTD validity) | ACCEPT |
| `not-wf` | REJECT | REJECT |
| `error` | **a fixed verdict** ❌ | no required verdict: skipped |
| needs external entities | **run** ❌ (resolver off, so the result is meaningless) | skipped, with the reason |
| XML 1.1, other editions | **run** ❌ | skipped, with the reason |
| crashes | **counted as pass or fail** ❌ (45 of 53 as passes) | counted separately |

## Results

The full tables (with every count) are in [summary.md](summary.md); per case in [cases.tsv](cases.tsv).

| Score of the same 2,168 observations | Old rules | Correct rules |
|---|---|---|
| pass | 1,314 | 1,086 |
| fail | 854 | 186 |
| crash | (inside pass/fail: 53) | 47 |
| skipped (out of profile) | 0 | 848 |
| not in the catalog | 0 | 1 |

`not in the catalog`: `ibm-1-1-not-wf-P02-ibm02n13.xml`, an ID the old runner
wrote with `.xml`; it is an XML 1.1 case, so it would be skipped anyway.

The catalog has 2,585 cases; the old runner left out 418 (408 of them applicable).
Today's runner covers all 2,585: 1,727 passed, 858 skipped, 0 failed.

## The old PowerShell runner

`scripts/run_xmlconf_conformance.ps1` was a weeks 1-2 local script. It **never
entered git** (`git log --all -- scripts/run_xmlconf_conformance.ps1` is empty);
it survives in [`../../history/patches/01-week1-build-fixes.patch`](../../history/patches/01-week1-build-fixes.patch)
and [`02-week2-runner-changes.patch`](../../history/patches/02-week2-runner-changes.patch).
It is **superseded** by `scripts/run_w3c_conformance.py` and is not revived:
fixing it would give a second runner with the same rules.

## How to repeat

```powershell
# the suite is downloaded by run_benchmarks.ps1 / run_w3c_conformance.py into build\validation-corpora\
python -I student\results\xmlconf-verdicts\rescore.py `
  --suite-dir build\validation-corpora\w3c-xml-20130923\xmlconf `
  --today build\benchmarks\w3c-xml-conformance\results.tsv
```

Inputs: the baseline [`../../baseline/logs/xmlconf-results.tsv`](../../baseline/logs/xmlconf-results.tsv)
(2026-10-14, unchanged) and `results.tsv` of the run of 2026-10-26
([#110](../../../reports/issue-0110/report.md), `student-Mass` @ `e8c5cb3`, MSVC).
Python 3.11 or newer.

## Limitations

- The old observations are from a **workbench** `xpact.exe` with assertions on
  (2026-10-14, before #28 and #80); today's from **finalized** builds. The
  comparison is between rules on the same observations, then with today.
- A crash is recognised from the message (`system execution failed`, contract
  `violated`), as the 2026-10-14 crash analysis did.
