#!/usr/bin/env python3
"""Publish only our xpact tests to Jenkins; retain both engines' raw evidence."""

import argparse
import copy
import json
import math
from pathlib import Path
import re
import sys
import tempfile
import xml.etree.ElementTree as ET

import build_implementations as builds


JUNIT_FILE = "xpact-junit.xml"
SUMMARY_FILE = "xpact-summary.json"
CONTROLS = {
    "catalog": {"catalog_observed", "catalog_noop", "observed_reuse_recovery",
                "noop_reuse_recovery", "gc_restoration"},
    "w3c": {"raw_utf8", "raw_utf16", "namespace_switch", "reuse_recovery", "gc_restoration"},
}
CATALOG_CORE_GATE = "Catalog correctness/build gate failed; see per-build errors in run.json"


class SummaryError(ValueError):
    """Own test evidence is incomplete or cannot be authenticated."""


def clear_summary(output_dir):
    for name in (JUNIT_FILE, SUMMARY_FILE):
        (Path(output_dir) / name).unlink(missing_ok=True)


def _text(value):
    # XML 1.0 Char production; anything else becomes "?" (an explicit check, not a regex class).
    return "".join(ch if _is_xml_char(ch) else "?" for ch in str(value))


def _is_xml_char(ch):
    code = ord(ch)
    return (code in (0x9, 0xA, 0xD) or 0x20 <= code <= 0xD7FF or 0xE000 <= code <= 0xFFFD
            or 0x10000 <= code <= 0x10FFFF)


def _error_suite(lane, context, error):
    suite = ET.Element("testsuite", name="xpact.{}.infrastructure".format(lane))
    test = ET.SubElement(suite, "testcase", classname="xpact.{}.infrastructure".format(lane),
                         name=context, time="0")
    ET.SubElement(test, "error", message=_text(str(error).splitlines()[0])).text = _text(error)
    return suite


def _own_controls(rows):
    own = [row for row in rows if row.get("implementation") == "xpact"]
    keys = [row.get("assertions") for row in own]
    if (len(own) != 2 or any(type(value) is not bool for value in keys)
            or set(keys) != {True, False}):
        raise SummaryError("Own directed controls must cover assertions on and off exactly once")
    return own


def _verify_builds(rows, lane, repo_root):
    metadata = []
    for row in rows:
        artifact = json.loads(Path(row["manifest"]).read_text(encoding="utf-8"))
        assertions = row["assertions"]
        expected = "finalized/assertions-{}/msvc-x64".format("on" if assertions else "off")
        if (artifact.get("status") != "verified" or artifact.get("implementation") != "xpact"
                or artifact.get("profile") != lane
                or artifact.get("build", {}).get("configuration") != expected
                or artifact["build"].get("mode") != "finalized"
                or artifact["build"].get("assertions") is not assertions):
            raise SummaryError("Own directed-control build identity/configuration is not verified")
        if (builds.file_sha256(artifact["executable"]) != artifact["executable_sha256"]
                or not re.fullmatch(r"[0-9a-f]{64}", artifact["build_inputs_sha256"])
                or not re.fullmatch(r"[0-9a-f]{40}", artifact["source"]["revision"])):
            raise SummaryError("Own build bytes or identity changed after verification")
        metadata.append(artifact)
    if any(metadata[0][field] != metadata[1][field] for field in ("build_inputs_sha256",)):
        raise SummaryError("Own assertion configurations use different source snapshots")
    if any(metadata[0]["source"][field] != metadata[1]["source"][field]
           for field in ("revision", "source_sha256")):
        raise SummaryError("Own assertion configurations use different source identities")
    if repo_root is not None and builds.source_fingerprint(repo_root, "xpact", profile=lane) != metadata[0]["build_inputs_sha256"]:
        raise SummaryError("Own source inputs changed after directed-control execution")


def _control_suites(directory, lane, report, repo_root):
    expected_status = "qualified" if lane == "catalog" else "executed"
    rows = report["qualification"] if report is not None else _gated_catalog_rows(directory, lane)
    own = _own_controls(rows)
    if any(row.get("status") != expected_status for row in own):
        raise SummaryError("Own {} build or directed controls did not complete".format(lane))
    _verify_builds(own, lane, repo_root)
    return [_control_suite(row, lane) for row in own]


def _gated_catalog_rows(directory, lane):
    """Build rows of an incomplete lane, accepted only for the known core-only catalog gate."""
    state = json.loads((directory / "run.json").read_text(encoding="utf-8"))
    rows = state["builds"]
    # A known core-only build/qualification gate can leave our complete
    # controls intact. A later measurement/integrity/persistence failure
    # has ambiguous ownership and must never become a green subject run.
    if (lane != "catalog" or state.get("status") != "failed" or state.get("error") != CATALOG_CORE_GATE
            or state.get("comparison_arguments")
            or not any(row.get("implementation") == "xpact-core" and row.get("status") == "failed" for row in rows)):
        raise SummaryError("Own validation cannot be established from the incomplete {} lane".format(lane))
    return rows


def _control_suite(row, lane):
    """One JUnit suite for one own build's directed controls."""
    mode = "on" if row["assertions"] else "off"
    suite = ET.Element("testsuite", name="xpact.{}.controls.assertions-{}".format(lane, mode))
    if row.get("qualification_error"):
        test = ET.SubElement(suite, "testcase", classname="xpact.{}.controls".format(lane),
                             name="assertions-{}/control-process".format(mode), time="0")
        ET.SubElement(test, "error", message="Own directed control process failed").text = _text(row["qualification_error"])
        return suite
    cases = row["cases"]
    names = [case["case_id"] for case in cases]
    if len(names) != len(CONTROLS[lane]) or set(names) != CONTROLS[lane]:
        raise SummaryError("Own {} directed-control case matrix is incomplete or duplicated".format(lane))
    for case in cases:
        if case["status"] not in ("PASS", "FAIL"):
            raise SummaryError("Own directed control has an invalid outcome")
        test = ET.SubElement(suite, "testcase", classname="xpact.{}.controls".format(lane),
                             name="assertions-{}/{}".format(mode, case["case_id"]), time="0")
        if case["status"] == "FAIL":
            ET.SubElement(test, "failure", message="Own directed control failed").text = _text(case.get("detail", "FAIL"))
    return suite


def _number(value):
    if type(value) is not int or value < 0:
        raise SummaryError("Own W3C report contains an invalid case count")
    return value


def _case_counts(suite):
    tests = suite.findall("testcase")
    names = [test.get("name") for test in tests]
    if any(not name for name in names) or len(names) != len(set(names)):
        raise SummaryError("Own JUnit case matrix has missing or duplicate names")
    counts = {"tests": len(tests), "failures": 0, "errors": 0, "skipped": 0}
    elapsed = 0.0
    for test in tests:
        outcomes = [child.tag for child in test if child.tag in ("failure", "error", "skipped")]
        if len(outcomes) > 1:
            raise SummaryError("Own JUnit case has contradictory outcomes")
        if outcomes:
            counts[{"failure": "failures", "error": "errors", "skipped": "skipped"}[outcomes[0]]] += 1
        duration = float(test.get("time", "0"))
        if not math.isfinite(duration) or duration < 0:
            raise SummaryError("Own JUnit case duration is invalid")
        elapsed += duration
    counts["passed"] = counts["tests"] - counts["failures"] - counts["errors"] - counts["skipped"]
    return counts, elapsed


def _check_w3c_counts(own, report):
    for field in ("total", "passed", "failed", "errors", "skipped"):
        _number(own[field])
    if own["total"] <= 0 or own["total"] != sum(own[field] for field in ("passed", "failed", "errors", "skipped")):
        raise SummaryError("Own W3C summary counts do not reconcile")
    if own["total"] != _number(report["source"]["catalog_cases"]):
        raise SummaryError("Own W3C summary does not cover the selected catalog")


def _w3c_suite(directory, report):
    if report is None or report.get("status") not in ("complete", "complete_with_failures"):
        raise SummaryError("Own full W3C catalog results are unavailable")
    own = [row for row in report["engines"] if row.get("engine") == "xpact"]
    if len(own) != 1:
        raise SummaryError("Own full W3C engine summary is missing or duplicated")
    own = own[0]
    _check_w3c_counts(own, report)
    document = ET.parse(directory / "conformance/junit.xml").getroot()
    selected = [suite for suite in document.findall("testsuite") if suite.get("name") == "w3c-xml-xpact"]
    if len(selected) != 1:
        raise SummaryError("Own full W3C JUnit suite is missing or duplicated")
    suite = copy.deepcopy(selected[0])
    if suite.findall(".//testsuite") or suite.findall(".//testcase") != suite.findall("testcase"):
        raise SummaryError("Nested JUnit suites or testcases cannot enter own W3C results")
    # W3C profile lanes append a dot-separated category, including skipped
    # cases. Keep the implementation boundary explicit: xpact-core shares
    # the base text but is outside the w3c.xml.xpact. namespace.
    own_class = "w3c.xml.xpact"
    if any(test.get("classname", "") != own_class
           and not test.get("classname", "").startswith(own_class + ".")
           for test in suite.findall("testcase")):
        raise SummaryError("Foreign implementation testcase found inside own W3C suite")
    counts, elapsed = _case_counts(suite)
    expected = {"tests": own["total"], "passed": own["passed"], "failures": own["failed"],
                "errors": own["errors"], "skipped": own["skipped"]}
    if counts != expected:
        raise SummaryError("Own W3C JUnit results contradict the engine summary")
    for field in ("tests", "failures", "errors", "skipped"):
        if int(suite.get(field, "-1")) != counts[field]:
            raise SummaryError("Own W3C JUnit declared counts contradict its cases")
    suite.set("time", "{:.6f}".format(elapsed))
    return suite


def _replace_text(path, text):
    staged = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent,
                                         prefix=".xpact-summary-", suffix=".tmp", delete=False) as stream:
            staged = Path(stream.name)
            stream.write(text)
        staged.replace(path)
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)


def _add_lane_suites(suites, lane, directory, report, row, repo_root):
    """Append one lane's own suites (or error suites); True when the lane has an infrastructure error."""
    infrastructure = False
    if report is not None and (row.get("status") != report.get("status")
                               or report.get("status") not in ("complete", "complete_with_failures")):
        report = None
        infrastructure = True
        suites.append(_error_suite(lane, "campaign-evidence", "Own campaign state and completed report disagree"))
    try:
        suites.extend(_control_suites(directory, lane, report, repo_root))
    except (OSError, ValueError, KeyError, TypeError) as error:  # SummaryError is a ValueError
        infrastructure = True
        suites.append(_error_suite(lane, "directed-controls", error))
    if lane == "w3c":
        try:
            suites.append(_w3c_suite(directory, report))
        except (OSError, ValueError, KeyError, TypeError, ET.ParseError) as error:
            infrastructure = True
            suites.append(_error_suite(lane, "full-catalog", error))
    return infrastructure


def _set_counts(suites):
    """Write each suite's and the root's counts and time; return the totals."""
    totals = dict.fromkeys(("tests", "passed", "failures", "errors", "skipped"), 0)
    elapsed = 0.0
    for suite in suites:
        counts, duration = _case_counts(suite)
        for field in totals:
            totals[field] += counts[field]
        for field in ("tests", "failures", "errors", "skipped"):
            suite.set(field, str(counts[field]))
        suite.set("time", "{:.6f}".format(duration))
        elapsed += duration
    for field in ("tests", "failures", "errors", "skipped"):
        suites.set(field, str(totals[field]))
    suites.set("time", "{:.6f}".format(elapsed))
    return totals


def _publish_summary(output_dir, lane_reports, lane_states, *, selected_lanes=("catalog", "w3c"),
                     lane_directories=None, repo_root=None):
    """Publish our tests only; comparison reports and plots are never rewritten."""
    output_dir = Path(output_dir)
    if (not selected_lanes or len(set(selected_lanes)) != len(selected_lanes)
            or set(selected_lanes) - set(CONTROLS)):
        raise SummaryError("Select catalog and/or W3C exactly once")
    directories = {lane: output_dir / lane for lane in selected_lanes}
    directories.update({lane: Path(path) for lane, path in (lane_directories or {}).items()})
    suites = ET.Element("testsuites")
    infrastructure = False
    for lane in selected_lanes:
        infrastructure |= _add_lane_suites(suites, lane, directories[lane], lane_reports.get(lane),
                                           lane_states.get(lane, {}), repo_root)
    totals = _set_counts(suites)
    if infrastructure:
        status = "failed"
    elif totals["failures"] or totals["errors"]:
        status = "complete_with_failures"
    else:
        status = "complete"
    summary = {"schema_version": 1, "implementation": "xpact", "status": status,
               "junit": JUNIT_FILE, "summary": SUMMARY_FILE, **totals}
    ET.indent(suites)
    try:
        _replace_text(output_dir / JUNIT_FILE, ET.tostring(suites, encoding="unicode", xml_declaration=True) + "\n")
        _replace_text(output_dir / SUMMARY_FILE, json.dumps(summary, indent=2) + "\n")
    except BaseException:
        clear_summary(output_dir)
        raise
    return summary


def publish_summary(output_dir, lane_reports, lane_states, *, selected_lanes=("catalog", "w3c"),
                    lane_directories=None, repo_root=None):
    """A failed re-export cannot leave an older own summary publishable."""
    try:
        return _publish_summary(output_dir, lane_reports, lane_states, selected_lanes=selected_lanes,
                                lane_directories=lane_directories, repo_root=repo_root)
    except BaseException:
        clear_summary(output_dir)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--lane", choices=tuple(CONTROLS), required=True)
    parser.add_argument("--repo-root", type=Path)
    args = parser.parse_args(argv)
    try:
        report_path = args.output_dir / "report.json"
        report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.is_file() else None
        state_path = args.output_dir / "run.json"
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.is_file() else {"status": "failed"}
        summary = publish_summary(args.output_dir, {args.lane: report} if report else {},
                                  {args.lane: state}, selected_lanes=(args.lane,),
                                  lane_directories={args.lane: args.output_dir}, repo_root=args.repo_root)
    except Exception as error:
        try:
            clear_summary(args.output_dir)
        except Exception as cleanup_error:
            print("Cannot clear own xpact summary: " + str(cleanup_error), file=sys.stderr)
        print("Cannot publish own xpact summary: " + str(error), file=sys.stderr)
        return 2
    print("Own xpact tests: {} ({})".format(summary["status"], args.output_dir / JUNIT_FILE), flush=True)
    return {"complete": 0, "complete_with_failures": 1, "failed": 2}[summary["status"]]


if __name__ == "__main__":
    sys.exit(main())
