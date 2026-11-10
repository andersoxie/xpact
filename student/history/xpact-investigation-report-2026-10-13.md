> **Snapshot of 2026-10-13 (week 2), kept as it was written.** It describes the state on the old
> `student-test` checkout, before this repository. Most problems it calls unresolved are fixed since:
>
> | Section | Where it stands now (2026-10-31) |
> |---|---|
> | 3.1 Eiffel runtime include directory | ✅ fixed ([#2](https://github.com/andersoxie/xpact/issues/2); on Jenkins [#73](https://github.com/andersoxie/xpact/issues/73)) |
> | 3.2 missing linker response file, 3.4 bridge-only DLL | ✅ the Eiffel-backed DLL builds and is the one the tests load ([#7](https://github.com/andersoxie/xpact/issues/7), [#10](https://github.com/andersoxie/xpact/issues/10), A04 [#168](https://github.com/andersoxie/xpact/issues/168)) |
> | 3.3 command line too long | ✅ fixed ([#4](https://github.com/andersoxie/xpact/issues/4)) |
> | 3.5 `final_finished_or_suspended` postcondition | ✅ fixed and verified (B03, [#3](https://github.com/andersoxie/xpact/issues/3)) |
> | invalid UTF-8 accepted | ✅ fixed ([#39](https://github.com/andersoxie/xpact/issues/39), PR [#80](https://github.com/andersoxie/xpact/pull/80)) |
> | Jenkins precompile prompt | ⏭️ dropped (student, 2026-10-22) |
> | 5.3 conformance, 852 failures | ✅ 676 were wrong verdict rules ([#117](https://github.com/andersoxie/xpact/issues/117)); now all 2,585 W3C cases run, 0 failed ([report](../../reports/latest-2026-10-28/README.md)) |
> | 6 performance | measured properly in week 7: [week 7 note](../notes/weekly/week-07.md) |
>
> The current status of everything is in [`../PLAN.md`](../PLAN.md).

# XPact Investigation Report

**Project:** XPact — XML parsing, by contract  
**Report type:** Student investigation and progress report  
**Platform:** Windows x64  
**Status:** Work in progress  
**Branch:** `student-test`

## 1. Project Overview

XPact is an XML parser project providing a C-facing API intended to be compatible with Expat. The investigation focuses on Phase 1: correctness and behavioral compatibility before performance optimization.

Objectives:
- Understand the Eiffel parser and native C interface.
- Investigate build and DLL integration errors.
- Test XML parsing with assertions enabled and disabled.
- Evaluate XML conformance and parser correctness.
- Measure preliminary performance and document findings.

### Architecture

```text
C application
    ↓
native/xpact_native.c
    ↓
Eiffel bridge
    ↓
src/xp_native_parser.e
    ↓
src/xp_parser.e
```

| File/component | Purpose |
|---|---|
| `include/xpact.h` | Public C API |
| `native/xpact_native.c` | Native C interface |
| `src/xp_native_parser.e` | Eiffel bridge |
| `src/xp_parser.e` | Core XML parser |
| `tests/` | Parser and integration tests |
| `XP_CLI` | Command-line parser |
| `XP_METRICS_EVENT_HANDLER` | Metrics collection |

Building the C bridge alone does not guarantee that the Eiffel parser is correctly integrated.

## 2. Environment and Setup

| Component | Environment |
|---|---|
| OS | Windows x64 |
| EiffelStudio | 25.12.9.8922 |
| EiffelStudio root | `C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard` |
| Visual Studio | 18 Community |
| Python | 3.10.6 |
| Jenkins Java | Temurin OpenJDK 21.0.12.1 |

The repository includes `src/`, `native/`, `include/`, `tests/`, `scripts/`, `docs/`, and `benchmarks/`.

Important scripts:
- `scripts/build_native.ps1`
- `scripts/build_native_eiffel.ps1`
- `scripts/run_native_runtime_smoke.ps1`
- `scripts/run_eiffel_test_matrix.ps1`
- `scripts/run_w3c_conformance.py`
- `tests/python/test_w3c_conformance.py`

The Eiffel test matrix supports assertion modes `All`, `On`, and `Off`, and build modes `All`, `Workbench`, and `Finalized`.

## 3. Troubleshooting and Errors

### 3.1 Eiffel runtime include directory

**Error:** `Cannot find Eiffel runtime include directory`

The build script used the outdated fallback path `C:\El2502E\studio\spec\win64\include`. The correct installation was found under the EiffelStudio root listed above.

**Status:** Correct path identified; script behavior still needs verification.

### 3.2 Missing Eiffel linker response file

**Error:** `Expected Eiffel link response file not found`

The expected file was:

`EIFGENs\xpact_native_library\F_code\xpact_native_library.lnk`

**Status:** Unresolved. The generated target, finalization process, and expected output path need investigation.

### 3.3 Windows command-line length

**Error:** `The input line is too long`

This occurred during `build_native_eiffel.ps1`.

**Status:** Unresolved. Investigate the command length and how the script passes arguments to Windows.

### 3.4 Native DLL integration

The bridge-only build produced `xpact.dll`, `xpact.lib`, and `xpact.exp`. The DLL was approximately 116 KB.

However, a C# P/Invoke test returned:

```text
XML_Parse: 0
error 44: XML_ERROR_NOT_STARTED
Eiffel parser bridge is not installed
```

**Finding:** Compiling the C bridge did not establish that the Eiffel parser was connected.

**Status:** Full native integration remains unverified.

### 3.5 Native parser assertion failure

A test-matrix run produced:
XP_NATIVE_PARSER parse @10
final_finished_or_suspended: Postcondition violated

**Status:** Unresolved. Reproduce with the exact target, assertion mode, build mode, and input.

### 3.6 Other environment and parser issues

- **AutoTest:** The generated executable reported `xpact AutoTest generated tests: ok`. This confirms that particular run only.
- **PowerShell:** A temporary process-level execution-policy bypass was used.
- **Visual Studio:** The `cl` compiler was initially unavailable; the C++ environment needed initialization.
- **Eiffel variables:** `ISE_PRECOMP`, `ISE_LIBRARY`, and `ISE_EIFFEL` were blank during one investigation.
- **Jenkins:** A job succeeded, but the safe Base precompile prompt repeatedly appeared under the `SYSTEM` account.
- **XML declaration:** A declaration at the beginning of the document passed; preceding whitespace or a newline produced a misplaced-declaration error.
- **Invalid UTF-8:** `bad-utf8.xml` contained bytes `C3 28`, but `xpact.exe --parse-file .\bad-utf8.xml` reported `xpact parse: ok`.

The invalid UTF-8 result is an important unresolved correctness issue.

## 4. Fixes and Solutions

The investigation established the correct EiffelStudio installation path and distinguished native C compilation from full Eiffel parser integration.

The generated AutoTest executable succeeded, a large XML file parsed successfully, and the XML declaration behavior was reduced to a reproducible test.

However, these results do not confirm that the build, native integration, or parser is fully correct.

The missing linker file, command-line length error, assertion failure, invalid UTF-8 acceptance, and Jenkins precompile prompt remain unresolved or require verification.

## 5. Testing and Conformance Results

### 5.1 Core XML tests

| Test | Expected result | Recorded finding |
|---|---|---|
| `<root/>` | Accept | Basic parsing observed |
| `<root>` | Reject | Requires verification |
| `<root><child></root>` | Reject | Requires verification |
| Invalid UTF-8 (`C3 28`) | Reject | Unexpectedly accepted |
| XML declaration at document start | Accept | Passed |
| Declaration preceded by whitespace | Reject as misplaced | Error observed |

The assignment also requires checking callback behavior for invalid input, including element, text, whole-input, and chunk-related callbacks. CLI output alone cannot verify these guarantees.

### 5.2 Assertion matrix

The project supports testing with assertions both enabled and disabled:

```powershell
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All
```

The recorded postcondition failure requires follow-up. The successful AutoTest run does not establish that the complete matrix passes.

### 5.3 XML conformance

One recorded conformance run produced:

| Result | Count |
|---|---:|
| Total tests | 2,163 |
| Passed | 1,311 |
| Failed | 852 |
| Missing | 0 |

One example failure was `rmt-e2e-2a` (`E2a.xml`), involving a duplicate enumeration value in a DTD `ATTLIST` declaration, such as `(one|one)`. The parser accepted the document when rejection was expected under the recorded test rules.

These results indicate substantial conformance gaps. The exact test profile and expected-verdict mapping should be confirmed against the runner and generated reports.

### 5.4 Python W3C test harness

The investigation examined `scripts/run_w3c_conformance.py` and `tests/python/test_w3c_conformance.py` in the W3C benchmark repository.

The Python and PowerShell conformance summaries differed. The Python harness also encountered a report-generation failure in `write_reports`.

The Python runner uses a configured executable and the W3C XML Test Suite dated `20130923`. Its results should be compared with the PowerShell runner using the same inputs, executable, and verdict rules.

**Status:** Reconcile the reports, verify report-generation tests, and confirm that each run replaces previous output files.

### 5.5 Regression testing

Regression tests should preserve a known input, expected result, actual result, command, build configuration, and outcome after changes.

Priority cases include invalid UTF-8, incomplete XML, mismatched tags, XML declaration placement, and duplicate DTD enumeration values.

## 6. Performance Benchmarks

A file named `test3.xml`, approximately 1,048,568 bytes, parsed successfully.

- Without `--metrics`: approximately 3.5 seconds.
- With `--metrics`: noticeably slower; no reliable duration was established.

An attempt to calculate callbacks per second was reverted after `REAL_64`/`REAL_32` type errors.

These are preliminary observations, not controlled benchmark results. Repeat measurements with fixed inputs and record the build configuration and timing methodology.

## 7. Known Issues and Limitations

**Build and integration**
- Missing Eiffel linker response file.
- Windows command-line length error.
- Eiffel parser bridge not installed in the bridge-only DLL.
- Native parser postcondition violation.
- Eiffel path and environment-variable handling require verification.
- Jenkins precompile prompt remains unresolved.

**Parser correctness**
- Invalid UTF-8 unexpectedly accepted.
- 852 failures in the recorded 2,163-test conformance run.
- Duplicate DTD enumeration case accepted unexpectedly.
- Python and PowerShell summaries differ.
- Full callback behavior remains unverified.

**Evidence limitations**
- A successful build does not prove parser integration.
- Passing AutoTest does not prove full conformance.
- CLI results do not establish native callback correctness.
- Preliminary timings do not establish reliable throughput.

## 8. Conclusions and Next Steps

The investigation clarified XPact's architecture, Windows/Eiffel environment, test workflows, and key integration problems.

Positive findings include identifying the correct EiffelStudio installation, successfully building the bridge-only DLL, passing the recorded AutoTest run, parsing a roughly 1 MB XML file, and recording an initial conformance baseline.

The main priorities are:

1. Reproduce and investigate invalid UTF-8 acceptance.
2. Resolve the missing linker response file and command-line length error.
3. Verify full Eiffel-backed DLL integration with a native smoke test.
4. Reproduce the parser postcondition failure.
5. Run the complete assertion and build matrix.
6. Add regression tests and verify callback behavior.
7. Reconcile Python and PowerShell conformance results.
8. Fix and test Python report generation.
9. Repeat performance measurements with and without metrics.
10. Resolve Jenkins precompile configuration.
11. Update this report with verified fixes, test commands, logs, and final results.

**Overall conclusion:** XPact has a functioning development and testing workflow, but parser correctness, XML conformance, and full native integration require further investigation. All unresolved issues should remain clearly marked until verified by repeatable tests.
