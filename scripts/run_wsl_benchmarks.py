#!/usr/bin/env python3
"""Build and time the Eiffel and distro libexpat benchmarks inside WSL2/Linux."""

import argparse
import csv
import io
import json
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
REPORT_NAMES = ("benchmark-results.tsv", "summary.md", "metadata.json")
TSV_FIELDS = (
    "Benchmark", "Engine", "Version", "Repetition", "Iterations", "DocumentBytes",
    "ElapsedMs", "DocsPerSecond", "MiBPerSecond", "Notes",
)


class BenchmarkError(RuntimeError):
    """A prerequisite, build, or benchmark command failed."""


@dataclass(frozen=True)
class BuildSpec:
    name: str
    target: str
    mode: str
    code_directory: str
    assertions: bool


@dataclass(frozen=True)
class Engine:
    name: str
    executable: Path
    arguments: tuple
    version: str
    notes: str
    environment: dict = None


def positive_integer(value):
    result = int(value)
    if result <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return result


def iteration_count(value):
    result = positive_integer(value)
    if result > 2147483647:
        raise argparse.ArgumentTypeError("must fit the benchmark's signed 32-bit iteration count")
    return result


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iterations", type=iteration_count, default=10000)
    parser.add_argument("--repetitions", type=positive_integer, default=5)
    parser.add_argument("--output-dir", type=Path,
                        default=REPO_ROOT / "build" / "wsl-benchmarks")
    parser.add_argument("--eiffel-build", action="append",
                        choices=("Finalized", "FinalizedAssertions", "Workbench"),
                        help="repeat to select several modes; defaults to both finalized modes")
    args = parser.parse_args(argv)
    args.output_dir = args.output_dir.expanduser().resolve()
    args.eiffel_build = args.eiffel_build or ["Finalized", "FinalizedAssertions"]
    return args


def sample_document_bytes():
    document = "<catalog>" + "".join(
        '<item id="{}">value</item>'.format(index) for index in range(1, 101)
    ) + "</catalog>"
    return len(document.encode("utf-8"))


def build_specs(names):
    specifications = {
        "Finalized": BuildSpec("Finalized", "xpact_benchmarks", "Finalized", "F_code", False),
        "FinalizedAssertions": BuildSpec("FinalizedAssertions", "xpact_benchmarks_assertions",
                                         "Finalized", "F_code", True),
        "Workbench": BuildSpec("Workbench", "xpact_benchmarks_assertions", "Workbench",
                               "W_code", True),
    }
    return [specifications[name] for name in dict.fromkeys(names)]


def run_checked(command, cwd=None, env=None, log_path=None):
    """Run a command, retain diagnostics, and never accept a failed exit status."""
    command = [str(argument) for argument in command]
    rendered = " ".join(shlex.quote(argument) for argument in command)
    try:
        completed = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, universal_newlines=True)
    except OSError as error:
        raise BenchmarkError("Cannot execute {}: {}".format(rendered, error)) from error
    output = completed.stdout or ""
    if log_path is not None:
        log_path = Path(log_path)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text("$ {}\n{}".format(rendered, output), encoding="utf-8")
    if completed.returncode != 0:
        location = " See {}.".format(log_path) if log_path is not None else ""
        raise BenchmarkError("Command exited {}: {}.{}\n{}".format(
            completed.returncode, rendered, location, output[-6000:]))
    return output.strip()


def clean_environment():
    """Exclude compiler and loader overrides that could substitute the xpact bridge."""
    environment = dict(os.environ)
    for name in ("LD_LIBRARY_PATH", "LD_PRELOAD", "LIBRARY_PATH", "CPATH", "C_INCLUDE_PATH",
                 "CPLUS_INCLUDE_PATH", "GCC_EXEC_PREFIX", "COMPILER_PATH"):
        environment.pop(name, None)
    environment["LC_ALL"] = "C"
    return environment


def require_linux_executable(path, name, elf=False):
    path = Path(path)
    try:
        with path.open("rb") as stream:
            header = stream.read(4)
    except OSError as error:
        raise BenchmarkError("Cannot inspect {} executable: {}".format(name, error)) from error
    if path.suffix.lower() == ".exe" or header[:2] == b"MZ" or (elf and header != b"\x7fELF"):
        raise BenchmarkError("{} must be a native Linux executable, found {}".format(name, path))
    if not os.access(str(path), os.X_OK):
        raise BenchmarkError("{} is not executable: {}".format(name, path))


def check_prerequisites(repo_root):
    if not sys.platform.startswith("linux"):
        raise BenchmarkError("Run this script with Linux Python inside WSL2, not Windows Python.")
    environment = clean_environment()
    ise_platform = environment.get("ISE_PLATFORM", "")
    ise_eiffel = environment.get("ISE_EIFFEL", "")
    if ise_platform and not ise_platform.startswith("linux"):
        raise BenchmarkError("ISE_PLATFORM must identify Linux, found {!r}.".format(ise_platform))
    if ise_eiffel and (re.match(r"^[A-Za-z]:", ise_eiffel) or "\\" in ise_eiffel):
        raise BenchmarkError("ISE_EIFFEL must name the Linux EiffelStudio installation.")
    c_compiler = environment.get("ISE_C_COMPILER", "")
    if c_compiler and c_compiler != "gcc":
        raise BenchmarkError("Unset ISE_C_COMPILER or set it to gcc for this Linux benchmark.")
    tools = {}
    for name in ("ec", "finish_freezing", "gcc", "ldd"):
        executable = shutil.which(name, path=environment.get("PATH"))
        if executable is None:
            raise BenchmarkError("Required Linux tool {!r} was not found on PATH. Install/configure "
                                 "Linux EiffelStudio, GCC, make and libexpat development files.".format(name))
        require_linux_executable(executable, name, elf=(name == "ec"))
        tools[name] = executable
    if shutil.which("make", path=environment.get("PATH")) is None:
        raise BenchmarkError("Required Linux tool 'make' was not found on PATH.")
    tools["eiffel_version"] = run_checked([tools["ec"], "-version"], env=environment)
    if "linux" not in tools["eiffel_version"].lower():
        raise BenchmarkError("ec -version did not identify a Linux Eiffel compiler: " +
                             tools["eiffel_version"])
    tools["gcc_version"] = run_checked([tools["gcc"], "--version"], env=environment)
    tools["ise_platform"] = ise_platform
    tools["ise_eiffel"] = ise_eiffel
    tools["environment"] = environment
    return tools


def record_eiffel_build(code_directory, spec, tools):
    """Record generated options and verify the compiler selected by Eiffel's makefile."""
    assignments = {}
    makefile = code_directory / "Makefile"
    if not makefile.is_file():
        raise BenchmarkError("Cannot verify Eiffel's C compiler: missing {}".format(makefile))
    for line in makefile.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.match(r"^(CC|CPP|CFLAGS|CPPFLAGS|LDFLAGS|CCLDFLAGS|EIFLIB)\s*=\s*(.*)$", line)
        if match:
            assignments[match.group(1)] = match.group(2)
    if not assignments.get("CC", "").strip():
        raise BenchmarkError("Cannot verify Eiffel's C compiler: missing CC in {}".format(makefile))
    details = {"code_directory": str(code_directory), "makefile_assignments": assignments}
    if assignments.get("CC"):
        command = shlex.split(assignments["CC"])
        compiler = command[1] if command[0] in ("ccache", "sccache") else command[0]
        compiler_path = shutil.which(compiler, path=tools["environment"].get("PATH"))
        if compiler_path is None:
            raise BenchmarkError("Cannot resolve Eiffel's generated C compiler: {}".format(compiler))
        require_linux_executable(compiler_path, "Eiffel C compiler")
        version = run_checked([compiler_path, "--version"], env=tools["environment"])
        if "gcc" not in version.lower() and "Free Software Foundation" not in version:
            raise BenchmarkError("Eiffel selected a C compiler other than GCC: {}\n{}".format(
                assignments["CC"], version))
        details["compiler_path"] = str(Path(compiler_path).resolve())
        details["compiler_version"] = version
    tools.setdefault("eiffel_build_details", {})[spec.name] = details


def build_eiffel(repo_root, output_dir, spec, tools):
    project = output_dir / "builds" / spec.name
    project.mkdir(parents=True, exist_ok=True)
    code_directory = project / "EIFGENs" / spec.target / spec.code_directory
    executable = code_directory / "xpact_benchmarks"
    for suffix in ("-eiffel.log", "-c.log"):
        previous_log = output_dir / "logs" / (spec.name + suffix)
        if previous_log.exists():
            previous_log.unlink()
    # Invalidate the old executable before generation, including a failed rebuild.
    if executable.exists():
        executable.unlink()
    command = [tools["ec"], "-batch", "-clean"]
    if spec.mode == "Finalized":
        command.append("-finalize")
        if spec.assertions:
            command.append("-keep")
    command.extend(["-config", repo_root / "benchmarks" / "xpact_benchmarks.ecf",
                    "-target", spec.target, "-project_path", project])
    print("Building Eiffel {} with Linux GCC...".format(spec.name), flush=True)
    run_checked(command, cwd=repo_root, env=tools["environment"],
                log_path=output_dir / "logs" / (spec.name + "-eiffel.log"))
    if not code_directory.is_dir():
        raise BenchmarkError("Eiffel generation did not create {}".format(code_directory))
    run_checked([tools["finish_freezing"]], cwd=code_directory, env=tools["environment"],
                log_path=output_dir / "logs" / (spec.name + "-c.log"))
    if not executable.is_file():
        raise BenchmarkError("Eiffel build did not create {}".format(executable))
    require_linux_executable(executable, "Eiffel benchmark", elf=True)
    record_eiffel_build(code_directory, spec, tools)
    assertion_label = "enabled" if spec.assertions else "discarded"
    name = "xpact Eiffel {}, assertions {} via WSL2 gcc".format(spec.mode.lower(), assertion_label)
    notes = "Linux EiffelStudio/GCC; parser reused; no-op event handler; Linux process wall time"
    result = []
    for suspend_gc in (False, True):
        result.append(Engine(
            name + (", GC suspended during parse" if suspend_gc else ""), executable,
            ("--suspend-gc",) if suspend_gc else (), tools["eiffel_version"],
            notes + ("; calls parse_without_garbage_collection" if suspend_gc else ""),
            tools["environment"],
        ))
    return result


def build_libexpat(repo_root, output_dir, tools):
    executable = output_dir / "libexpat_c_benchmark"
    for name in ("libexpat-c.log", "libexpat-ldd.log"):
        previous_log = output_dir / "logs" / name
        if previous_log.exists():
            previous_log.unlink()
    if executable.exists():
        executable.unlink()
    print("Building distro libexpat C benchmark with GCC -O2...", flush=True)
    run_checked([tools["gcc"], "-O2", repo_root / "benchmarks" / "libexpat_c_benchmark.c",
                 "-lexpat", "-o", executable], cwd=repo_root, env=tools["environment"],
                log_path=output_dir / "logs" / "libexpat-c.log")
    if not executable.is_file():
        raise BenchmarkError("GCC did not create {}".format(executable))
    require_linux_executable(executable, "libexpat benchmark", elf=True)
    dependencies = run_checked([tools["ldd"], executable], env=tools["environment"],
                               log_path=output_dir / "logs" / "libexpat-ldd.log")
    match = re.search(r"^\s*libexpat\.so[^\s]*\s+=>\s+(/\S+)", dependencies, re.MULTILINE)
    if match is None:
        raise BenchmarkError("Cannot identify the system libexpat dependency; see libexpat-ldd.log.")
    library = Path(match.group(1)).resolve()
    if not any(root == library.parent or root in library.parents
               for root in (Path("/usr/lib"), Path("/usr/lib64"), Path("/lib"), Path("/lib64"))):
        raise BenchmarkError("libexpat resolved outside the distro library directories: {}".format(library))
    version = run_checked([executable, "--version"], env=tools["environment"])
    if "xpact" in version.lower() or not version.startswith("expat_"):
        raise BenchmarkError("Expected distro Expat version, found {!r}.".format(version))
    tools["libexpat_version"] = version
    tools["libexpat_library"] = str(library)
    return [Engine(
        "libexpat C {} via WSL2 gcc".format(mode), executable, ("--mode", mode), version,
        "GCC -O2; distro libexpat; parser created per document; {}; Linux process wall time".format(
            "C callbacks" if mode == "callbacks" else "no callbacks"), tools["environment"],
    ) for mode in ("callbacks", "tokenizer")]


def measure_engine(engine, iterations, repetitions):
    command = [engine.executable] + list(engine.arguments) + ["--iterations", str(iterations)]
    print("Measuring {}...".format(engine.name), flush=True)
    run_checked(command, env=engine.environment)  # One untimed, full-workload warmup.
    rows = []
    byte_count = sample_document_bytes()
    for repetition in range(1, repetitions + 1):
        start = time.perf_counter()
        run_checked(command, env=engine.environment)
        seconds = time.perf_counter() - start
        if seconds <= 0:
            raise BenchmarkError("Nonpositive elapsed time for " + engine.name)
        rows.append({
            "Benchmark": "catalog-100-items", "Engine": engine.name, "Version": engine.version,
            "Repetition": repetition, "Iterations": iterations, "DocumentBytes": byte_count,
            "ElapsedMs": round(seconds * 1000, 3),
            "DocsPerSecond": round(iterations / seconds, 3),
            "MiBPerSecond": round(iterations * byte_count / (1024 * 1024) / seconds, 3),
            "Notes": engine.notes,
        })
    return rows


def clear_reports(output_dir):
    for name in REPORT_NAMES:
        report = output_dir / name
        if report.exists():
            report.unlink()


def markdown_cell(value):
    return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def render_summary(rows, metadata):
    grouped = {}
    for row in rows:
        grouped.setdefault(row["Engine"], []).append(row)
    lines = [
        "# WSL2 GCC benchmarks", "", "Generated: " + metadata["generated_utc"], "",
        "Linux: " + metadata["os"], "",
        "Eiffel: " + markdown_cell(metadata["eiffel_version"]), "",
        "GCC: " + markdown_cell(metadata["gcc_version"].splitlines()[0]), "",
        "Expat: {} ({})".format(metadata["libexpat_version"], metadata["libexpat_library"]), "",
        "Workload: the same 2611-byte UTF-8 catalog with 100 item elements; {} documents per run."
        .format(metadata["iterations"]), "",
        "Each engine has one untimed warmup. Values are the lower median of {} measured runs. "
        "Times include Linux process startup and exclude compilation and wsl.exe startup."
        .format(metadata["repetitions"]), "",
        "| Engine | Median elapsed ms | Docs/sec | MiB/sec | Notes |",
        "|---|---:|---:|---:|---|",
    ]
    for engine_rows in grouped.values():
        ordered = sorted(engine_rows, key=lambda row: row["ElapsedMs"])
        row = ordered[(len(ordered) - 1) // 2]
        lines.append("| {} | {} | {} | {} | {} |".format(*[
            markdown_cell(row[key]) for key in
            ("Engine", "ElapsedMs", "DocsPerSecond", "MiBPerSecond", "Notes")]))
    lines.extend([
        "", "Using one Linux environment reduces OS and launch differences between the Eiffel "
        "and libexpat rows. Eiffel uses its own generated GCC options; the C harness uses -O2 "
        "and the installed distro libexpat. This does not isolate the effect of switching MSVC "
        "to GCC. Eiffel reuses its parser with a no-op handler; libexpat creates a parser per "
        "document, with callbacks enabled or disabled as labelled.", "",
        "Raw repetitions: benchmark-results.tsv. Toolchain and run metadata: metadata.json. "
        "Build diagnostics: logs/.", "",
    ])
    return "\n".join(lines)


def publish_reports(output_dir, rows, metadata):
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=TSV_FIELDS, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    contents = {
        "benchmark-results.tsv": buffer.getvalue(),
        "metadata.json": json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        "summary.md": render_summary(rows, metadata),
    }
    staged = []
    try:
        # Stage every report before replacing any final path.
        for name in REPORT_NAMES:
            descriptor, temporary = tempfile.mkstemp(prefix=".xpact-report-", dir=str(output_dir))
            path = Path(temporary)
            staged.append((path, output_dir / name))
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
                stream.write(contents[name])
        for temporary, destination in staged:
            temporary.replace(destination)
    except BaseException:
        clear_reports(output_dir)
        raise
    finally:
        for temporary, _ in staged:
            if temporary.exists():
                temporary.unlink()


def run_benchmarks(args):
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    clear_reports(output_dir)
    try:
        tools = check_prerequisites(REPO_ROOT)
        specs = build_specs(args.eiffel_build)
        engines = []
        for spec in specs:
            engines.extend(build_eiffel(REPO_ROOT, output_dir, spec, tools))
        engines.extend(build_libexpat(REPO_ROOT, output_dir, tools))
        rows = []
        for engine in engines:
            rows.extend(measure_engine(engine, args.iterations, args.repetitions))
        metadata = {
            "generated_utc": datetime.now(timezone.utc).isoformat(),
            "os": platform.platform(), "machine": platform.machine(),
            "python": platform.python_version(), "kernel": platform.release(),
            "os_release": (Path("/etc/os-release").read_text(encoding="utf-8")
                           if Path("/etc/os-release").is_file() else ""),
            "repository": str(REPO_ROOT), "iterations": args.iterations,
            "repetitions": args.repetitions, "warmups_per_engine": 1,
            "document_bytes": sample_document_bytes(), "eiffel_builds": [spec.name for spec in specs],
            "eiffel_version": tools["eiffel_version"], "gcc_version": tools["gcc_version"],
            "ise_platform": tools["ise_platform"], "ise_eiffel": tools["ise_eiffel"],
            "libexpat_version": tools["libexpat_version"],
            "libexpat_library": tools["libexpat_library"], "libexpat_c_flags": ["-O2"],
            "eiffel_build_details": tools.get("eiffel_build_details", {}),
            "tool_paths": {name: tools[name] for name in ("ec", "finish_freezing", "gcc", "ldd")},
            "timing": "perf_counter around Linux subprocess; compilation and wsl.exe launch excluded",
        }
        publish_reports(output_dir, rows, metadata)
    except BaseException:
        clear_reports(output_dir)
        raise
    print("WSL GCC benchmark reports written to {}".format(output_dir), flush=True)
    return rows


def main(argv=None):
    args = parse_args(argv)
    try:
        run_benchmarks(args)
    except (BenchmarkError, OSError, ValueError) as error:
        print("WSL GCC benchmark failed: {}".format(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
