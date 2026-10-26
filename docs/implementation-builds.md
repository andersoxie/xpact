# Pinned implementation builds

This is the first step towards running the same functional tests and benchmarks
against our parser (`xpact`) and Finnian Reilly's parser (`xpact-core`). It builds
two independent Eiffel executables and records exactly what each build used.

The next step is the [coverage inventory](implementation-coverage.md), which
maps existing cases and workloads to their shared or backend-specific coverage.
The [focused dual catalog lane](dual-catalog-lane.md) uses the same build
infrastructure for assertion-enabled audits and assertion-discarded benchmarks.
The [dual W3C lane](dual-w3c-lane.md) uses separate harnesses for original-byte
conformance cases with the same pinned dependency and isolated build provenance.

## Build both implementations

Requirements: Windows x64, Python 3.11 or newer, Git, EiffelStudio with Base,
Base Extension, Time and bundled MSVC zlib, and Visual Studio C++ x64 tools.
`ec` and `finish_freezing` must be on `PATH`. The PowerShell wrapper loads the
MSVC environment; the Python runner selects Eiffel's `msc_vc140` backend.

Dependency Git commands enable `core.longpaths=true` for that invocation, so
deep Jenkins workspace paths remain readable after a checkout moves into its
40-character revision directory. No global Git setting is changed.

From the repository root:

```powershell
.\scripts\build_implementations.ps1
```

The current configuration is **finalized, assertions enabled, full void safety**.
Compilation uses `-finalize -keep` so finalization retains contract checks.
These probes do not depend on a Base precompile.

The core build compiles the pinned Shift-JIS helper C source into its own MSVC
object. Upstream's ECF supplies that helper's static archive only on Unix.
Our probe ECF links the Windows object without changing the upstream checkout;
the helper's source hash, object hash and compilation command are recorded.

To build just one implementation:

```powershell
.\scripts\build_implementations.ps1 -Implementation Xpact
.\scripts\build_implementations.ps1 -Implementation Xpact-core
```

The first core build fetches the exact commit recorded in
[`dependencies/xpact-core.json`](../dependencies/xpact-core.json):

- Fork: <https://github.com/andersoxie/Xpact-core.git>
- Commit: `6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676`

There is no update to the fork's latest branch. A deliberate lock-file change
is required to use a different revision.

## Prepare once, then work offline

Source preparation is also available separately:

```powershell
python .\scripts\prepare_xpact_core.py
python .\scripts\prepare_xpact_core.py --offline
.\scripts\build_implementations.ps1 -Offline
```

The source lives under `build/dependencies/xpact-core/<commit>/`. Preparation
checks the origin, exact commit, every tracked file's bytes, required files,
and the absence of extra files, including ignored files. It rechecks these on
every reuse, including offline runs. A missing offline checkout is an error.
An altered checkout is rejected and preserved for inspection; the script does
not reset it or silently switch implementations.

Downloads use a separate temporary checkout. Only verified source is published
at the pinned path. Concurrent preparation validates the winning checkout.
Failed preparation removes only its own temporary directory.

## Read the evidence

Every invocation creates a new `build/implementations/<run-id>/` directory.
Each implementation has its own `project/EIFGENs/`, executable, generated
identity class and logs. Existing builds and evidence are preserved.

The command prints the run's `run.json` path. Each verified implementation also
has a `build.json` recording:

- Implementation ID, source URL and full revision, source content hash, and
  whether our repository had uncommitted changes.
- Probe/build input hash, build mode, assertion and void-safety settings.
- EiffelStudio and C compiler paths and versions, generated C build flags,
  dependency paths and hashes, and the exact compilation command.
- Executable path and SHA-256 hash, plus the probe's identity and result.

The executables parse `<root>probe</root>` and check the root start event,
root end event and exact text. A successful executable prints:

```text
XPACT_BUILD_PROBE<TAB>implementation<TAB>revision<TAB>configuration<TAB>OK
```

The build runner verifies that identity before publishing `build.json`, and
checks that source inputs did not change during the build. A failed engine is
reported separately; the other selected engine is still attempted. A partial
or failed run must not be treated as a verified pair.

## Scope of this step

These are build probes, not the shared functional suite or a performance
comparison. No parser verdicts beyond this tiny XML case have been established.
The core probe observes raw events through `XT_XML_PARSER_BASE`; it does not
use the higher-level text-normalizing wrapper. The pinned upstream checkout
is not modified by our build.

The native C/.NET adapter and independently named DLLs belong to the later
native integration step. WSL builds, additional assertion/build configurations,
shared cases, benchmark timing and CI execution of both engines follow in the
remaining plan steps. The existing production build and test commands keep
their current entry points.

Run the setup's infrastructure tests without EiffelStudio or network access:

```powershell
python -m unittest discover -s tests/python -p test_implementation_builds.py -v
```
