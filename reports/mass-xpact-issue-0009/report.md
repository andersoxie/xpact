# Report: mass-xpact #9: the W3C conformance runner ran one case at a time

> **Issue:** [CodTanium/mass-xpact#9](https://github.com/CodTanium/mass-xpact/issues/9) · **Branch:** `perf/parallel-w3c-runner`, from `student-Mass` @ `253c81e`
> **Changed:** `scripts/run_w3c_conformance.py`, `tests/python/test_w3c_conformance.py` (test tooling only)
> **Status:** ✅ fixed · ✅ verified

## 1. In short

`run_w3c_conformance.py --jobs N` runs N cases at the same time. The default stays **1**.

| ✅ Result (2,585 cases, finalized `xpact_benchmarks.exe`, 16 logical cores) | `--jobs 1` | `--jobs 16` |
|---|---:|---:|
| Wall time | 40 s | **9 s** |
| `results.tsv` without `elapsed_ms` | | **byte-identical** (SHA-256 `4ba3e69f…d2ef53`) |
| Summary: passed / failed / errors / skipped | 1,974 / 0 / 0 / 611 | **same** |
| Summed per-case `elapsed_ms` | 34,612 ms | 64,043 ms |

**Why the default stays 1:** the summed `elapsed_ms` is published by `run_benchmarks.ps1`. With
parallel jobs each case shares the CPU with the others, so that number grows (34.6 s → 64.0 s) and is no
longer comparable with earlier runs. Use `--jobs` for quick verification runs.

## 2. Problem report

| Field | |
|---|---|
| **1. Problem** | One parser process per case, started one after another. |
| **2. Environment** | Windows 11, student PC2, Python 3.15 (uv); engine `EIFGENs\xpact_benchmarks\F_code\xpact_benchmarks.exe` (built 2026-10-27). |
| **3. Command** | `python -I scripts\run_w3c_conformance.py --engine xpact=<exe> --output-dir build\w3c-jobs<N> --jobs <N>` |
| **4. Expected** | Same results, less wall time. |
| **5. Actual (before)** | 40 s, one core busy. |
| **6. Error output** | None. |
| **7. Investigation** | `main` called `run_case` (one `subprocess.run`) per case in a loop. |
| **8. Cause** | ✅ **Confirmed** in the code. |
| **9. Fix** | `--jobs N` (≥ 1, default 1). With N > 1 the cases run on a thread pool (`map` keeps catalog order) and every job gets its own work directory, so parallel crashes never share an `exception_trace.log`. With N = 1 the code path is the old one: the same calls in the same order. |
| **10. Verification** | ✅ Section 3. |

## 3. Verification

| Check | Result | Log |
|---|---|---|
| ✅ Unit tests `tests/python/test_w3c_conformance.py` | 43 / 43 (2 new: `--jobs 4` = `--jobs 1` in catalog order; `--jobs 0` rejected) | [unittest](logs/unittest.txt) |
| ✅ Real run, `--jobs 1` vs `--jobs 16` | results identical except `elapsed_ms` | [jobs 1](logs/results-no-elapsed-jobs1.tsv), [jobs 16](logs/results-no-elapsed-jobs16.tsv), [sha256](logs/sha256.txt) |
| ✅ Summaries | same counts | [jobs 1](logs/summary-jobs1.json), [jobs 16](logs/summary-jobs16.json) |

## 4. Limitations

- [ ] Only the default lane was run for real; `--all-cases` with `--entity-engine` was covered by the unit tests only.
- [ ] `run_benchmarks.ps1` does not pass `--jobs`; it keeps the sequential run.
- [ ] Progress lines (`250/2585`) appear when cases finish in catalog order, not as each one ends.
