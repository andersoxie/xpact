# #197: run the W3C-in-pieces test (test 2) on several cores

[← reports](../README.md) · issue [#197](https://github.com/andersoxie/xpact/issues/197) · status: ✅ **verified** (2026-11-15)

## Result

| | `--jobs 1` (one document at a time) | `--jobs 16` (16 worker pairs) |
|---|---:|---:|
| Round 1 | 149.1 s | 27.8 s |
| Round 2 | 148.4 s | 27.5 s |
| Round 3 | 148.3 s | 27.5 s |
| **Median** | **148.4 s** | **27.5 s** → **5.4× faster** |

- ✅ **Same results:** all 6 runs wrote byte-identical `chunked-*.tsv` and `-summary.json` files (SHA-256 compared).
- Summary of every run: ok 2,564 · xpact-only 16 · both 5 · total 2,585 (the same as the 8 Nov rerun).
- ✅ The parser and the results are unchanged; only the test runner is faster.

## Report

| Field | |
|---|---|
| **Problem** | Test 2 ([`reports/issue-0165/tools/run.py`](../issue-0165/tools/run.py)) ran the 2,585 documents one after another through one xpact/Expat worker pair. |
| **Environment** | Student PC, Windows 11, 16 logical cores; `incremental-test` @ `15be360`; production DLL `website/backend/native/xpact.dll` SHA-256 `adae03d2…a8a5`; Python 3.15; W3C suite `xmlts20130923.zip` (SHA-256 checked by `scripts/run_w3c_conformance.py`). |
| **Command** | `python -I reports/issue-0197/compare_jobs.py --dll website\backend\native\xpact.dll --jobs 16 --rounds 3` ([compare_jobs.py](compare_jobs.py)) |
| **Expected** | `--jobs N` gives exactly the same per-document results and row order as `--jobs 1`, several times faster. |
| **Actual** | Identical outputs in all 6 runs; median 148.4 s → 27.5 s. |
| **Investigation** | `run.py --jobs N` was already on `incremental-test` since `b28f5ff` (2026-11-03): one thread per job, each with its own xpact and Expat worker **process** (the harness `Pool` is not thread-safe), longest documents first, rows written in suite order. Branch `fix/197-parallel-test2` was an earlier, superseded attempt. What was missing: the equality check and the timing. |
| **Cause** | Confirmed: sequential runner. (Test 2 itself got faster since the issue was written, because the re-parse problem F05-1 was fixed: 20-25 min → 2.5 min sequential.) |
| **Fix** | No code change to `run.py`; [compare_jobs.py](compare_jobs.py) added as the repeatable check. |
| **Verification** | 3 alternating rounds on an otherwise idle PC ([timings.tsv](timings.tsv), [result.md](result.md)). |

## Limitations

- Timings are from one PC with 16 logical cores; with 6 cores (as in the issue) expect about 3-4×.
- The assertions build was not timed; the code path is the same.
