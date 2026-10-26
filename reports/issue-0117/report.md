# Report: issue #117, xmlconf verdict rules (draft 12)

Issue: [#117](https://github.com/andersoxie/xpact/issues/117)   Branch: `fix/117-xmlconf-verdicts`   Base: `student-Mass` @ `76f539e`   Date: 2026-10-26

## In short

| | |
|---|---|
| Task | Draft 12: make `run_xmlconf_conformance.ps1` use the non-validating verdict rules of `run_w3c_conformance.py`, and compare before/after |
| Found | That script **never entered git**; the rules already live in `run_w3c_conformance.py` (#29), the runner Jenkins uses. Three of four boxes were done |
| Done | The last box: the 2026-10-14 observations re-scored with the runner's rules, compared with today. Results: [`student/results/xmlconf-verdicts/`](../../student/results/xmlconf-verdicts/README.md) |
| Result | **676 of the 854 old "failures" were wrong rules**; 233 real problems remained (173 malformed documents accepted, 47 crashes, 13 good documents rejected); **all 233 pass today** in both builds |

## Investigation

| Check | Command | Result |
|---|---|---|
| Is the old runner in git? | `git log --all --format=%h -- scripts/run_xmlconf_conformance.ps1` | nothing: never committed |
| Where is it? | `grep -rl run_xmlconf_conformance student` | `student/history/patches/01-…`, `02-…`; `student/baseline/README.md`: "Still missing from git" |
| The old observations | `student/baseline/logs/xmlconf-results.tsv` | 2,168 rows: 1,314 pass, 854 FAIL; 53 crash messages (45 scored pass) — matches `BASELINE.md` K5 |
| The correct rules | `expectation()` in `scripts/run_w3c_conformance.py` | `invalid` → ACCEPT; `error`, external entities, XML 1.1, other editions → skipped with a reason |

**Decision:** the old runner is recorded as superseded and not revived; a
second runner with the same rules would only add maintenance.

## What changed

| File | Change |
|---|---|
| `student/results/xmlconf-verdicts/rescore.py` | New. Imports `load_catalog()` / `expectation()` from the runner (not a copy), scores the baseline, adds today's status |
| `student/results/xmlconf-verdicts/cases.tsv`, `summary.md` | New, generated: 2,168 cases; the tables |
| `student/results/xmlconf-verdicts/README.md` | New: the answer in plain words, the rules side by side, how to repeat |
| `student/github/issues/12-xmlconf-verdicts.md` | Last box ticked; "Resolved 2026-10-26" |
| `student/PLAN.md`, `student/results/README.md`, `reports/README.md` | ticked / one row each |

## Expected results (written before the run)

| # | Check | Expected |
|---|---|---|
| 1 | Totals | every one of the 2,168 rows lands in exactly one class (pass, fail, crash, skipped, not in catalog) |
| 2 | Old `invalid` failures | become passes or skips (a non-validating parser accepts them) |
| 3 | Today | the cases that still fail under the right rules pass in both builds (W3C 1,727/1,727 on 2026-10-26) |

## Verification

Python 3.14.0; suite `xmlts20130923` in `build/validation-corpora/` of the
`xpact3.0` folder; today's `results.tsv` from the #110 run (`e8c5cb3`, MSVC).

| # | Command / check | Actual | |
|---|---|---|---|
| 1 | `python -I student/results/xmlconf-verdicts/rescore.py --suite-dir … --today …` | `2168 cases scored`, exit 0; 1,086 + 186 + 47 + 848 + 1 = **2,168** | ✅ |
| 2 | `invalid` rows that were FAIL | 144 → pass, 53 → skipped, 0 → fail as `invalid ACCEPT`; 8 `invalid` were *rejected* (real) | ✅ |
| 3 | the 233 real problems, today | **233 passed / passed** (`Finalized` / `FinalizedAssertions`) | ✅ |
| 4 | refactor for two SonarLint warnings, rerun | `cases.tsv` and `summary.md` byte-identical before and after | ✅ |
| 5 | link check | 0 broken | ✅ |

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 117 -Commit <merged sha>
```
