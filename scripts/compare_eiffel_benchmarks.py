#!/usr/bin/env python3
"""Compare two native Eiffel benchmark executables using sequential AB/BA pairs."""

import argparse
import csv
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import io
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tempfile
import time


MAX_ITERATIONS = 2147483647
REPORT_NAMES = ("comparison.json", "comparison.tsv")
FIELDS = ("Workload", "Pair", "Order", "Iterations", "DocumentBytes",
          "BaselineElapsedMs", "CandidateElapsedMs", "BaselineMiBPerSecond",
          "CandidateMiBPerSecond", "CandidateSpeedRatio")


class BenchmarkError(RuntimeError):
    """A benchmark could not produce a trustworthy measurement."""


@dataclass(frozen=True)
class Workload:
    name: str
    path: object
    document_bytes: int
    iterations: int


def positive_int(value):
    number = int(value)
    if not 1 <= number <= MAX_ITERATIONS:
        raise argparse.ArgumentTypeError("must be between 1 and 2147483647")
    return number


def nonnegative_float(value):
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise argparse.ArgumentTypeError("must be finite and nonnegative")
    return number


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path,
                        default=Path(__file__).resolve().parents[1] / "build/eiffel-comparison")
    parser.add_argument("--workload", action="append", choices=("catalog", "text", "attributes", "files"))
    parser.add_argument("--xml-file", type=Path, action="append", default=[])
    parser.add_argument("--iterations", type=positive_int, default=10000)
    parser.add_argument("--file-iterations", type=positive_int, default=1000)
    parser.add_argument("--xml-iterations", type=positive_int, default=32)
    parser.add_argument("--pairs", type=positive_int, default=6)
    parser.add_argument("--warmups", type=positive_int, default=2)
    parser.add_argument("--min-sample-seconds", type=nonnegative_float, default=1.0)
    parser.add_argument("--timeout-seconds", type=positive_int,
                        help="Optional maximum duration of one benchmark process")
    args = parser.parse_args(argv)
    for name in ("baseline", "candidate", "output_dir"):
        setattr(args, name, getattr(args, name).expanduser().resolve())
    args.xml_file = [path.expanduser().resolve() for path in args.xml_file]
    return args


def preflight_inputs(args):
    """Reject input/output aliases before invalidating reports or writing fixtures."""
    output = Path(args.output_dir).expanduser().resolve()
    reserved = [output / name for name in REPORT_NAMES]
    reserved += [output / "fixtures" / name for name in ("text.xml", "attributes.xml")]
    reserved = [path.resolve() for path in reserved]
    inputs = [("baseline", args.baseline), ("candidate", args.candidate)]
    inputs += [("XML input", path) for path in args.xml_file]
    for role, source in inputs:
        source = Path(source).expanduser().resolve()
        for destination in reserved:
            collision = source == destination
            if not collision:
                try:
                    collision = source.samefile(destination)
                except OSError:
                    # Missing or unreadable noncolliding inputs follow normal failure cleanup.
                    pass
            if collision:
                raise BenchmarkError("The {} {} aliases a reserved generated output {}. "
                                     "Choose a separate input or output directory.".format(
                                         role, source, destination))


def prepare_workloads(args):
    selected = list(dict.fromkeys(args.workload or
                    (["catalog", "text", "attributes"] + (["files"] if args.xml_file else []))))
    documents = {
        "text": "<root>" + "plain text " * 10000 + "</root>",
        "attributes": "<root>" + ("<item " + " ".join('a{:02d}="value"'.format(i)
                      for i in range(50)) + "/>") * 20 + "</root>",
    }
    workloads = []
    for name in selected:
        if name == "catalog":
            document = "<catalog>" + "".join('<item id="{}">value</item>'.format(i)
                       for i in range(1, 101)) + "</catalog>"
            workloads.append(Workload(name, None, len(document.encode("utf-8")), args.iterations))
        elif name in documents:
            path = args.output_dir / "fixtures" / (name + ".xml")
            path.parent.mkdir(parents=True, exist_ok=True)
            content = documents[name].encode("utf-8")
            path.write_bytes(content)
            workloads.append(Workload(name, path, len(content), args.file_iterations))
        else:
            if not args.xml_file:
                raise BenchmarkError("The files workload requires at least one --xml-file.")
            for index, path in enumerate(dict.fromkeys(args.xml_file), 1):
                workloads.append(Workload("file-{}:{}".format(index, path.name), path,
                                          path.stat().st_size, args.xml_iterations))
    return workloads


def run_sample(executable, iterations, workload, phase, output_dir, timeout=None):
    command = [str(executable), "--iterations", str(iterations)]
    if workload.path is not None:
        command += ["--file", str(workload.path)]
    work = output_dir / "work"
    work.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter()
    try:
        completed = subprocess.run(command, cwd=work, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, universal_newlines=True,
                                   encoding="utf-8", errors="replace", timeout=timeout)
        elapsed = time.perf_counter() - start
        expected = "xpact benchmark harness parsed {} documents.".format(iterations)
        if completed.returncode == 0 and completed.stdout.strip() == expected and elapsed > 0:
            return elapsed
        details = "exit={}\nstdout:\n{}\nstderr:\n{}".format(
            completed.returncode, completed.stdout, completed.stderr)
    except (OSError, subprocess.TimeoutExpired) as error:
        details = str(error)
    logs = output_dir / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    safe_phase = "".join(c if c.isalnum() or c in "-_." else "_" for c in phase)
    log = logs / (safe_phase + ".log")
    log.write_text(json.dumps(command) + "\n" + details, encoding="utf-8")
    raise BenchmarkError("Invalid benchmark result for {}. See {}".format(phase, log))


def clear_reports(output_dir):
    for name in REPORT_NAMES:
        path = output_dir / name
        if path.exists():
            path.unlink()


def publish_reports(output_dir, report):
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(report["results"])
    contents = (json.dumps(report, indent=2) + "\n", buffer.getvalue())
    staged = []
    try:
        for name, content in zip(REPORT_NAMES, contents):
            descriptor, temporary = tempfile.mkstemp(prefix=".comparison-", dir=str(output_dir))
            path = Path(temporary)
            staged.append((path, output_dir / name))
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
                stream.write(content)
        for temporary, destination in staged:
            temporary.replace(destination)
    except BaseException:
        clear_reports(output_dir)
        raise
    finally:
        for temporary, _ in staged:
            if temporary.exists():
                temporary.unlink()


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_comparison(args):
    # This guard must remain outside cleanup: a colliding report may be the input itself.
    preflight_inputs(args)
    output = args.output_dir
    output.mkdir(parents=True, exist_ok=True)
    clear_reports(output)
    try:
        executables = {"A": args.baseline, "B": args.candidate}
        identities = {role: {"path": str(path), "sha256": file_hash(path)}
                      for role, path in executables.items()}
        workloads = prepare_workloads(args)
        report = {"metadata": {"started_utc": datetime.now(timezone.utc).isoformat(),
                  "platform": platform.platform(), "python": platform.python_version(),
                  "executables": identities, "warmups": args.warmups, "pairs": args.pairs,
                  "min_sample_seconds": args.min_sample_seconds,
                  "method": "sequential native process wall time; alternating AB/BA pairs; speed ratio = baseline time / candidate time",
                  "workloads": [{"name": w.name, "path": str(w.path) if w.path else None,
                                 "document_bytes": w.document_bytes,
                                 "initial_iterations": w.iterations,
                                 "sha256": file_hash(w.path) if w.path else None} for w in workloads]},
                  "calibration": [], "results": [], "summary": []}
        for workload in workloads:
            count = workload.iterations
            print("Comparing {}...".format(workload.name), flush=True)
            def sample(role, phase):
                arguments = (executables[role], count, workload,
                             workload.name + "-" + phase + "-" + role, output)
                if args.timeout_seconds is not None:
                    return run_sample(*arguments, timeout=args.timeout_seconds)
                return run_sample(*arguments)
            if args.min_sample_seconds > 0:
                while True:
                    baseline, candidate = sample("A", "calibration"), sample("B", "calibration")
                    report["calibration"].append({"Workload": workload.name, "Iterations": count,
                        "BaselineElapsedMs": baseline * 1000, "CandidateElapsedMs": candidate * 1000})
                    if min(baseline, candidate) >= args.min_sample_seconds:
                        break
                    if count == MAX_ITERATIONS:
                        raise BenchmarkError("Cannot reach minimum sample time within the signed 32-bit iteration limit.")
                    count = min(count * 2, MAX_ITERATIONS)
            for warmup in range(args.warmups):
                for role in ("AB" if warmup % 2 == 0 else "BA"):
                    sample(role, "warmup-{}".format(warmup + 1))
            rows = []
            for pair in range(1, args.pairs + 1):
                order = "AB" if pair % 2 else "BA"
                elapsed = {role: sample(role, "pair-{}".format(pair)) for role in order}
                mib = count * workload.document_bytes / 1048576
                row = dict(zip(FIELDS, (workload.name, pair, order, count, workload.document_bytes,
                      elapsed["A"] * 1000, elapsed["B"] * 1000, mib / elapsed["A"],
                      mib / elapsed["B"], elapsed["A"] / elapsed["B"])))
                rows.append(row)
                report["results"].append(row)
                print("  pair {} {}: candidate speed ratio {:.4f}".format(pair, order, row["CandidateSpeedRatio"]), flush=True)
            ratios = [row["CandidateSpeedRatio"] for row in rows]
            report["summary"].append({"workload": workload.name, "pairs": len(rows), "iterations": count,
                "document_bytes": workload.document_bytes, "median_candidate_speed_ratio": statistics.median(ratios),
                "min_candidate_speed_ratio": min(ratios), "max_candidate_speed_ratio": max(ratios),
                "median_baseline_ms": statistics.median(row["BaselineElapsedMs"] for row in rows),
                "median_candidate_ms": statistics.median(row["CandidateElapsedMs"] for row in rows),
                "min_baseline_ms": min(row["BaselineElapsedMs"] for row in rows),
                "max_baseline_ms": max(row["BaselineElapsedMs"] for row in rows),
                "min_candidate_ms": min(row["CandidateElapsedMs"] for row in rows),
                "max_candidate_ms": max(row["CandidateElapsedMs"] for row in rows)})
        publish_reports(output, report)
        return report
    except BaseException:
        clear_reports(output)
        raise


def main(argv=None):
    try:
        run_comparison(parse_args(argv))
    except (BenchmarkError, OSError, ValueError) as error:
        print("Eiffel comparison failed: {}".format(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
