# Eiffel/GCC benchmarks in WSL2

Use Linux EiffelStudio inside WSL2 to compile the Eiffel benchmark with GCC
and compare it with the libexpat C benchmark in the same Linux environment.
This is an additional benchmark lane; the Windows/MSVC measurements remain
available through `scripts/run_benchmarks.ps1`.

The Windows EiffelStudio installation cannot use WSL GCC as a replacement
backend for its Windows runtime. Install a Linux EiffelStudio distribution
in WSL instead. Eiffel Software documents GCC as a supported Linux C compiler
in its [Linux installation guide](https://www.eiffel.org/doc/eiffelstudio/Linux).
Use the same EiffelStudio release on Windows and Linux when comparing them.

## Setup and execution

In the selected WSL2 distribution, install GCC, make, Python 3 and libexpat
development headers (Ubuntu packages: `build-essential python3 libexpat1-dev`).
Install Linux EiffelStudio following the official guide and configure its
Linux environment. For an archive installation, this normally means
`ISE_EIFFEL` points at the Linux installation, `ISE_PLATFORM=linux-x86-64`,
and its `studio/spec/linux-x86-64/bin` directory is on `PATH`.
Do not point these variables at the Windows installation.

From PowerShell:

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu
```

If the Linux compiler environment is supplied by a shell file rather than
the login environment, pass its Linux path:

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu `
  -EiffelEnvironment /opt/Eiffel_25.02/setup.rc `
  -Iterations 10000 -Repetitions 5 `
  -EiffelBuild Finalized,FinalizedAssertions,Workbench
```

The path above is an example; use the environment file belonging to your
installation. The default build selection is `Finalized,FinalizedAssertions`.
The wrapper can be invoked from any current directory. `-OutputDir` defaults
to `build\wsl-benchmarks` relative to the repository, and accepts an absolute
Windows path. `-Distribution` defaults to the configured WSL distribution.

From a configured Linux shell, the same runner can also be invoked directly:

```sh
python3 scripts/run_wsl_benchmarks.py --iterations 10000 --repetitions 5
```

Every run rebuilds both benchmarks. Each Eiffel build mode has its own
project directory under the output directory, separate from Windows
`EIFGENs`. `FinalizedAssertions` retains runtime assertions with
`-finalize -keep`; `Finalized` discards them. Both use the existing benchmark
ECF and parser sources. Workbench is optional and has assertions enabled.
The Windows Base precompile is conditional on Windows; Linux compiles Base
from source, so a fresh Linux installation needs no precompiled Base project.

## Results and interpretation

The output directory contains `benchmark-results.tsv`, `summary.md`,
`metadata.json`, and build logs. Old measured reports are removed before
checking prerequisites. A failed build or benchmark does not leave an old
successful report presented as a new measurement.

The workloads use the same 2,611-byte UTF-8 catalog with 100 items:

- Eiffel with a reused parser and a no-op event handler, with normal GC and
  GC suspended during parsing, for every selected build mode.
- The existing libexpat C harness, compiled with `gcc -O2`, with callbacks
  and without callbacks. It creates a parser for each document and links
  against the distribution's libexpat.

Timing takes place inside Linux using a monotonic clock. Both executables
have an untimed warmup, and elapsed times include their Linux process
startup and document preparation. They exclude compilation and the
Windows-to-WSL launch. The summary reports medians; the TSV retains every
measured repetition. Toolchain and OS information accompanies the results.

This makes Eiffel and libexpat more comparable by using GCC and Linux for
both. It still measures different parsers, runtime/GC behavior, callback
work, parser reuse and optimization settings. A difference from the Windows
results cannot be attributed to the C compiler alone. The older Windows
runner times WSL C executables from Windows, so its process timings include
`wsl.exe` overhead and should be kept as a separate series.

## Measured xpact comparison: 24 October 2026

The direct xpact Eiffel executable was measured on the same physical Windows
computer, with MSVC running natively and GCC running inside its WSL2 Ubuntu
20.04 distribution. The timing batches ran sequentially. Both builds used
EiffelStudio 25.02.9.8723 and the same parser sources and catalog workload.
Windows used MSVC 19.44.35229 with the generated `-Ox` options; Linux used
GCC 9.4.0 with the generated `-O3` options.

Each result below is the median of three runs of 10,000 documents after one
untimed full-workload warmup. The table uses normal GC, a reused parser, and
a no-op event handler; timing includes native process startup inside each OS.

| xpact build | Windows/MSVC MiB/s | WSL2/GCC MiB/s | WSL throughput relative to Windows |
|---|---:|---:|---:|
| Finalized, assertions discarded | 13.629 | 12.400 | 9.0% lower |
| Finalized, assertions enabled | 1.434 | 1.535 | 7.0% higher |

The compiler/platform configuration produces a modest difference on this
workload, with the direction depending on assertion settings. Enabling the
full assertion set increases elapsed time approximately 9.5 times on Windows
and 8.1 times on WSL. These measurements change the OS, runtimes, compiler
version and optimization options together, so they do not isolate the C
compiler's contribution.

[Raw repetitions](../benchmarks/results/xpact-compiler-comparison-2026-10-24.tsv)
also include the GC-suspended variants for both configurations. The committed
WSL runner uses the distribution's libexpat for its separate C baseline; the
table above compares only xpact's direct Eiffel parser.

## Jenkins

Both Jenkins pipelines enable the WSL Eiffel/GCC benchmarks by default, using
the settings verified in Jenkins build #74:

| Parameter | Default |
|---|---|
| `RUN_WSL_EIFFEL_BENCHMARKS` | `true` |
| `WSL_DISTRIBUTION` | `Ubuntu` |
| `WSL_EIFFEL_ENVIRONMENT` | `/mnt/c/Users/ander/Documents/xpact/build/wsl-toolchain/eiffel-env.sh` |

These settings target the built-in Windows agent's existing Linux EiffelStudio
installation. Override the distribution and environment file for another host.
The environment file and toolchain are outside the Jenkins workspace and must
remain available to the Jenkins account. Clear `WSL_EIFFEL_ENVIRONMENT` only
when the Linux login environment already exposes the compiler, or set
`RUN_WSL_EIFFEL_BENCHMARKS=false` to disable this stage.

Jenkins refreshes the parameter defaults when it runs the updated Jenkinsfile.
Values already submitted for a build remain unchanged.

The separate stage publishes its own benchmark tests, plots, toolchain metadata
and logs. It does not require the Windows benchmark stage to be enabled.
Missing Linux prerequisites fail the selected stage instead of silently
reporting a skipped measurement.

The portable runner tests need no EiffelStudio installation:

```powershell
python -m unittest discover -s tests/python -p test_wsl_benchmarks.py -v
```
