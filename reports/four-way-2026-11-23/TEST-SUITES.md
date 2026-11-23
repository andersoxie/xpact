# XPact test suites: what they test and how to reproduce them

**What:** every test suite used to check XPact, what each one proves, how big it is, and the one command that reproduces it. Written for a reviewer who wants to re-run the results.
**Where:** this file is `reports/four-way-2026-11-23/TEST-SUITES.md`; the results of the last full run are in [REPORT.md](REPORT.md) and [scripted-run/](scripted-run/).
**Status:** all suites below were run on 23 November 2026 on `main` @ `2862a18` (except the Gobo XML parser comparison, run 18 November, #442).

**Legend:** ✅ passed · ❌ failed · 🚫 not part of the one-command run (the note says why)

## 1. Reproduce everything with one command

```powershell
git clone https://github.com/andersoxie/xpact.git; cd xpact; git checkout incremental-test
.\benchmarks\four_way\run_four_way.ps1          # ~25 min; results in reports\four-way-<date>\
.\benchmarks\four_way\run_four_way.ps1 -SkipLinux   # Windows only (no WSL needed)
```

How it works, in short:
1. **Build** the parser test programs with EiffelStudio and the MSVC C compiler (`scripts\build_implementations.ps1`, `scripts\build_native_eiffel.ps1`).
2. **Run each suite** as its own step in a fresh PowerShell. Every step writes `logs\NN-name.log`, and its exit code and minutes go to `logs\00-steps.tsv`. A failing step is recorded and the run goes on.
3. **Linux half:** the same script calls `benchmarks\four_way\wsl_four_way.sh` inside WSL (Ubuntu 24.04). It builds xpact with the Gobo compiler and with Linux EiffelStudio, then runs W3C, regression and speed for Gobo, Linux expat and all four parsers.
4. **Tables:** `summarize_four_way.py` merges every parser's W3C verdicts into one table; `expat_lenient_cases.py` explains expat's differences.

Every parser gets the **same input files and the same expected answer**. The test programs are thin adapters that print one line per document (`ACCEPT`/`REJECT`) or one line per parser event, so the judging code is shared.

## 2. The suites

| # | Suite | What it proves | Size | Command (repo root) | Last result | Docs |
|---|---|---|---|---|---|---|
| 1 | **W3C XML Conformance Test Suite** (xmlts 20130923), profile XML 1.0 5th ed. | The parser accepts every well-formed document and rejects every broken one, as the XML standard says | 1,974 cases run, 611 excluded by profile | `.\scripts\run_dual_w3c.ps1` | ✅ 1,974 / 1,974 | [w3c-xml-conformance](../../docs/w3c-xml-conformance.md), [dual-w3c-lane](../../docs/dual-w3c-lane.md) |
| 2 | **W3C, all cases** | No crash or wrong verdict on *every* case of the suite, including the excluded ones | 2,585 cases | `.\scripts\run_benchmarks.ps1 -EiffelBuild FinalizedAssertions -W3cAllCases` | ✅ 0 failed, 0 errors | [benchmarks](../../docs/benchmarks.md) |
| 3 | **Dual regression** | Same parser events whether the document comes whole, split at every byte position, or one byte at a time (incremental parsing) | 910 runs + 10 lifecycle steps | `.\scripts\run_dual_regression.ps1` | ✅ 910 / 910 | [dual-regression-lane](../../docs/dual-regression-lane.md) |
| 4 | **Dual catalog** (speed + qualification) | Throughput of xpact vs xpact-core on the same catalog workload, after checking both give the same output | 1 workload, repeated | `.\scripts\run_dual_catalog.ps1` | ✅ ratio 2.05 | [dual-catalog-lane](../../docs/dual-catalog-lane.md) |
| 5 | **libexpat 2.8.1 unit suite** through xpact's C interface | XPact can replace libexpat: libexpat's own tests run against xpact's DLL | 399 checks, 38 listed expected failures | `.\scripts\run_libexpat_adapter.ps1 -ExpatSourceDir C:\xpact\deps\libexpat -Mode All` then `-Mode NativeSuite` | ✅ gate passed (361/399) | [libexpat-parity](../../docs/libexpat-parity.md), [libexpat-api-compatibility](../../docs/libexpat-api-compatibility.md) |
| 6 | **Eiffel test matrix** (`tests/xp_test_root.e`, AutoTest) | XPact's own unit and integration tests, in 4 build modes | 4 modes × the full Eiffel suite | `.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode Off\|On -BuildMode Workbench\|Finalized` | ❌ 1 doc assertion, all 4 modes | [test-matrix](../../docs/test-matrix.md) |
| 7 | **C# DLL tests** (`tests/dotnet/XpactDllTests`) | The DLL behaves like libexpat when called from C (P/Invoke on the Expat C API), whole and chunked | 4,308 cases | `dotnet build tests\dotnet\XpactDllTests -c Release` then `build\dotnet\XpactDllTests\bin\Release\net10.0\XpactDllTests.exe` | ✅ 4,308 / 4,308 | [README](../../tests/dotnet/XpactDllTests/README.md) |
| 8 | **Chunked CRC harness + corpus** | A checksum of all events is identical for whole and chunked input | harness + corpus files | `.\scripts\run_chunked_crc_harness.ps1`, `.\scripts\run_chunked_crc_corpus.ps1` | ✅ | [chunked-parse-crc](../../docs/chunked-parse-crc.md) |
| 9 | **Native ABI tests** (`tests/native/*.c`) | The C header `include/xpact.h` works from plain C, on Windows and Linux | 6 C programs | `.\scripts\run_native_abi_tests.ps1` (needs a WSL default distro with bash) | ✅ | [platform-builds](../../docs/platform-builds.md) |
| 10 | **Native runtime smoke** | The DLL loads and parses in a clean process | smoke | `.\scripts\run_native_runtime_smoke.ps1` | ✅ | [drop-in-verification](../../docs/drop-in-verification.md) |
| 11 | **Contributed examples** (`examples/`) | The example programs still build and run | all examples | `.\scripts\run_contributed_examples.ps1` | ✅ | |
| 12 | **Incremental shim audit** | The incremental (chunked) layer replays its buffer correctly | audit program | `.\scripts\run_incremental_shim_audit.ps1` | ✅ | [incremental-shim-audit](../../docs/incremental-shim-audit.md) |
| 13 | **Python unit tests** (`tests/python`) | The test harness scripts themselves (runners, judges, reports) | 257 tests | `python -m unittest discover -s tests\python -p "test_*.py"` | ✅ 257 OK | |
| 14 | **Large XML** | One big file parsed whole, through every xpact engine | generated 5 MB file (`make_large_xml.py`) | `.\scripts\run_large_xml_benchmarks.ps1 -XmlFile <file> -NoPublish` | ✅ 5 MB; ❌ C ABI "out of memory" from 10 MB | [large-xml-benchmarks](../../docs/large-xml-benchmarks.md) |
| 15 | **Four-way W3C + regression + speed** (xpact, xpact via Gobo, expat, xpact-core) | The same suites #1 and #3 on the other parsers, and speed on one Linux machine | as #1 and #3 | `.\benchmarks\four_way\run_four_way.ps1` | see [REPORT](REPORT.md) | [REPORT §3](REPORT.md) |
| 16 | **Gobo XML parser comparison** | Gobo's own parser vs xpact: W3C, canonical output, encodings, libxml2 corpus, fuzzing, security limits, large files, speed | 1,974 W3C + 146 encodings + 1,417 libxml2 files + 870k fuzz inputs + 29 limit cases | `bash reports/gobo-xml-2026-11-18/run_all.sh` (WSL) | 🚫 separate run (#442) | [results](../gobo-xml-2026-11-18/results.md) |
| 17 | **Linux benchmarks** | xpact speed under Linux EiffelStudio and Gobo vs the distro's libexpat | catalog workload | `.\scripts\run_wsl_benchmarks.ps1` | 🚫 covered by #15 | [wsl-benchmarks](../../docs/wsl-benchmarks.md) |
| 18 | **Website tests** (`website/`) | The website's API (upload limits, security, validation) and the frontend build | 56 backend tests + build | `.\website\scripts\test.ps1` (after `.\website\scripts\build-dll.ps1 -SkipBuild`) | ✅ 56 / 56 + build | [website testing](../../website/docs/testing.md) |
| 19 | **Jenkins pipeline tests** (`tests/jenkins`) | The CI pipeline files are valid and publish plots and e-mails | 3 Groovy tests | `.\scripts\test_jenkins_pipelines.ps1` | 🚫 needs Jenkins | [dual-implementation-jenkins](../../docs/dual-implementation-jenkins.md) |

## 3. What you need installed (once)

| Tool | Why | Version used |
|---|---|---|
| EiffelStudio | builds the Eiffel parsers and tests | 25.12 Standard (Windows), 25.12 rev 98922 (Linux) |
| Visual Studio C++ (MSVC) + its CMake | C compiler for EiffelStudio, the DLL and the libexpat suite | Visual Studio 2026 |
| Python | all runners and reports (standard library only) | 3.11+ (`uv` works) |
| .NET SDK | C# DLL tests, website | 10 |
| Git | clones libexpat 2.8.1 for suite #5 | any |
| WSL Ubuntu 24.04 (Linux half only) | Gobo `gec`, Linux EiffelStudio, gcc, python3, `libexpat1-dev` | gec 26.11.14, gcc 13.3, expat 2.6.1 |

Downloaded by the scripts themselves: the W3C test suite (into `build\`) and libexpat 2.8.1 source (into `C:\xpact\deps\libexpat`).

## 4. Where results land

| Output | Folder |
|---|---|
| One-command run (logs, tables, step list) | `reports\four-way-<date>\` |
| Single suite runs | `build\<suite>\<timestamp>\` (`summary.md`, `comparison.tsv`, `run.json`) |
| C# DLL tests | `build\dotnet-dll-tests\<dll>-<time>\` or `--out` |

Exit codes: **0** = all passed, any other value = at least one failure or the run could not be done (the C# DLL tests use 1 = failure, 2 = could not run). The exit code of every step is in `logs\00-steps.tsv`.

## 5. In CI (Jenkins)

The repo already has Jenkins pipelines in [`ci/`](../../ci/); [`ci/Jenkinsfile.all-tests`](../../ci/Jenkinsfile.all-tests) runs most suites above on every build.

| In Jenkins (`all-tests`, `dual-w3c`, `dual-catalog`, `windows-phase1`) | Not in Jenkins yet |
|---|---|
| #1 W3C and #3 regression (dual lanes), #2 W3C all cases, #4 dual catalog, #5 libexpat suite, #6 Eiffel test matrix, #8 chunked CRC corpus, #9 native ABI (Windows + WSL), #10 runtime smoke, #11 contributed examples, #12 shim audit, #13 Python unit tests, #14 large XML, #17 Linux/Gobo benchmarks | #7 C# DLL tests, #8 chunked CRC *harness* script, #15 four-way comparison (expat and Gobo engines), #18 website tests |

So a reviewer can either re-run Jenkins' `all-tests` job, or run the commands in §2 on a Windows PC. Proposal (not done; needs the Jenkins server): add stages for #7, #15 (`run_four_way.ps1 -SkipLinux`, checking `logs\00-steps.tsv` against expected exit codes; the dual lanes exit 1 on purpose for xpact-core's known gaps) and #18.