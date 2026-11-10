# Report: mass-xpact #5: Test 2 ran one W3C case at a time

> **Issue:** [CodTanium/mass-xpact#5](https://github.com/CodTanium/mass-xpact/issues/5) · **Branch:** `perf/parallel-test2`, from `student-Mass` @ `253c81e`
> **Changed:** `reports/issue-0165/tools/run.py` (test harness only, no parser code)
> **Status:** ✅ fixed · ✅ verified: output byte-identical

## 1. In short

Test 2 now runs its cases on several worker pairs at once (`--jobs`, default one per CPU).
The output files are **byte-identical** to the sequential run.

| ✅ Result (production DLL with the #2 fix, 16 logical cores) | Before | After |
|---|---:|---:|
| Test 2 wall time | ~15 min 30 s | **5 min 02 s** |
| `chunked-<tag>.tsv` and `-summary.json` | | **byte-identical** (SHA-256 below) |

**Why not 16× faster:** two cases, `pr-xml-little` and `pr-xml-utf-16` (313 KB, UTF-16),
hit the **300 s per-case timeout** in every run, sequential or parallel. UTF-16 input still uses the old
full replay on each `XML_Parse` call (#2 resumes UTF-8 only), so byte-by-byte parsing is quadratic.
In the sequential run those two timeouts were 10 of the 15½ minutes. In the parallel run they run
side by side, and all other cases finish in about one minute next to them. Making UTF-16 resume is the
next parser step (separate issue).

## 2. Problem report

| Field | |
|---|---|
| **1. Problem** | Test 2 was sequential: one xpact and one Expat worker, one case at a time. |
| **2. Environment** | Windows 11, student PC2, 16 logical cores; Python 3.15 (uv); `build\fix1\native-eiffel\xpact.dll` (Production, `7c3eda4` of `perf/incremental-parsing`). |
| **3. Command** | `python -I reports\issue-0165\tools\run.py --dll <dll> --tag <tag> [--jobs N]` |
| **4. Expected** | Same rows, wall time divided by about the number of cores. |
| **5. Actual (before)** | ~15 min 30 s (measured on `0ff0615`, same speed as `7c3eda4`). |
| **6. Error output** | None. |
| **7. Investigation** | `run.py` looped over `w3c.cases()` with one `Pool` per engine. A first parallel version took 5 min 04 s; starting the most expensive cases first changed nothing (5 min 02 s). Timing the largest cases showed the two UTF-16 timeouts. |
| **8. Cause** | ✅ **Confirmed** in the code: no parallelism. The remaining floor is 🟡 the two UTF-16 timeouts (confirmed in the rows: `TIMEOUT`). |
| **9. Fix** | `--jobs N` threads, each with its own xpact and Expat worker process (`Pool` is not thread-safe). The most expensive cases (size² up to `--max-split-size`) start first. Rows and printed lines are written in suite order after all cases finish. |
| **10. Verification** | ✅ section 3. |

## 3. Verification

| Check | Result | Log |
|---|---|---|
| ✅ TSV, sequential (old `run.py`) vs `--jobs 16` (new) | **byte-identical**, SHA-256 `c054d7af…e34142` | [sequential](logs/chunked-sequential-before.tsv), [parallel](logs/chunked-parallel-jobs16.tsv), [sha256](logs/sha256.txt) |
| ✅ Summary | ok 2,562 · xpact-only 18 · both 5 · total 2,585, identical | [summary](logs/chunked-parallel-jobs16-summary.json) |
| ✅ Wall time | 5 min 04 s (submission in suite order), 5 min 02 s (largest first) | |

## 4. Limitations

- [ ] `--jobs 1` with the new code was not run separately; it uses the same code path with one thread.
- [ ] Printed non-ok rows now appear at the end of the run, not while it runs.
- [ ] Under load, a case near the 300 s timeout could time out in parallel but not sequentially; none did here.
- [ ] Only the Test 2 harness changed. `scripts/run_w3c_conformance.py` is still sequential (separate change: its summed `elapsed_ms` feeds the benchmark reports).
