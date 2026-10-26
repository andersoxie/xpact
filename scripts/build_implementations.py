#!/usr/bin/env python3
"""Build isolated parser probes, catalog or W3C executables and record provenance."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

from prepare_xpact_core import DependencyError, prepare_dependency, run_git


class BuildError(RuntimeError):
    """No verified build artifact can be published."""


GC_POLICIES = {"xpact": "normal", "xpact-core": "core-managed-off-full-collect"}


def write_json_atomic(path, value):
    path = Path(path)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n",
                                         dir=path.parent, prefix=path.name + ".", suffix=".tmp",
                                         delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(value, stream, indent=2, ensure_ascii=True)
            stream.write("\n")
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def file_sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_fingerprint(repo_root, implementation, profile="probe"):
    """Hash selected source/build inputs, excluding generated identities."""
    root = Path(repo_root)
    if profile == "probe":
        source = root / "tools/implementation_probe" / implementation.replace("-", "_")
        directories = [source]
    elif profile == "catalog":
        source = root / "benchmarks/dual_catalog"
        directories = [source / "shared", source / implementation.replace("-", "_")]
    elif profile == "w3c":
        source = root / "benchmarks/dual_w3c"
        directories = [source / "shared", source / implementation.replace("-", "_")]
    else:
        raise BuildError("Unknown build profile: " + str(profile))
    paths = [path for directory in directories for pattern in ("*.e", "*.ecf")
             for path in directory.rglob(pattern)]
    paths += [root / "scripts/build_implementations.py", root / "scripts/prepare_xpact_core.py",
              root / "dependencies/xpact-core.json"]
    if profile == "catalog":
        paths += [root / relative for relative in ("scripts/run_dual_catalog.py",
                  "scripts/run_dual_catalog.ps1", "scripts/compare_eiffel_benchmarks.py")
                  if (root / relative).is_file()]
    elif profile == "w3c":
        paths += [root / relative for relative in ("scripts/run_dual_w3c.py",
                  "scripts/run_dual_w3c.ps1", "scripts/run_w3c_conformance.py")
                  if (root / relative).is_file()]
    if implementation == "xpact":
        paths += list((root / "src").rglob("*.e"))
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(path.relative_to(root).as_posix().encode("utf-8") + b"\0")
        digest.update(bytes.fromhex(file_sha256(path)))
    return digest.hexdigest()


def run_checked(command, *, cwd=None, env=None, log_path=None, timeout=1200):
    command = [str(value) for value in command]
    try:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, encoding="utf-8", errors="replace",
                                timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        if log_path is not None:
            Path(log_path).write_text(str(error) + "\n", encoding="utf-8")
        raise BuildError("Cannot complete {}: {}".format(command[0], error)) from error
    output = result.stdout or ""
    if log_path is not None:
        Path(log_path).write_text(json.dumps(command) + "\n" + output, encoding="utf-8")
    if result.returncode:
        raise BuildError("{} exited {}. See {}.\n{}".format(
            command[0], result.returncode, log_path or "command output", output[-5000:]))
    return output.strip()


def toolchain():
    if sys.platform != "win32":
        raise BuildError("This first build lane requires Windows x64 and MSVC. "
                         "WSL integration follows in the benchmark step.")
    environment = dict(os.environ)
    tools = {}
    for name in ("ec", "finish_freezing", "cl"):
        tools[name] = shutil.which(name, path=environment.get("PATH"))
        if not tools[name]:
            raise BuildError("Missing {}. Run scripts/build_implementations.ps1 from an "
                             "EiffelStudio environment.".format(name))
    if environment.get("VSCMD_ARG_TGT_ARCH", "").lower() != "x64":
        raise BuildError("An x64 MSVC environment is required; use build_implementations.ps1.")
    installation = Path(environment.get("ISE_EIFFEL") or Path(tools["ec"]).resolve().parents[4])
    environment.setdefault("ISE_EIFFEL", str(installation))
    environment.setdefault("ISE_LIBRARY", str(installation))
    environment["ISE_PLATFORM"] = "win64"
    environment["ISE_C_COMPILER"] = "msc_vc140"
    required = ("library/base/base.ecf", "library/base_extension/base_extension.ecf",
                "library/time/time.ecf", "C_library/zlib/clibs_zlib.ecf",
                "C_library/zlib/spec/msc_vc140/win64/lib/zlib.lib")
    library_root = Path(environment["ISE_LIBRARY"])
    dependencies = []
    for relative in required:
        path = library_root / relative
        if not path.is_file():
            raise BuildError("Missing EiffelStudio dependency: " + str(path))
        dependencies.append({"path": str(path), "sha256": file_sha256(path)})
    return tools, environment, {
        "platform": platform.platform(), "architecture": "x64",
        "eiffel_compiler": tools["ec"],
        "eiffel_version": run_checked([tools["ec"], "-version"], env=environment),
        "c_compiler": tools["cl"],
        "c_compiler_version": run_checked([tools["cl"]], env=environment),
        "ise_eiffel": environment["ISE_EIFFEL"], "ise_library": environment["ISE_LIBRARY"],
        "ise_c_compiler": environment["ISE_C_COMPILER"], "dependencies": dependencies,
    }


def write_identity(directory, implementation, revision, configuration):
    directory.mkdir()
    values = {"implementation_id": implementation, "source_revision": revision,
              "build_configuration": configuration}
    # All generated values are controlled identifiers, never arbitrary Eiffel source.
    if not all(re.fullmatch(r"[a-zA-Z0-9/_.-]+", value) for value in values.values()):
        raise BuildError("Invalid build identity")
    lines = ["class XP_BUILD_IDENTITY", "feature -- Build identity"]
    lines += ['\t{}: STRING = "{}"'.format(name, value) for name, value in values.items()]
    lines.append("end\n")
    (directory / "xp_build_identity.e").write_text("\n".join(lines), encoding="utf-8")


def validate_probe(output, implementation, revision, configuration):
    expected = "\t".join(("XPACT_BUILD_PROBE", implementation, revision, configuration, "OK"))
    markers = [line for line in output.splitlines() if line.startswith("XPACT_BUILD_PROBE")]
    if markers != [expected]:
        raise BuildError("Probe did not confirm the expected implementation/revision/configuration: "
                         + repr(markers))


def validate_catalog_identity(output, implementation, revision, configuration):
    expected = "\t".join(("XPACT_CATALOG_IDENTITY", implementation, revision,
                           configuration, GC_POLICIES[implementation]))
    if output.splitlines() != [expected]:
        raise BuildError("Catalog executable did not confirm the expected identity/GC policy: "
                         + repr(output))
    return GC_POLICIES[implementation]


def validate_w3c_identity(output, implementation, revision, configuration):
    expected = "\t".join(("XPACT_W3C_IDENTITY", implementation, revision,
                           configuration, GC_POLICIES[implementation]))
    if output.splitlines() != [expected]:
        raise BuildError("W3C executable did not confirm the expected identity/GC policy: "
                         + repr(output))
    return GC_POLICIES[implementation]


def makefile_settings(code_directory):
    path = code_directory / "Makefile"
    assignments = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.match(r"^(CC|CPP|CFLAGS|CPPFLAGS|LDFLAGS|CCLDFLAGS|EIFLIB)\s*=\s*(.*)$", line)
        if match:
            assignments[match[1]] = match[2]
    if assignments.get("CC", "").strip().lower() not in ("cl", "cl.exe"):
        raise BuildError("Eiffel did not generate the expected MSVC build: " + repr(assignments))
    return assignments


def build_one(repo_root, run_root, implementation, tools, environment, compiler_metadata,
              *, offline=False, profile="probe", assertions=True):
    if implementation not in GC_POLICIES or profile not in ("probe", "catalog", "w3c"):
        raise BuildError("Unknown implementation or build profile")
    if type(assertions) is not bool:
        raise BuildError("assertions must be a boolean")
    root = Path(repo_root)
    destination = Path(run_root) / implementation
    destination.mkdir()
    manifest = destination / "build.json"
    configuration = "finalized/assertions-{}/msvc-x64".format("on" if assertions else "off")
    fingerprint = source_fingerprint(root, implementation, profile)
    source_status = run_git(["status", "--porcelain", "--untracked-files=all"], root)
    if implementation == "xpact-core":
        source = prepare_dependency(root, offline=offline)
        revision = source["revision"]
    else:
        revision = run_git(["rev-parse", "HEAD"], root).strip()
        source = {"repository": run_git(["remote", "get-url", "origin"], root).strip(),
                  "revision": revision, "source_dir": str(root), "source_sha256": fingerprint,
                  "worktree_dirty": bool(source_status)}
    generated = destination / "metadata"
    write_identity(generated, implementation, revision, configuration)
    build_environment = dict(environment)
    build_environment.update({"XPACT_SOURCE_ROOT": str(root), "XPACT_PROBE_METADATA": str(generated)})
    helpers = []
    if implementation == "xpact-core":
        core = Path(source["source_dir"])
        build_environment.update({"XPACT_CORE": str(core),
                                  "XPACT_INCLUDE": str(core / "contrib/xpact/include"),
                                  "C_SHIFT_JIS_SUBSET": str(core / "C-tools/shift_jis_subset")})
        # Upstream's ECF supplies this codec's archive only on Unix. Build the
        # same pinned C source for MSVC outside the immutable source checkout.
        helper_source = core / "C-tools/shift_jis_subset/src/shift_jis_subset.c"
        helper_object = destination / "shift_jis_subset.obj"
        helper_command = [tools["cl"], "/nologo", "/O2", "/MT", "/c",
                          "/I" + str(core / "C-tools/shift_jis_subset/include"),
                          str(helper_source), "/Fo:" + str(helper_object)]
        run_checked(helper_command, cwd=destination, env=build_environment,
                    log_path=destination / "shift-jis.log")
        helpers.append({"source": str(helper_source), "source_sha256": file_sha256(helper_source),
                        "object": str(helper_object), "object_sha256": file_sha256(helper_object),
                        "command": helper_command})
        build_environment["XPACT_SHIFT_JIS_OBJECT"] = str(helper_object)
    suffix = {"probe": "_build_probe", "catalog": "_catalog_benchmark", "w3c": "_w3c_conformance"}[profile]
    name = implementation.replace("-", "_") + suffix
    project = destination / "project"
    project.mkdir()
    if profile == "probe":
        ecf = root / "tools/implementation_probe" / implementation.replace("-", "_") / "probe.ecf"
        target = "probe"
    elif profile == "catalog":
        ecf = root / "benchmarks/dual_catalog" / implementation.replace("-", "_") / "catalog.ecf"
        target = "catalog_assertions" if assertions else "catalog"
    else:
        ecf = root / "benchmarks/dual_w3c" / implementation.replace("-", "_") / "conformance.ecf"
        target = "conformance_assertions" if assertions else "conformance"
    command = [tools["ec"], "-batch", "-clean", "-finalize"]
    if assertions:
        command.append("-keep")
    command += ["-config", str(ecf), "-target", target, "-project_path", str(project)]
    print("Building {} ({})".format(implementation, configuration), flush=True)
    run_checked(command, cwd=root, env=build_environment, log_path=destination / "eiffel.log")
    code = project / "EIFGENs" / target / "F_code"
    run_checked([tools["finish_freezing"]], cwd=code, env=build_environment,
                log_path=destination / "c.log")
    executable = code / (name + ".exe")
    if not executable.is_file():
        raise BuildError("Expected isolated executable was not created: " + str(executable))
    flags = makefile_settings(code)
    verification_command = [executable] + (["--identity"] if profile != "probe" else [])
    output = run_checked(verification_command, cwd=destination, env=build_environment,
                         log_path=destination / ("probe.log" if profile == "probe" else "identity.log"),
                         timeout=30)
    if profile == "catalog":
        validate_catalog_identity(output, implementation, revision, configuration)
    elif profile == "w3c":
        validate_w3c_identity(output, implementation, revision, configuration)
    else:
        validate_probe(output, implementation, revision, configuration)
    if source_fingerprint(root, implementation, profile) != fingerprint:
        raise BuildError("Build inputs changed while compiling " + implementation)
    if implementation == "xpact-core":
        verified = prepare_dependency(root, offline=True)
        if verified != source:
            raise BuildError("Pinned dependency changed while compiling")
    elif run_git(["rev-parse", "HEAD"], root).strip() != revision:
        raise BuildError("Repository revision changed while compiling")
    metadata = {
        "schema_version": 1, "status": "verified", "implementation": implementation,
        "profile": profile,
        "source": source, "build_inputs_sha256": fingerprint,
        "build": {"configuration": configuration, "mode": "finalized", "assertions": assertions,
                  "void_safety": "all", "command": command, "makefile": flags,
                  "native_helpers": helpers},
        "toolchain": compiler_metadata,
        "executable": str(executable), "executable_sha256": file_sha256(executable),
        "probe_output": output,
    }
    if profile != "probe":
        metadata["gc_policy"] = GC_POLICIES[implementation]
    write_json_atomic(manifest, metadata)
    print("Verified {}: {}".format(implementation, manifest), flush=True)
    return {"implementation": implementation, "status": "verified", "manifest": str(manifest)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--implementation", choices=("both", "xpact", "xpact-core"), default="both")
    parser.add_argument("--offline", action="store_true", help="Require an already verified core checkout")
    parser.add_argument("--profile", choices=("probe", "catalog", "w3c"), default="probe")
    parser.add_argument("--assertions", choices=("on", "off"), default="on")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    # Unique runs preserve prior evidence and cannot consume another run's executable/report.
    runs = root / "build/implementations"
    runs.mkdir(parents=True, exist_ok=True)
    run_root = runs / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:12])
    run_root.mkdir()
    state = {"schema_version": 1, "status": "running", "results": []}
    try:
        write_json_atomic(run_root / "run.json", state)
        tools, environment, compiler_metadata = toolchain()
        selected = ("xpact", "xpact-core") if args.implementation == "both" else (args.implementation,)
        for implementation in selected:
            try:
                result = build_one(root, run_root, implementation, tools, environment,
                                   compiler_metadata, offline=args.offline, profile=args.profile,
                                   assertions=args.assertions == "on")
            except (BuildError, DependencyError, OSError, ValueError) as error:
                result = {"implementation": implementation, "status": "failed", "error": str(error)}
                print(str(error), file=sys.stderr)
            state["results"].append(result)
        state["status"] = "verified" if all(row["status"] == "verified" for row in state["results"]) else "failed"
    except (BuildError, DependencyError, OSError, ValueError) as error:
        state.update(status="failed", error=str(error))
        print(str(error), file=sys.stderr)
    try:
        write_json_atomic(run_root / "run.json", state)
    except OSError as error:
        print("Cannot publish run status: " + str(error), file=sys.stderr)
        return 1
    print("Build results: " + str(run_root / "run.json"), flush=True)
    return 0 if state["status"] == "verified" else 1


if __name__ == "__main__":
    sys.exit(main())
