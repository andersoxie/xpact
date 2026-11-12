# #326 · SonarQube issue 2: `run_case` "expects a different type" (S5655) and loop capture (S1515)

| | |
|---|---|
| Status | ✅ fixed (no behaviour change); rescan in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
| Issue | [#326](https://github.com/andersoxie/xpact/issues/326) |
| File | `scripts/run_w3c_conformance.py` |

- **Problem:** SonarQube flagged `run_case(lane_case, …)` at lines 595 and 598 (S5655, critical) and the inner `run_one` reading the loop variables `engine` / `executable` (S1515).
- **Investigation:** `lane_case = replace(case, …)` uses `dataclasses.replace`, which returns a new object of the same class (`Case`). SonarQube's type inference does not know that and treats the result as a different type. `run_one` is only used by `pool.map` / `map` inside the same loop iteration, so it always sees that iteration's `engine`.
- **Cause:** ✅ confirmed false positive for S5655; S1515 is not a live bug (the closure never outlives its iteration), only fragile.
- **Fix:** a typed helper `lane_variant(case: Case) -> Case` wraps `replace`; `run_one` takes `engine` and `executable` as default arguments bound at definition time.

## Verification

| Command | Result |
|---|---|
| `python -m unittest discover -s tests/python -p "test_w3c*.py"` (uv CPython 3.15) | ✅ Ran 43, OK; includes `test_all_cases_runs_out_of_profile_cases_in_their_lanes`, which runs `main --all-cases` end to end through `lane_variant` |
| full Python suite | see [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
