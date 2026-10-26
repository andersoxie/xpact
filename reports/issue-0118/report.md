# Report: issue #118, G01 corpus manifest and reviewed W3C cases

Issue: [#118](https://github.com/andersoxie/xpact/issues/118)   Branch: `fix/118-g01-corpus`   Base: `student-Mass` @ `c532e81`   Date: 2026-10-26

## In short

| | |
|---|---|
| Task | G01 (draft 11): a portable corpus manifest with sources, versions, hashes, dependencies and expectations; 50-100 reviewed W3C cases |
| Result | [`student/results/G01-corpus/`](../../student/results/G01-corpus/README.md): **93 cases**, 83 counted (46 accept, 37 reject) + 10 marked not counted; 93/93 pass the review; the 83 pass today in both builds |
| Deviation | The task says "selected **with the supervisor**". The student decided to skip that; the manifest and draft 11 say "selected by the student, not reviewed by the supervisor" |

## What changed

| File | Change |
|---|---|
| `student/results/G01-corpus/make_manifest.py` | New. Reads the catalog with the runner's `load_catalog()` (records the catalog attributes while it reads), selects per category, writes the manifest and summary; `--check` verifies paths and SHA-256 |
| `student/results/G01-corpus/manifest.tsv`, `summary.md` | New, generated |
| `student/results/G01-corpus/README.md` | New: what is in it, how it was chosen and reviewed, how to repeat, limitations |
| `student/github/issues/11-G01.md` | the 4 boxes ticked with evidence; the supervisor deviation stated |
| `student/PLAN.md`, `student/notes/weekly/week-04.md`, `student/results/README.md`, `reports/README.md` | ticked / one row each |

## Expected results (written before the runs)

| # | Check | Expected |
|---|---|---|
| 1 | Number of cases | 50-100, both ACCEPT and REJECT in every category where both exist |
| 2 | Review column | `ok` for every case: expected outcome follows the guide's table; counted cases `passed`, marked ones `skipped` in both of today's builds |
| 3 | `--check` on the suite the manifest was made from | 0 differences, exit 0 |
| 4 | `--check` on a copy with one file changed | that one case reported, exit 1 |
| 5 | Rerun | the same manifest |

## Verification

Python 3.14.0; suite `xmlts20130923` in `build/validation-corpora/` of the
`xpact3.0` folder (root catalog SHA-256 `a10d3fc4…fd52`, as pinned in the runner);
today's `results.tsv` from #110 (`e8c5cb3`, MSVC).

| # | Command | Actual | Exit | |
|---|---|---|---|---|
| 1 | `python -I student/results/G01-corpus/make_manifest.py --suite-dir … --today …` | `93 cases written; review ok: 93`; 83 counted (46/37), 10 marked; 9 counted categories with both verdicts, `invalid` and `largest` accept-only by nature | 0 | ✅ |
| 2 | `review` column | 93 `ok` | - | ✅ |
| 3 | `… --check --suite-dir <the suite>` | `93 cases checked, 0 missing or different` | 0 | ✅ |
| 4 | `… --check` on a copy with one byte appended to `rmt-ns10-001` | `1 missing or different: rmt-ns10-001` | 1 | ✅ |
| 5 | rerun after a code-style fix (2 SonarLint warnings) | `manifest.tsv` byte-identical | 0 | ✅ |
| 6 | 5 cases read by eye | all 5 right (listed in the README) | - | ✅ |
| 7 | link check | 0 broken | - | ✅ |

**Corrected during the work:** a first version had only 7 encoding cases (2
accept); the category now also looks at the file itself (UTF-16 byte order
mark, non-UTF-8 encoding declaration): 10, balanced. A README statement that all
12 Japanese cases need external entities was checked and corrected (6 do; 6 are
`error` cases).

## Limitations

See the README: not reviewed by the supervisor; "reviewed" = rules, catalog and
today's runs plus 5 by eye; no current failure in the set; verdicts only (34
canonical outputs linked for a later event check).

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 118 -Commit <merged sha>
```
