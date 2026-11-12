# #327 · SonarQube issue 3: `main()` always returns the same value (S3516, blocker)

| | |
|---|---|
| Status | ✅ fixed (no behaviour change); rescan in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
| Issue | [#327](https://github.com/andersoxie/xpact/issues/327) |
| File | `benchmarks/libexpat_py_benchmark.py` |

- **Problem:** `main() -> int` returned `0` on every path; errors already leave through `raise SystemExit("…")` (exit 1). SonarQube rates a function whose return value carries no information as a blocker.
- **Cause:** ✅ confirmed by reading the code: not a bug, a misleading signature.
- **Fix:** `main() -> None`; the script calls `main()` (exit status 0) instead of `raise SystemExit(main())`. The strings the Eiffel test `tests/xp_test_root.e:2676` looks for (`xml.parsers`, `EXPAT_VERSION`, `--file`) are unchanged.

## Verification

Run with uv CPython 3.15 (pyexpat `expat_2.8.5`):

| Command | Expected | Actual |
|---|---|---|
| `libexpat_py_benchmark.py --version` | prints version, exit 0 | ✅ `expat_2.8.5`, exit 0 |
| `--iterations 3 --mode callbacks` | 906 events (302 × 3), exit 0 | ✅ 906 callback events, exit 0 |
| `--iterations 3 --mode tokenizer` | 0 events, exit 0 | ✅ exit 0 |
| `--iterations 0` | error, exit 1 | ✅ exit 1 |

`run_benchmarks.ps1` and `run_large_xml_benchmarks.ps1` call it the same way (version string from stdout, exit code checked).
