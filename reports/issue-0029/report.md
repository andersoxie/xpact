# Fix report: issue #29, W3C suite with assertions off and on

Issue: [#29](https://github.com/andersoxie/xpact/issues/29)   Branch: `fix/29-w3c-assertions`   Base: `student-Mass` @ `2f0d441`   Date: 2026-10-21

## Why

The guide asks for assertions-enabled results, but the W3C suite had only been
run with the old `run_xmlconf_conformance.ps1` (2026-10-14), whose verdict
rules differ from the teacher's Python runner (draft 12). The Python runner
writes its reports under `build/`, which is gitignored, so a run leaves no
record in the repository.

No code, script or build setting is changed: this records results and updates
the student documents. The finding from the run is
[#28](https://github.com/andersoxie/xpact/issues/28).

## What changed

| File | Change |
|---|---|
| `student/results/w3c-conformance-2026-10-21/` | New. `README.md` (configuration, commands, results of both builds, breakdown, observations), `summary.md`/`summary.json` (runner output), `failures.tsv` (1,693 failed or crashed cases), `cr-lf.xml`/`lf.xml` (9-byte repro of #28 and its control), `.gitattributes` (`*.xml binary`, so `core.autocrlf` cannot remove the CR) |
| `reports/error-reports/2026-10-21.md` | New error report: five failures from the run |
| `student/github/issues/12-xmlconf-verdicts.md` | Section "Update 2026-10-21": the Python runner's numbers |
| `student/github/issues/21-finding-xmlconf-crashes.md` | Section "Update 2026-10-21": blocked by #28; `rmt-e3e-12` still shows |
| `student/github/README.md` | #28 and #29 in the list of issues created outside the drafts and in the labels table |
| `student/PLAN.md` | Last updated; W3C run under "Also done" and week 3; #28 under week 2 findings; "Next tests" with the five tests chosen from the guide |
| `student/PLAN2.md` | Two rows in "Tests run so far" |
| `reports/README.md` | Commit `2f0d441` for #26; rows for #29 and the error report |
| `tests/python/run_w3c_conformance.py` | New: copy of `scripts/run_w3c_conformance.py` next to its tests, without the `#!` line. The tests and `run_benchmarks.ps1` still use the `scripts/` copy |

Done on GitHub (not a file change): issues #28 (finding) and #29 (this task)
created with labels.

## The run

Recorded in [`student/results/w3c-conformance-2026-10-21/README.md`](../../student/results/w3c-conformance-2026-10-21/README.md).
The expected outcome of the run was not written down before it; the checks
below were.

| Build | Assertions | Passed | Failed | Errors | Skipped |
|---|---|---:|---:|---:|---:|
| `Finalized` | off | 1,491 | 236 | 0 | 858 |
| `FinalizedAssertions` | on | 270 | 97 | 1,360 | 858 |

## Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | Unit tests of the runner, `python tests\python\test_w3c_conformance.py` | 22 tests, OK |
| 2 | Second W3C run with both builds, no rebuild in between | Same numbers as the table above |
| 3 | `cr-lf.xml` and `lf.xml` as staged in git (`git show :<path>`) | Bytes and SHA-256 unchanged; `cr-lf.xml` still contains `0d` |
| 4 | Rows in `failures.tsv` | 236 + 97 + 1,360 = 1,693 |
| 5 | `tests/python/run_w3c_conformance.py` compared with `scripts/run_w3c_conformance.py` | Same apart from line 1 and line ends |
| 6 | Relative links in every changed Markdown file | All resolve |
| 7 | `cr-lf.xml` with both builds | Assertions off ACCEPT exit 0; assertions on crash in `normalized_input`, exit 1 |

## Verification

Clone `C:\xpact\xpact-student-Mass`, branch `fix/29-w3c-assertions`,
Windows PowerShell 5.1, Python 3.15.0, GitHub CLI 2.102.1.

| # | Command | Actual | Exit |
|---|---|---|---|
| 1 | `python tests\python\test_w3c_conformance.py` | `Ran 22 tests in 0.230s` `OK` | 0 |
| 2 | `python scripts\run_w3c_conformance.py --engine Finalized=... --engine FinalizedAssertions=... --timeout 10` (18:08:07-18:09:11; exe timestamps 17:34:16 and 17:33:59 before and after) | `Finalized` 1491/236/0/858, `FinalizedAssertions` 270/97/1360/858: identical to the run at 17:35 | 1 (failures expected) |
| 3 | `git show :student/results/w3c-conformance-2026-10-21/cr-lf.xml \| sha256sum` and `od -An -tx1` | `5b7e3147…2a9fed`, `3c 72 3e 0d 0a 3c 2f 72 3e`; `lf.xml` `7b5783c0…4881c5`, `3c 72 3e 0a 3c 2f 72 3e`; `git check-attr`: `binary: set` | 0 |
| 4 | `wc -l failures.tsv` minus header | `1693` | 0 |
| 5 | `diff --strip-trailing-cr <(tail -n +2 scripts/run_w3c_conformance.py) tests/python/run_w3c_conformance.py` | no output | 0 |
| 6 | Link check (regex over `](...)`, URL-decoded, `Test-Path` relative to the file) | Before this report: 1 broken, `issue-0029/report.md` (this file). After: 0 | - |
| 7 | `xpact_benchmarks.exe --conformance-file cr-lf.xml` / `lf.xml`, both builds | lf off: ACCEPT 0 · lf on: ACCEPT 0 · cr-lf off: ACCEPT 0 · cr-lf on: `Non-decreasing loop variant`, 1 | see left |

All expectations were met.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 29 -Commit <merged sha>
```

That only reverts the files. Issues #28 and #29 stay on GitHub; close #28 by
hand if the finding turns out to be wrong.

## Note on `fix.ps1`

`fix.ps1 start` stopped under Windows PowerShell 5.1: with
`$ErrorActionPreference = "Stop"`, git's stderr message "Already on
'student-Mass'" became an error. The same steps were run by hand (`git fetch
--prune origin`, `git switch student-Mass`, `git merge --ff-only`, `git switch
-c fix/29-w3c-assertions`). The script was not changed.
