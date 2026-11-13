# Eiffel/GCC benchmarks in WSL2

Use Linux EiffelStudio and the [Gobo Eiffel compiler](https://github.com/gobo-eiffel/gobo)
(`gec`) inside WSL2 to compile the Eiffel benchmark with GCC and compare them
with the libexpat C benchmark in the same Linux environment.
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

Install the latest standalone Linux distribution from
[Gobo's releases](https://github.com/gobo-eiffel/gobo/releases),
rather than the older Gobo tools bundled with EiffelStudio. Set `GOBO` to the
unpacked Gobo directory and add its `bin` directory to `PATH`, so `gec --version`
works in the same Linux shell. An environment file can contain:

```sh
export GOBO=/opt/gobo
export GOBO_EIFFEL=ge
export GOBO_CC=gcc
export PATH="$GOBO/bin:$PATH"
```

Gobo has its own Eiffel runtime and libraries;
the Gobo benchmark uses those with the same xpact parser and harness sources.
The runner does not download or install compilers.
Use a Linux distribution compatible with the selected compiler binary. The
prebuilt Gobo 26.10 Linux x86-64 compiler requires glibc 2.38 or newer; the
configured host uses Ubuntu 24.04 (`Ubuntu-24.04` in WSL), since its older
Ubuntu 20.04 distribution cannot load this Gobo release.

From PowerShell:

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu-24.04
```

If the Linux compiler environment is supplied by a shell file rather than
the login environment, pass its Linux path:

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu-24.04 `
  -EiffelEnvironment /opt/Eiffel_25.02/setup.rc `
  -GoboEnvironment /opt/gobo/setup.sh `
  -Iterations 10000 -Repetitions 5 `
  -EiffelBuild Finalized,FinalizedAssertions
```

The paths above are examples; use environment files belonging to your
installations. The optional Gobo environment file is sourced after the
EiffelStudio file. An environment file is sourced only when its compiler is
selected. The default compiler selection is `EiffelStudio,Gobo`,
and the default build selection is `Finalized,FinalizedAssertions`.
The wrapper can be invoked from any current directory. `-OutputDir` defaults
to `build\wsl-benchmarks` relative to the repository, and accepts an absolute
Windows path. `-Distribution` defaults to the configured WSL distribution.

To run just one compiler, pass `-EiffelCompiler Gobo` or
`-EiffelCompiler EiffelStudio`. Only selected compilers are required.
Workbench is an EiffelStudio mode; select EiffelStudio alone to include it:

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu-24.04 `
  -EiffelCompiler EiffelStudio -EiffelBuild Finalized,FinalizedAssertions,Workbench
```

From a configured Linux shell, the same runner can also be invoked directly:

```sh
python3 scripts/run_wsl_benchmarks.py --iterations 10000 --repetitions 5
# Gobo only:
python3 scripts/run_wsl_benchmarks.py --eiffel-compiler Gobo
```

Every run rebuilds all selected benchmarks. Each compiler and build mode has
its own project directory under the output directory, separate from Windows
`EIFGENs`. For EiffelStudio, `FinalizedAssertions` retains runtime assertions
with `-finalize -keep`; `Finalized` discards them. Gobo also has optimized
builds with xpact assertions requested or disabled, using two independent targets
in `benchmarks/xpact_gobo_benchmarks.ecf`. Each target sets its complete
assertion policy explicitly and disables assertions in imported Base classes.
This matches EiffelStudio's broad scope, but not all executed checks:
EiffelStudio still enforces supplier preconditions from xpact callers, while
Gobo 26.10 ignores that setting and also omits `check` instructions and
decreasing loop-variant checks. The `26.11.12+ca6541c` nightly passes the
previously failing probes, including separate-library caller checks; this is
bounded qualification rather than proof of full semantic equivalence.
The Gobo result is therefore labelled
`xpact assertions requested`, not equivalent full assertion coverage.
See the [assertion investigation](gobo-assertions.md) for measured effects and
the compiler behavior probes. Both Gobo targets specify native GCC `-O2`
through an ECF `external_cflag`, since Gobo 26.10's default `gcc.cfg` did
not add optimization flags to its C compilation commands.
Both compilers use the same parser and benchmark harness sources.
Gobo uses GCC and the Boehm garbage collector explicitly. It contributes one
normal-GC row per assertion mode. Gobo 26.10's `MEMORY` runtime controls do
not implement garbage-collection suspension, so the runner does not publish
Gobo GC-suspended measurements. The `26.11.12+ca6541c` nightly implements
those controls and passes the lifecycle probe, but the runner still provides
only normal-GC Gobo rows. EiffelStudio retains both GC variants.
Gobo's generated C build script is retained with the build.
Workbench is optional, has assertions enabled, and requires selecting
EiffelStudio alone; Gobo with Workbench is rejected.
The Windows Base precompile is conditional on Windows; Linux compiles Base
from source, so a fresh Linux installation needs no precompiled Base project.

## Results and interpretation

The output directory contains `benchmark-results.tsv`, `summary.md`,
`metadata.json`, and build logs. Old measured reports are removed before
checking prerequisites. A failed build or benchmark does not leave an old
successful report presented as a new measurement.

The workloads use the same 2,611-byte UTF-8 catalog with 100 items:

- Each selected Eiffel compiler with a reused parser, a no-op event handler,
  and normal GC for every selected build mode. Gobo rows are labelled
  separately from EiffelStudio.
- EiffelStudio also runs with GC suspended during parsing. The runner omits
  this variant for Gobo to support 26.10; the qualified 26.11 nightly now
  implements the required `MEMORY` controls.
- The existing libexpat C harness, compiled with `gcc -O2`, with callbacks
  and without callbacks. It creates a parser for each document and links
  against the distribution's libexpat.

Timing takes place inside Linux using a monotonic clock. All executables
have an untimed warmup, and elapsed times include their Linux process
startup and document preparation. They exclude compilation and the
Windows-to-WSL launch. The summary reports medians; the TSV retains every
measured repetition. Toolchain and OS information accompanies the results.

This makes Eiffel and libexpat more comparable by using GCC and Linux for
both. Comparing Gobo with EiffelStudio also changes the generated code,
runtime, base libraries and garbage collector. It still measures different
parsers, runtime/GC behavior, callback work, parser reuse and optimization
settings: EiffelStudio's generated build uses its own flags (`-O3` on the
configured host), while Gobo explicitly uses `-O2`. The generated commands
and options are recorded in `metadata.json`; these are not identical backend
configurations. A difference from the Windows results cannot be attributed
to the C compiler alone. The older Windows
runner times WSL C executables from Windows, so its process timings include
`wsl.exe` overhead and should be kept as a separate series.

## Measured Gobo/EiffelStudio comparison: 13 November 2026

After updating the shared Jenkins WSL compiler selection, the Jenkins benchmark
launcher was invoked locally with its normal settings: Ubuntu 24.04/WSL2,
10,000 documents per process, one full warmup, and five measured repetitions.
This was a local invocation using Jenkins's shared environment files, not a new
Jenkins job build. Both compilers rebuilt the same parser and harness sources at
repository revision `01e963d`; source hashes and the working-tree state are
preserved with the results.

The following medians compare **normal GC** and finalized builds only. Gobo is
`26.11.12+ca6541c`; EiffelStudio is `25.02.9.8723`. Both use GCC 13.3, with Gobo's
`-O2` and EiffelStudio's generated `-O3` settings. Gobo uses Boehm GC;
EiffelStudio uses its own collector.

| Requested assertion mode | EiffelStudio elapsed | Gobo elapsed | Gobo throughput relative to EiffelStudio |
|---|---:|---:|---:|
| Off | 1,552.189 ms | 915.405 ms | **1.70×** |
| On | 15,399.687 ms | 4,024.620 ms | **3.83×** |

Gobo takes 41.0% less elapsed time with assertions off and 73.9% less with them
on. Enabling assertions increases elapsed time **4.40×** for Gobo and **9.92×**
for EiffelStudio. These are comparisons within this run, not estimates of the
speedup from upgrading Gobo alone. The earlier November investigation used a
different parser revision and, for its original configuration, broader Base
assertion scope.

The previously failing assertion probes now match, including caller-requested
supplier preconditions. An additional empty-routine literal-`ensure False` probe
still differs with assertions off, so this remains bounded qualification rather
than full semantic equivalence; see [the assertion investigation](gobo-assertions.md).

The developers' shared-ECF suggestion was checked separately. New Gobo builds
both targets directly from the unchanged EiffelStudio ECF, without the explicit
optimization or GC options. With the same 10,000-document/five-repetition timing
procedure, those Gobo executables measured **940.900 ms off** and **4,014.825 ms
on**, giving **1.65×** and **3.84×** EiffelStudio's throughput. The conclusion
therefore holds with the shared ECF too.

The two Gobo configurations do not produce identical library code on this host:
the installed EiffelStudio 25.02 Base snapshot differs from the newer Gobo
FreeELKS snapshot, including `CONSOLE` and `FILE_INFO`. Gobo's README identifies
compatibility with EiffelStudio 26.09.9.9100. The shared-ECF control uses the
installed EiffelStudio Base sources; the normal Jenkins runner retains the
separate Gobo ECF and its library selection for older compiler compatibility.
Neither comparison isolates the compiler backend from its runtime and library
implementation.

[Raw repetitions](../benchmarks/results/gobo-eiffelstudio-comparison-2026-11-13.tsv)
also retain the runner's additional EiffelStudio GC-suspended and libexpat rows;
they are excluded from the ratios above.
[Metadata and follow-up evidence](../benchmarks/results/gobo-eiffelstudio-comparison-2026-11-13.json)
include the source/configuration hashes, generated flags, executable hashes,
shared-ECF control repetitions, and literal-postcondition diagnostics.

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

Both Jenkins pipelines enable the WSL Eiffel/GCC benchmarks by default.
Jenkins build #74 verified the earlier EiffelStudio-only configuration on
`Ubuntu`. The current defaults add Gobo and select the host's `Ubuntu-24.04`
distribution, which can run the latest compiler binary:

| Parameter | Default |
|---|---|
| `RUN_WSL_EIFFEL_BENCHMARKS` | `true` |
| `WSL_EIFFEL_COMPILERS` | `EiffelStudio,Gobo` |
| `WSL_DISTRIBUTION` | `Ubuntu-24.04` |
| `WSL_EIFFEL_ENVIRONMENT` | `/mnt/c/Users/ander/Documents/xpact/build/wsl-toolchain/eiffel-env.sh` |
| `WSL_GOBO_ENVIRONMENT` | `/mnt/c/Users/ander/Documents/xpact/build/gobo-toolchain/gobo-env.sh` |

These environment paths target the built-in Windows agent's Linux compiler
installations. On 13 November 2026 the shared Gobo environment was updated to
`gec version 26.11.12+ca6541c`, from the checksum-verified
[official nightly](https://github.com/gobo-eiffel/gobo/releases/tag/nightly),
installed under `build/gobo-toolchain/26.11.12-ca6541c/gobo`.
The previous 26.10 installation remains available, with environment and metadata
backups named `gobo-env-before-26.11.12.sh` and
`installation-before-26.11.12.json` in `build/gobo-toolchain`.
Both pipeline defaults still use the same shared environment filename, so the
compiler update requires no job parameter change. Build #134 predates this
selection change and retains its original 26.10 results.
Override `WSL_GOBO_ENVIRONMENT` for another Gobo installation, or clear it when
the Linux login environment already exposes Gobo. Override the distribution and
environment files for another host. Environment files and toolchains outside
the Jenkins workspace must remain available to the Jenkins account.
Clear `WSL_EIFFEL_ENVIRONMENT` when the Linux login environment already exposes
EiffelStudio. Environment files for unselected compilers are ignored.
Set `WSL_EIFFEL_COMPILERS` to
`EiffelStudio` to retain the previous compiler selection, or set
`RUN_WSL_EIFFEL_BENCHMARKS=false` to disable this stage.

From this repository on the configured Windows host, the same environment files
can be used directly:

```powershell
.\scripts\run_wsl_benchmarks.ps1 -Distribution Ubuntu-24.04 `
  -EiffelEnvironment /mnt/c/Users/ander/Documents/xpact/build/wsl-toolchain/eiffel-env.sh `
  -GoboEnvironment /mnt/c/Users/ander/Documents/xpact/build/gobo-toolchain/gobo-env.sh
```

Jenkins refreshes the parameter defaults when it runs the updated Jenkinsfile.
Values already submitted for a build remain unchanged.

The separate stage publishes its own benchmark tests, plots, toolchain metadata
and logs. It does not require the Windows benchmark stage to be enabled.
Missing Linux prerequisites fail the selected stage instead of silently
reporting a skipped measurement.

The portable runner tests need no Eiffel compiler installation:

```powershell
python -m unittest discover -s tests/python -p test_wsl_benchmarks.py -v
```
