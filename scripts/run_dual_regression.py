#!/usr/bin/env python3
"""Run small functional regressions on both Eiffel parsers, whole and chunked, with event traces.

Plan step 4 checkpoint (newUpdates.txt): elements, attributes, text, malformed
input and chunked input through an xpact adapter and an Xpact-core adapter,
with inspectable event traces. The inputs are the C02, CR and C10 inputs of the
C# DLL tests (#37, #121) plus a few element/attribute/text controls.

Every input runs whole, split at every byte and byte by byte. Each result is
compared with an expectation written here, independently of both parsers;
agreement between the parsers alone is not counted as correct. Accepted
documents must give exactly the expected events (adjacent text pieces joined).
Rejected documents are judged on the verdict only.

A run lives in build/dual-regression/<run-id>/ and is never reused.
Exit code: 0 = every xpact case passed, 1 = xpact failures (core results are
reported, not judged), 2 = the run could not be completed.
"""

import argparse
import csv
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import subprocess
import sys
import uuid

import build_implementations as builds
from prepare_xpact_core import DependencyError

RUN_JSON = "run.json"
SUMMARY_MD = "summary.md"

IMPLEMENTATIONS = ("xpact", "xpact-core")
def start_event(name):
    return "start:" + name


def end_event(name):
    return "end:" + name


R, T = [start_event("r"), end_event("r")], [start_event("root"), end_event("root")]


def escaped(data):
    """The same escaping as DR_TRACE: printable ASCII except \\ and | stays."""
    return "".join(chr(b) if 32 <= b < 127 and b not in (0x5C, 0x7C) else "\\x%02x" % b for b in data)


def text(data):
    return "text:" + escaped(data)


def cases():
    """(name, group, bytes, accepted, expected events or None)."""
    rows = [
        ("c02-valid", "c02", b"<root/>", True, T),
        ("c02-valid-pair", "c02", b"<root></root>", True, T),
        ("c02-text", "c02", b"<root>hi</root>", True, [start_event("root"), text(b"hi"), end_event("root")]),
        ("c02-empty", "c02", b"", False, None),
        ("c02-incomplete", "c02", b"<root>", False, None),
        ("c02-mismatched", "c02", b"<root><child></root>", False, None),
        ("c02-trailing-junk", "c02", b"<root/>junk", False, None),
        ("cr-crlf", "cr", b"<r>\r\n</r>", True, [start_event("r"), text(b"\n"), end_event("r")]),
        ("cr-lone", "cr", b"<r>\r</r>", True, [start_event("r"), text(b"\n"), end_event("r")]),
        ("cr-last-byte", "cr", b"<r/>\r", True, R),
        ("cr-attribute", "cr", b"<r a='x\ry'/>", True, R),
        ("elem-nested", "basic", b"<a><b/><c>t</c></a>", True,
         [start_event("a"), start_event("b"), end_event("b"), start_event("c"), text(b"t"), end_event("c"), end_event("a")]),
        ("attr-two", "basic", b"<a x='1' y=\"2\"/>", True, [start_event("a"), end_event("a")]),
        ("attr-duplicate", "basic", b"<a x='1' x='2'/>", False, None),
        ("attr-unquoted", "basic", b"<a x=1/>", False, None),
        ("text-entities", "basic", b"<a>&lt;&amp;&gt;</a>", True, [start_event("a"), text(b"<&>"), end_event("a")]),
        ("text-charrefs", "basic", b"<a>&#65;&#x42;</a>", True, [start_event("a"), text(b"AB"), end_event("a")]),
        ("text-whitespace", "basic", b"<a> x \n y </a>", True, [start_event("a"), text(b" x \n y "), end_event("a")]),
        ("text-undefined-entity", "basic", b"<a>&nope;</a>", False, None),
    ]
    sequences = [("valid-e9", b"\xc3\xa9", True), ("bad-continuation", b"\xc3(", False),
                 ("overlong", b"\xc0\xaf", False), ("surrogate", b"\xed\xa0\x80", False),
                 ("above-10ffff", b"\xf4\x90\x80\x80", False), ("lone-continuation", b"\x80", False),
                 ("ff", b"\xff", False)]
    places = [("text", b"<r>", b"</r>"), ("attribute", b"<r a='", b"'/>"), ("name", b"<r", b"/>"),
              ("comment", b"<r><!--", b"--></r>"), ("pi", b"<r><?pi ", b"?></r>"),
              ("cdata", b"<r><![CDATA[", b"]]></r>")]
    for seq_name, seq, valid in sequences:
        for place, before, after in places:
            events = None
            if valid:
                if place == "name":
                    events = [start_event("r") + escaped(seq), end_event("r") + escaped(seq)]
                elif place in ("text", "cdata"):
                    events = [start_event("r"), text(seq), end_event("r")]
                else:
                    events = R
            rows.append(("utf8-%s-%s" % (seq_name, place), "utf8", before + seq + after, valid, events))
    return rows


LIFECYCLE = [  # step, accepted, events (must match DR_REGRESSION_ROOT.lifecycle)
    ("1-valid", True, [start_event("root"), text(b"hi"), end_event("root")]),
    ("2-mismatched", False, None),
    ("3-valid-after-failure", True, [start_event("root"), text(b"hi"), end_event("root")]),
    ("4-incomplete", False, None),
    ("5-valid-after-incomplete", True, [start_event("a"), start_event("b"), end_event("b"), text(b"t"), end_event("a")]),
    ("6-partial-then-final", True, [start_event("root"), text(b"hi"), end_event("root")]),
    ("7-bad-utf8", False, None),
    ("8-valid-after-bad-utf8", True, [start_event("r"), text(b"ok"), end_event("r")]),
    ("9-empty", False, None),
    ("10-valid-after-empty", True, T),
]


def chunkings(data):
    names = ["whole"] + ["split@%d" % k for k in range(1, len(data))]
    return names + (["bytes"] if data else []) + (["bytes-final"] if len(data) > 1 else [])


def run_exe(executable, arguments, cwd, timeout):
    try:
        done = subprocess.run([executable] + arguments, cwd=cwd, capture_output=True, timeout=timeout)
        return done.returncode, done.stdout.decode("utf-8", "replace"), done.stderr.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        return None, "", "timeout"


def parse_lines(output, marker):
    rows = {}
    for line in output.splitlines():
        parts = line.split("\t")
        if parts and parts[0] == marker and len(parts) == 5:
            rows[parts[1]] = (parts[2], parts[3], parts[4])
    return rows


def trace_case(executable, path, names, cwd, timeout):
    """{chunking: (verdict, events)}; a crash or timeout is isolated per chunking."""
    code, out, err = run_exe(executable, ["--trace", str(path)], cwd, timeout)
    rows = parse_lines(out, "XPACT_TRACE")
    if code == 0 and set(rows) == set(names):
        return rows
    result = {}
    for name in names:
        code, out, err = run_exe(executable, ["--trace", str(path), "--chunking", name], cwd, timeout)
        one = parse_lines(out, "XPACT_TRACE")
        if code == 0 and name in one:
            result[name] = one[name]
        elif code is None:
            result[name] = ("TIMEOUT", "", "")
        else:
            result[name] = ("CRASH", "", "exit %s: %s" % (code, (err or out).strip().splitlines()[-1:] or ""))
    return result


def judge(accepted, expected_events, verdict, events):
    if verdict in ("CRASH", "TIMEOUT"):
        return verdict
    if verdict != ("ACCEPT" if accepted else "REJECT"):
        return "WRONG-VERDICT"
    if accepted and events != " | ".join(expected_events):
        return "WRONG-EVENTS"
    return "PASS"


def run_lane(repo_root, run_root, offline, timeout):
    state = {"schema_version": 1, "status": "running", "lane": "dual-regression",
             "started": datetime.now(timezone.utc).isoformat()}
    builds.write_json_atomic(run_root / RUN_JSON, state)
    fixtures = run_root / "fixtures"
    fixtures.mkdir()
    all_cases = cases()
    for name, _, data, _, _ in all_cases:
        (fixtures / (name + ".xml")).write_bytes(data)
    tools, environment, compiler_metadata = builds.toolchain()
    executables, rows, lifecycle_rows, build_errors = {}, [], [], {}
    for assertions in (True, False):
        phase = run_root / ("assertions-on" if assertions else "assertions-off")
        phase.mkdir()
        for implementation in IMPLEMENTATIONS:
            label = "%s/%s" % (implementation, "assertions-on" if assertions else "assertions-off")
            try:
                built = builds.build_one(repo_root, phase, implementation, tools, environment, compiler_metadata,
                                         offline=offline, profile="regression", assertions=assertions)
            except (builds.BuildError, DependencyError, OSError, ValueError) as error:
                # One engine's build failure must not hide the other engine's results.
                build_errors[label] = str(error).splitlines()[0][:400]
                print("%-28s BUILD FAILED: %s" % (label, build_errors[label]), flush=True)
                continue
            artifact = json.loads(Path(built["manifest"]).read_text(encoding="utf-8"))
            executables[label] = artifact
            for name, group, data, accepted, events in all_cases:
                names = chunkings(data)
                traces = trace_case(artifact["executable"], fixtures / (name + ".xml"), names,
                                    phase / implementation, timeout)
                for chunking in names:
                    verdict, observed, error = traces.get(chunking, ("MISSING", "", ""))
                    rows.append({"build": label, "case": name, "group": group, "chunking": chunking,
                                 "input": escaped(data), "expected": "ACCEPT" if accepted else "REJECT",
                                 "verdict": verdict, "result": judge(accepted, events, verdict, observed)
                                 if verdict != "MISSING" else "MISSING",
                                 "expected_events": " | ".join(events) if events else "",
                                 "events": observed, "error": error})
            code, out, _ = run_exe(artifact["executable"], ["--lifecycle"], phase / implementation, timeout)
            steps = parse_lines(out, "XPACT_LIFECYCLE")
            for step, accepted, events in LIFECYCLE:
                verdict, observed, error = steps.get(step, ("CRASH" if code not in (0, None) else "MISSING", "", ""))
                lifecycle_rows.append({"build": label, "step": step,
                                       "expected": "ACCEPT" if accepted else "REJECT", "verdict": verdict,
                                       "result": judge(accepted, events, verdict, observed),
                                       "expected_events": " | ".join(events) if events else "",
                                       "events": observed, "error": error})
            print("%-28s %d chunked runs" % (label, sum(1 for r in rows if r["build"] == label)), flush=True)
    if not rows:
        raise ValueError("no implementation could be built: " + json.dumps(build_errors))
    write_reports(run_root, rows, lifecycle_rows, executables, build_errors)
    xpact_failures = [r for r in rows + lifecycle_rows if r["build"].startswith("xpact/") and r["result"] != "PASS"]
    xpact_missing = [label for label in build_errors if label.startswith("xpact/")]
    if xpact_missing:
        status = "incomplete"
    else:
        status = "complete" if not xpact_failures else "complete_with_failures"
    state.update(status=status, build_errors=build_errors,
                 finished=datetime.now(timezone.utc).isoformat(),
                 builds={k: {"executable": v["executable"], "executable_sha256": v["executable_sha256"],
                             "revision": v["source"]["revision"], "configuration": v["build"]["configuration"]}
                         for k, v in executables.items()})
    builds.write_json_atomic(run_root / RUN_JSON, state)
    if xpact_missing:
        return 2
    return 0 if not xpact_failures else 1


def write_tsv(path, rows):
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=list(rows[0]), delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    path.write_text(buffer.getvalue(), encoding="utf-8")


def write_reports(run_root, rows, lifecycle_rows, executables, build_errors):
    from collections import Counter
    write_tsv(run_root / "cases.tsv", rows)
    write_tsv(run_root / "lifecycle.tsv", lifecycle_rows)
    builds_seen = list(dict.fromkeys(r["build"] for r in rows))
    lines = ["# Dual regression lane: functional cases, whole and chunked", "",
             "Expected results are written in `run_dual_regression.py`, independently of both parsers.", "",
             "## Builds", "", "| Build | Revision | Configuration | SHA-256 |", "|---|---|---|---|"]
    for label, a in executables.items():
        lines.append("| %s | `%s` | %s | `%s…` |" % (label, a["source"]["revision"][:12],
                                                   a["build"]["configuration"], a["executable_sha256"][:12]))
    for label, error in build_errors.items():
        lines.append("| %s | build failed | %s | |" % (label, error.replace("|", "/")))
    results = ["PASS", "WRONG-VERDICT", "WRONG-EVENTS", "CRASH", "TIMEOUT", "MISSING"]
    lines += ["", "## Results per build (every chunking)", "",
              "| Build | Runs | " + " | ".join(results) + " |", "|---" * (len(results) + 2) + "|"]
    for b in builds_seen:
        c = Counter(r["result"] for r in rows if r["build"] == b)
        lines.append("| %s | %d | %s |" % (b, sum(c.values()), " | ".join(str(c[x]) for x in results)))
    lines += ["", "## Per group", "", "| Build | Group | Runs | Not PASS |", "|---|---|---|---|"]
    for b in builds_seen:
        for g in dict.fromkeys(r["group"] for r in rows):
            sel = [r for r in rows if r["build"] == b and r["group"] == g]
            lines.append("| %s | %s | %d | %d |" % (b, g, len(sel), sum(r["result"] != "PASS" for r in sel)))
    lines += ["", "## Lifecycle (one reused parser)", "",
              "| Step | Expected | " + " | ".join(builds_seen) + " |", "|---|---|" + "---|" * len(builds_seen)]
    for step, accepted, _ in LIFECYCLE:
        cells = []
        for b in builds_seen:
            r = next(x for x in lifecycle_rows if x["build"] == b and x["step"] == step)
            cells.append(r["verdict"] + ("" if r["result"] == "PASS" else " ❌ " + r["result"]))
        lines.append("| %s | %s | %s |" % (step, "ACCEPT" if accepted else "REJECT", " | ".join(cells)))
    lines += ["", "## Cases that are not PASS (first 60 distinct case/build/result)", "",
              "| Build | Case | Runs | Result | Chunkings (first 4) | Observed events | Error |", "|---|---|---|---|---|---|---|"]
    seen = {}
    for r in rows:
        if r["result"] != "PASS":
            key = (r["build"], r["case"], r["result"])
            seen.setdefault(key, []).append(r)
    for (b, case, result), group in list(seen.items())[:60]:
        first = group[0]
        lines.append("| %s | %s | %d | %s | %s | `%s` | %s |" % (
            b, case, len(group), result, ", ".join(r["chunking"] for r in group[:4]),
            first["events"].replace("|", "·") or "-", first["error"].replace("|", "/") or "-"))
    (run_root / SUMMARY_MD).write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--offline", action="store_true", help="Require an already verified core checkout")
    parser.add_argument("--timeout", type=int, default=60, help="seconds per executable call")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    runs = root / "build/dual-regression"
    runs.mkdir(parents=True, exist_ok=True)
    run_root = runs / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:12])
    run_root.mkdir()
    print("Dual regression results: " + str(run_root), flush=True)
    try:
        code = run_lane(root, run_root, args.offline, args.timeout)
    except (builds.BuildError, DependencyError, OSError, ValueError, KeyError) as error:
        builds.write_json_atomic(run_root / RUN_JSON, {"schema_version": 1, "status": "failed", "error": str(error)})
        print("Dual regression could not complete: " + str(error), file=sys.stderr)
        return 2
    print("Complete: " + str(run_root / SUMMARY_MD))
    return code


if __name__ == "__main__":
    sys.exit(main())
