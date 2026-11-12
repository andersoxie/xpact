#!/usr/bin/env python3
"""Diagnose assertion capabilities of configured Linux Eiffel compilers.

Known differences are recorded, not treated as infrastructure failures. A failed
build, timeout, or unrelated process failure prevents publication of results.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


SOURCE = Path(__file__).resolve().parent
REPO = SOURCE.parents[1]
NAMESPACE = "http://www.eiffel.com/developers/xml/configuration-1-20-0"
ATTRIBUTES = ("precondition", "postcondition", "check", "invariant", "loop", "supplier_precondition")
TAGS = {"pre": "deliberate_precondition", "post": "deliberate_postcondition",
        "check": "deliberate_check", "invariant": "deliberate_invariant",
        "loop_invariant": "deliberate_loop_invariant", "loop_variant": "deliberate_loop_variant",
        "negative_variant": "deliberate_negative_variant"}


def run(command, directory, environment, log, timeout=300):
    command = [str(part) for part in command]
    with subprocess.Popen(command, cwd=directory, env=environment,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, start_new_session=True) as process:
        try:
            output, _ = process.communicate(timeout=timeout)
        except BaseException:
            # Compiler drivers spawn C compiler/make children. Stop the entire
            # group before invalidating output so late children cannot recreate it.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            output, _ = process.communicate()
            log.write_text(output, encoding="utf-8")
            raise
    log.write_text(output, encoding="utf-8")
    return subprocess.CompletedProcess(command, process.returncode, output)


def checked(command, directory, environment, log):
    result = run(command, directory, environment, log)
    if result.returncode:
        raise RuntimeError("Command failed ({}); see {}".format(result.returncode, log))
    return result.stdout.strip()


def config_text(compiler, selection):
    ET.register_namespace("", NAMESPACE)
    system = ET.Element("system", xmlns=NAMESPACE, name="assertion_probe",
                        uuid="B360C71F-958A-4636-AABB-E893AC52B413")
    target = ET.SubElement(system, "target", name="assertion_probe")
    ET.SubElement(target, "root", {"class": "ASSERTION_PROBE", "feature": "make"})
    option = ET.SubElement(target, "option")
    flags = {key: str(selection == "all_on" or
                      (selection == "supplier_only" and key == "supplier_precondition")).lower()
             for key in ATTRIBUTES}
    ET.SubElement(option, "assertions", flags)
    ET.SubElement(target, "setting", name="console_application", value="true")
    capability = ET.SubElement(target, "capability")
    ET.SubElement(capability, "concurrency", support="none")
    ET.SubElement(capability, "void_safety", support="all", use="all")
    ET.SubElement(target, "external_cflag", value="-O2")
    library = ("$GOBO/library/free_elks/library.ecf" if compiler == "Gobo" else
               "$ISE_LIBRARY/library/base/base.ecf")
    ET.SubElement(target, "library", name="base", location=library)
    ET.SubElement(target, "cluster", name="probe", location=SOURCE.as_posix())
    return ET.tostring(system, encoding="unicode")


def build(compiler, selection, output, environment):
    directory = output / (compiler + "-" + selection)
    directory.mkdir(parents=True, exist_ok=True)
    config = directory / "probe.ecf"
    config.write_text(config_text(compiler, selection), encoding="utf-8")
    if compiler == "Gobo":
        candidates = [directory / ".gobo", directory]
    else:
        candidates = [directory / "EIFGENs" / "assertion_probe" / "F_code"]
    executables = [path / "assertion_probe" for path in candidates]
    scripts = [path / "assertion_probe.sh" for path in candidates] if compiler == "Gobo" else []
    for artifact in executables + scripts:
        artifact.unlink(missing_ok=True)
    print("Building {} {}...".format(compiler, selection), flush=True)
    try:
        if compiler == "Gobo":
            code = compile_gobo(config, directory, scripts, environment)
        else:
            code = compile_eiffelstudio(config, selection, directory, candidates[0], environment)
        executable = code / "assertion_probe"
        with executable.open("rb") as stream:
            if stream.read(4) != b"\x7fELF":
                raise RuntimeError("Compiler did not produce a native Linux probe")
    except BaseException:
        for stale in executables:
            stale.unlink(missing_ok=True)
        raise
    return executable, directory


def compile_gobo(config, directory, scripts, environment):
    """gec, then its one generated C build script; return the code directory."""
    checked(["gec", "--finalize", "--gc=boehm", "--cc=no", config], directory,
            environment, directory / "eiffel.log")
    generated = [script for script in scripts if script.is_file()]
    if len(generated) != 1:
        raise RuntimeError("Gobo did not create exactly one fresh build script")
    code = generated[0].parent
    checked(["sh", "-e", generated[0]], code, environment, directory / "c.log")
    return code


def compile_eiffelstudio(config, selection, directory, code, environment):
    """ec -finalize (with -keep unless all assertions are off), then finish_freezing."""
    command = ["ec", "-batch", "-clean", "-finalize"] + (["-keep"] if selection != "all_off" else [])
    command.extend(["-config", config, "-target", "assertion_probe", "-project_path", directory])
    checked(command, directory, environment, directory / "eiffel.log")
    checked(["finish_freezing"], code, environment, directory / "c.log")
    return code


def investigate(args):
    output = args.output_dir.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = output / "results.json"
    if report.exists():
        report.unlink()
    if not sys.platform.startswith("linux"):
        raise RuntimeError("Run with Linux Python in the configured compiler environment")
    environment = probe_environment()
    results = {"generated_utc": datetime.now(timezone.utc).isoformat(),
               "platform": platform.platform(), "compilers": {}, "cases": [],
               "source_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                 for path in SOURCE.glob("*.e")}}
    results["gcc_version"] = checked(["gcc", "--version"], output, environment, output / "gcc.log")
    for compiler in args.compiler:
        tool = "gec" if compiler == "Gobo" else "ec"
        results["compilers"][compiler] = {
            "path": shutil.which(tool, path=environment.get("PATH")),
            "version": checked([tool, "--version" if compiler == "Gobo" else "-version"],
                               output, environment, output / (compiler + "-version.log"))}
        for selection in args.selection:
            executable, directory = build(compiler, selection, output, environment)
            results["cases"] += [probe_case(compiler, selection, mode, tag, executable, directory, environment)
                                 for mode, tag in TAGS.items()]
    results["all_requested_checks_match"] = all(row["matches_requested_setting"] for row in results["cases"])
    write_report(results, output, report)
    print("Diagnostic results written to {}".format(report), flush=True)


def probe_environment():
    """The caller's environment without loader/compiler overrides that would change what is measured."""
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(("GOBO_CLI_", "GOBO_DEFAULT_"))}
    for key in ("LD_LIBRARY_PATH", "LD_PRELOAD", "LIBRARY_PATH", "CPATH", "C_INCLUDE_PATH",
                "CPLUS_INCLUDE_PATH", "BOEHM_GC"):
        environment.pop(key, None)
    environment.update(GOBO_CC="gcc", GOBO_EIFFEL="ge", LC_ALL="C")
    return environment


def probe_case(compiler, selection, mode, tag, executable, directory, environment):
    """Run one assertion mode; the row says whether the violation was detected as requested."""
    result = run([executable, mode], directory, environment, directory / (mode + ".log"), 15)
    completed = "PROBE_COMPLETED " + mode in result.stdout
    detected = result.returncode != 0 and tag in result.stdout and not completed
    if not detected and not (result.returncode == 0 and completed):
        raise RuntimeError("Unrelated probe failure for {} {} {}; see {}".format(
            compiler, selection, mode, directory / (mode + ".log")))
    expected = selection == "all_on" or (selection == "supplier_only" and mode == "pre")
    print("{} {} {}: {} (requested {})".format(
        compiler, selection, mode, "detected" if detected else "completed",
        "detection" if expected else "no detection"), flush=True)
    return {"compiler": compiler, "selection": selection, "assertion": mode,
            "expected_violation": expected, "detected_violation": detected,
            "matches_requested_setting": detected == expected,
            "exit_code": result.returncode, "diagnostic": result.stdout}


def write_report(results, output, report):
    """Write results.json atomically: a stopped run never leaves a partial report."""
    descriptor, staging = tempfile.mkstemp(prefix=".assertion-report-", dir=output)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(results, stream, indent=2)
            stream.write("\n")
        Path(staging).replace(report)
    finally:
        Path(staging).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=REPO / "build" / "compiler-assertions")
    parser.add_argument("--compiler", action="append", choices=("Gobo", "EiffelStudio"))
    parser.add_argument("--selection", action="append", choices=("all_on", "all_off", "supplier_only"))
    args = parser.parse_args()
    args.compiler = list(dict.fromkeys(args.compiler or ("Gobo", "EiffelStudio")))
    args.selection = list(dict.fromkeys(args.selection or ("all_on", "all_off", "supplier_only")))
    try:
        investigate(args)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
