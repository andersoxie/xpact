# #325 · SonarQube issue 1: scan included frozen evidence folders

| | |
|---|---|
| Status | ✅ fixed; rescan result in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
| Issue | [#325](https://github.com/andersoxie/xpact/issues/325) |
| File | `sonar-project.properties` |

- **Problem:** the scan of 2026-11-12 01:01 (`7db9612`) indexed 7,928 files. 97 of its 196 issues were in `reports/` and `student/results/`: probe scripts and logs kept exactly as they were run. One of them does not even parse (`student/results/AlotOfTests-2026-10-28/08-encodings/run.py:52`), and the scanner tried to read a test XML log as code.
- **Cause:** ✅ confirmed: `sonar.sources=.` with exclusions only for build output.
- **Fix:** `sonar.exclusions` also lists `reports/**`, `student/results/**`, `**/node_modules/**`, `website/dist/**`. Evidence stays unchanged ("do not overwrite useful baseline evidence").

## Verification

See the rescan in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md): 0 issues under `reports/` or `student/results/`.
