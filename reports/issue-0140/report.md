# Report: issue #140, script for the supervisor: collect the information for the open steps

Issue: [#140](https://github.com/andersoxie/xpact/issues/140)   Branch: `fix/140-supervisor-info-script`   Base: `student-Mass` @ `d2f98a9`   Date: 2026-10-26

## In short

| | |
|---|---|
| Why | The open steps of the dual-implementation plan (`newUpdates.txt`) and #74/#79 need information that only exists on the supervisor's machine: his tools, Jenkins builds, dual-lane runs, WSL and large XML files |
| What | [`student/tools/collect-supervisor-info.ps1`](../../student/tools/collect-supervisor-info.ps1): one command, **read-only by default**, writes one `.txt` to the Desktop for him to send back |
| Verified | Parses in Windows PowerShell 5.1; tested on the student PC with a fake Jenkins home; every missing part is reported as "not found", nothing fails |

## How the supervisor runs it

```powershell
# from the xpact repository root (a checkout that contains this script)
powershell -NoProfile -ExecutionPolicy Bypass -File student\tools\collect-supervisor-info.ps1
# optional: large XML files, and running both dual lanes now
powershell -NoProfile -ExecutionPolicy Bypass -File student\tools\collect-supervisor-info.ps1 -LargeXml D:\xml\a.xml,D:\xml\b.xml -RunDualLanes
```

It writes `Desktop\xpact-supervisor-info-<date>.txt`. That file goes to the student.

## What it collects, and for which step

| Section | Content | For |
|---|---|---|
| 1 Machine and tools | Windows, PowerShell; `ISE_EIFFEL`, `ISE_PLATFORM`, `ISE_C_COMPILER`, `ISE_LIBRARY` in process, user and machine scope; `ec -version`, Python, Git, .NET, CMake, Visual Studio installs | #74, step 1 |
| 2 Repository | path, branch, commit, number of local changes, remotes, whether the student work is in it | all |
| 3 Xpact-core | `dependencies/xpact-core.json` and the cached checkout's commit and local changes | steps 1, 4, 6 |
| 4 Local dual runs | newest `build/dual-catalog`, `build/dual-w3c`, `build/dual-ci-*`: `run.json` and summaries; newest files in `benchmarks/results` | steps 7-9 |
| 5 Jenkins | each xpact job's newest builds (`-MaxBuilds`, default 3): result, time, duration, commit; stage and key lines with line numbers; the last 40 lines; archived `run.json` / `xpact-summary.json` | Jenkins run, #74, #79, #130, #131 |
| 6 WSL | distributions; whether `ec` is installed in the default one | step 7 |
| 7 Large XML | size and SHA-256 of the files given with `-LargeXml`; the newest large-XML run | step 7 |
| 8 (optional) | `-RunDualLanes`: runs `run_dual_catalog.ps1` and `run_dual_w3c.ps1` with `-Offline`, records exit codes, output tails and results | step 9 baseline |

**Privacy and size:** e-mail addresses are replaced by `<email>`. Jenkins console
markup is removed. Files are cut at 4,000-6,000 characters, and at most 400 key
lines are kept per build log. Nothing is uploaded; he decides what to send.

## Expected results (written before testing, in #140)

| # | Expected | Actual | |
|---|---|---|---|
| 1 | Parses in Windows PowerShell 5.1 | `ParseFile`: 0 errors, PowerShell 5.1.26100.9711 | ✅ |
| 2 | Completes on the student PC (no Jenkins, no WSL distribution) and reports the missing parts | exit 0; "not found" for Jenkins, Xpact-core cache, dual runs and large-XML runs; "no WSL distribution" | ✅ |
| 3 | Reads a Jenkins home correctly (fake home, [`fake-jenkins-home/`](fake-jenkins-home/)) | result `FAILURE`, commit, stage line, `smoke: ok`, `Finished:` with line numbers; e-mail masked (`mail to <email> failed`); console markup removed; archived `run.json` shown | ✅ |
| 4 | `-LargeXml a,b` | existing file: size and SHA-256; missing file: "not found" | ✅ |
| 5 | `-RunDualLanes` records a failing lane instead of stopping | both lanes: `exit code: 1` and their traceback in the file; the script still completes | ✅ |
| 6 | Read-only without `-RunDualLanes` | `git status`: only the new script is new; no other file changed | ✅ |

Full output of the last test: [`test-output-student-pc.txt`](test-output-student-pc.txt) (237 lines).

**Corrected during testing:**
- With no `dual-ci` run, the whole `build` folder was listed as a run.
- `-LargeXml a,b` arrived as one string under `-File`.
- WSL's own messages are UTF-16 and came out letter-spaced.
- Native-tool stderr appeared as long PowerShell error records.

All four are fixed, and the outputs above are from after the fixes.

**Observation, not part of this change:** on the student PC the dual lanes stop
at `hashlib.file_digest` because this shell's `python` is 3.10. This is the
known setting from #104/#113, and the lanes need Python 3.11 or newer. The
supervisor's runs used a newer Python.

## Limitations

- Not run on the supervisor's machine: the Jenkins part is tested only against
  a fake Jenkins home built from the structure Jenkins uses (`jobs/<job>/builds/<n>/build.xml`, `log`, `archive/`).
- `-RunDualLanes` is not read-only: it creates new run folders under `build/`,
  as the lanes always do.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 140 -Commit <merged sha>
```
