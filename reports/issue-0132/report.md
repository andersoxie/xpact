# Report: issue #132, remove the old copy tests/python/run_w3c_conformance.py

Issue: [#132](https://github.com/andersoxie/xpact/issues/132)   Branch: `fix/132-remove-old-runner-copy`   Base: `student-Mass` @ `508d9c5`   Date: 2026-10-26

## In short

| | |
|---|---|
| Problem | `tests/python/run_w3c_conformance.py` was a copy of the W3C runner described in #29 and first committed in `8850dab` (#30), to sit next to its tests. It fell behind (361 lines vs 459) and nothing used it (#104) |
| Change | File removed; the one live doc that mentioned it (`docs/implementation-coverage.md`) updated. The old reports (#29, #32, #79, #104) are history and stay unchanged |
| Result | Python tests 178 run, OK (7 skipped), before and after |

## Investigation

| Check | Result |
|---|---|
| Who uses it? `grep -rn run_w3c_conformance` | the tests import `scripts/run_w3c_conformance.py` (`tests/python/test_w3c_conformance.py:27`); no script, test or Jenkinsfile uses the copy |
| Where did it come from? `git log -- tests/python/run_w3c_conformance.py` | first committed in `8850dab` (#30, student; described in the #29 report), last changed in `492c6eb` |

## Verification

Python 3.14.0 (`py -3.14`; this tool shell's default `python` is still 3.10, see #113).

| # | Command | Actual | |
|---|---|---|---|
| 1 | `py -3.14 -m unittest discover -s tests/python` before the change | `Ran 178 tests`, `OK (skipped=7)` ([log](python-before.txt)) | ✅ |
| 2 | the same after `git rm tests/python/run_w3c_conformance.py` | `Ran 178 tests`, `OK (skipped=7)` ([log](python-after.txt)) | ✅ |
| 3 | `grep` for the path in live docs and scripts | only `docs/implementation-coverage.md` (updated) and old reports | ✅ |

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 132 -Commit <merged sha>
```
