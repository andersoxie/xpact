"""Publish scoped dual-implementation results as Jenkins plot data and HTML."""

import csv
import html
import io
import math
from pathlib import Path
import re
import statistics
import tempfile


ENGINES = ("xpact", "xpact-core")
LABELS = ("xpact", "pinned Xpact-core")
MANIFEST = "plots.tsv"
HTML_REPORT = "dual-implementation-plots.html"
PLOT_IDS = ("dual-catalog-ms-per-1000-documents", "dual-catalog-mib-per-second",
            "dual-w3c-passed", "dual-w3c-wrong-verdicts", "dual-w3c-errors", "dual-w3c-excluded")
REPORT_FILES = (MANIFEST, HTML_REPORT) + tuple(name + ".csv" for name in PLOT_IDS)
CATALOG_CONTROLS = {"catalog_observed", "catalog_noop", "observed_reuse_recovery",
                    "noop_reuse_recovery", "gc_restoration"}
W3C_CONTROLS = {"raw_utf8", "raw_utf16", "namespace_switch", "reuse_recovery", "gc_restoration"}
GC_POLICIES = {"xpact": "normal", "xpact-core": "core-managed-off-full-collect"}


class ReportsError(ValueError):
    """A report cannot supply authenticated, complete plot values."""


def clear_reports(output_dir):
    """Remove only this publisher's named files, preserving child lane evidence."""
    for name in REPORT_FILES:
        (Path(output_dir) / name).unlink(missing_ok=True)


def positive_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
        raise ReportsError("Catalog measurements must be finite positive numbers")
    return value


def count(value, *, positive=False):
    if type(value) is not int or value < (1 if positive else 0):
        raise ReportsError("Case counts must be nonnegative integers")
    return value


def validate_artifacts(report, profile):
    if set(report["artifacts"]) != set(ENGINES):
        raise ReportsError("Both implementation artifacts are required")
    for engine, artifact in report["artifacts"].items():
        if (artifact["status"] != "verified" or artifact["profile"] != profile
                or artifact["implementation"] != engine
                or artifact["gc_policy"] != GC_POLICIES[engine]
                or artifact["build"]["configuration"] != "finalized/assertions-off/msvc-x64"
                or artifact["build"]["mode"] != "finalized"
                or artifact["build"]["assertions"] is not False):
            raise ReportsError("Plot artifact differs from the selected finalized configuration")
        if (not re.fullmatch(r"[0-9a-f]{40}", artifact["source"]["revision"])
                or not re.fullmatch(r"[0-9a-f]{64}", artifact["executable_sha256"])
                or not re.fullmatch(r"[0-9a-f]{64}", artifact["build_inputs_sha256"])):
            raise ReportsError("Plot provenance lacks source or executable identity")


def validate_controls(report, profile):
    expected = CATALOG_CONTROLS if profile == "catalog" else W3C_CONTROLS
    rows = report["qualification"]
    keys = [(row["implementation"], row["assertions"]) for row in rows]
    if (len(keys) != 4 or set(keys) != {(engine, assertions) for engine in ENGINES for assertions in (True, False)}
            or any(type(row["assertions"]) is not bool for row in rows)):
        raise ReportsError("Directed controls must cover both assertion modes for both implementations")
    has_failures = False
    for row in rows:
        if row["status"] != ("qualified" if profile == "catalog" else "executed"):
            raise ReportsError("Directed controls were not executed")
        if row.get("qualification_error"):
            if profile == "catalog" or row["cases"]:
                raise ReportsError("Control process errors cannot supply passing qualification")
            has_failures = True
            continue
        cases = row["cases"]
        names = [case["case_id"] for case in cases]
        if len(names) != len(expected) or set(names) != expected:
            raise ReportsError("Directed control matrix is incomplete or duplicated")
        if any(case["status"] not in ("PASS", "FAIL") for case in cases):
            raise ReportsError("Invalid directed control outcome")
        has_failures |= any(case["status"] == "FAIL" for case in cases)
    if profile == "catalog" and has_failures:
        raise ReportsError("A failed catalog correctness gate cannot supply benchmark values")
    return has_failures


def catalog_plots(report):
    if report["status"] != "complete" or report["lane"] != "catalog-finalized-assertions-off":
        raise ReportsError("An incomplete catalog campaign cannot supply plot values")
    validate_artifacts(report, "catalog")
    validate_controls(report, "catalog")
    comparison = report["comparison"]
    rows = comparison["results"]
    pairs = count(comparison["metadata"]["pairs"], positive=True)
    if len(rows) != pairs:
        raise ReportsError("Catalog measurement pairs are incomplete")
    document_bytes = count(report["input"]["bytes"], positive=True)
    iteration_counts = set()
    for index, row in enumerate(rows, 1):
        iterations = count(row["Iterations"], positive=True)
        iteration_counts.add(iterations)
        if (row["Workload"] != "catalog" or row["Pair"] != index
                or row["Order"] != ("AB" if index % 2 else "BA")
                or row["DocumentBytes"] != document_bytes):
            raise ReportsError("Catalog plot data changed workload, input or pair sequence")
        for prefix in ("Baseline", "Candidate"):
            elapsed = positive_number(row[prefix + "ElapsedMs"])
            rate = positive_number(row[prefix + "MiBPerSecond"])
            computed_rate = document_bytes * iterations / (1024 * 1024) / (elapsed / 1000)
            if not math.isclose(rate, computed_rate, rel_tol=1e-9):
                raise ReportsError("Catalog throughput contradicts elapsed time and document count")
    if len(iteration_counts) != 1:
        raise ReportsError("Catalog pairs use different iteration counts")
    normalized, rates = [], []
    for prefix in ("Baseline", "Candidate"):
        normalized.append(positive_number(statistics.median(
            row[prefix + "ElapsedMs"] / row["Iterations"] * 1000 for row in rows)))
        rates.append(positive_number(statistics.median(row[prefix + "MiBPerSecond"] for row in rows)))
    return [plot_spec("dual-catalog-ms-per-1000-documents", "Dual catalog",
                      "Catalog finalized, assertions discarded: time per 1,000 documents",
                      "Median ms per 1,000 documents", normalized),
            plot_spec("dual-catalog-mib-per-second", "Dual catalog",
                      "Catalog finalized, assertions discarded: throughput", "Median MiB/s", rates)]


def w3c_plots(report):
    if report["status"] not in ("complete", "complete_with_failures") or report["lane"] != "w3c-finalized-assertions-off":
        raise ReportsError("An incomplete W3C campaign cannot supply plot values")
    validate_artifacts(report, "w3c")
    has_failures = validate_controls(report, "w3c")
    rows = report["engines"]
    if len(rows) != 2 or {row["engine"] for row in rows} != set(ENGINES):
        raise ReportsError("W3C counts must cover each implementation exactly once")
    indexed = {row["engine"]: row for row in rows}
    total = count(report["source"]["catalog_cases"], positive=True)
    for row in rows:
        for field in ("total", "passed", "failed", "errors", "skipped"):
            count(row[field])
        if row["total"] != total or sum(row[field] for field in ("passed", "failed", "errors", "skipped")) != total:
            raise ReportsError("W3C case totals do not reconcile")
        has_failures |= row["failed"] > 0 or row["errors"] > 0
    if indexed[ENGINES[0]]["skipped"] != indexed[ENGINES[1]]["skipped"]:
        raise ReportsError("W3C profile exclusions differ between implementations")
    if (report["status"] == "complete_with_failures") != has_failures:
        raise ReportsError("W3C campaign status contradicts its outcomes")
    return [plot_spec("dual-w3c-" + token, "Dual W3C conformance", "W3C finalized, assertions discarded: " + title,
                      "Cases", [indexed[engine][field] for engine in ENGINES])
            for token, title, field in (("passed", "passed", "passed"),
                                        ("wrong-verdicts", "wrong verdicts", "failed"),
                                        ("errors", "process errors and timeouts", "errors"),
                                        ("excluded", "profile exclusions", "skipped"))]


def plot_spec(token, group, title, yaxis, values):
    return {"token": token, "group": group, "title": title, "yaxis": yaxis, "values": values}


def svg(spec):
    values = spec["values"]
    maximum = max(values) or 1
    parts = ['<section><h2>{}</h2>'.format(html.escape(spec["title"])),
             '<p>{}</p>'.format(html.escape(spec["yaxis"])),
             '<svg viewBox="0 0 820 130" role="img" aria-label="{}">'.format(html.escape(spec["title"], quote=True))]
    for index, (label, value, color) in enumerate(zip(LABELS, values, ("#0f766e", "#b45309"))):
        y = 12 + index * 55
        width = value / maximum * 430
        parts += ['<text x="0" y="{}">{}</text>'.format(y + 22, html.escape(label)),
                  '<rect x="175" y="{}" width="{:.3f}" height="32" fill="{}"/>'.format(y, width, color),
                  '<text x="{}" y="{}">{}</text>'.format(185 + width, y + 22, format(value, ".6g"))]
    return "\n".join(parts + ["</svg></section>"])


def html_report(state, lane_reports, plots):
    parts = ['<!doctype html><html lang="en"><head><meta charset="utf-8">',
             '<meta name="viewport" content="width=device-width, initial-scale=1">',
             '<title>Dual implementation plots</title>',
             '<style>body{font:16px system-ui,sans-serif;max-width:1050px;margin:2rem auto;padding:0 1rem;color:#17252a}table{border-collapse:collapse;width:100%;margin:1rem 0}th,td{border:1px solid #ccd4d7;padding:.5rem;text-align:left}svg{width:100%;height:auto}code{overflow-wrap:anywhere}section{margin:2rem 0}p{line-height:1.5}</style>',
             '</head><body><h1>Dual implementation plots</h1>',
             '<p>Jenkins build: <code>{}</code>. Comparison campaign status: <strong>{}</strong>.</p>'.format(
                 html.escape(state["build_id"]), html.escape(state["status"])),
             '<p>Windows x64; Eiffel finalized with assertions discarded. Assertion-enabled builds run directed controls only.</p>',
             '<table><tr><th>Lane</th><th>Status</th><th>Evidence or infrastructure error</th></tr>']
    for lane in ("catalog", "w3c"):
        row = state["lanes"][lane]
        evidence = '<a href="{0}/report.json">Report</a> · <a href="{0}/summary.md">Summary</a>'.format(lane) if lane in lane_reports else html.escape(row.get("error", "No completed campaign; no numeric values published."))
        parts.append('<tr><td>{}</td><td>{}</td><td>{}</td></tr>'.format(lane, html.escape(row["status"]), evidence))
    parts += ['</table>',
              '<p>Only xpact contributes to the Jenkins Test Result summary and its test pass/fail decision. Xpact-core remains comparison data in these plots and detailed artifacts.</p>',
              '<p>Catalog timing is normalized per 1,000 documents because calibration can change the iteration count. Throughput is the median of measured pairs. Both engines use no-op handlers; parser reset/reuse and process startup are timed. Core retains internal GC suspension/full collection; the caller requests no additional suspension.</p>',
              '<p>W3C plots show functional outcomes, including red completed campaigns. Wrong verdicts and process errors remain failures; exclusions are never passed. W3C elapsed times include fresh process startup and file I/O and are not compared here as parser throughput. No known-failure allowlist is applied.</p>']
    if state.get("subject_summary"):
        parts.append('<p>Jenkins xpact test status: <strong>{}</strong>. <a href="xpact-summary.json">Test summary</a>.</p>'.format(
            html.escape(state["subject_summary"]["status"])))
    parts.extend(svg(spec) for spec in plots)
    for lane, report in lane_reports.items():
        parts += ['<h2>{} directed controls</h2>'.format(html.escape(lane)),
                  '<table><tr><th>Implementation</th><th>Assertions</th><th>Passed</th><th>Failed</th><th>Control process/protocol error</th></tr>']
        for row in report["qualification"]:
            parts.append('<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>'.format(
                html.escape(row["implementation"]), "on" if row["assertions"] else "off",
                sum(case["status"] == "PASS" for case in row["cases"]),
                sum(case["status"] == "FAIL" for case in row["cases"]),
                html.escape(row.get("qualification_error", ""))))
        parts += ['</table>', '<table><tr><th>Implementation</th><th>Source revision</th><th>Executable SHA-256</th><th>GC policy</th></tr>']
        for engine in ENGINES:
            artifact = report["artifacts"][engine]
            parts.append('<tr><td>{}</td><td><code>{}</code></td><td><code>{}</code></td><td>{}</td></tr>'.format(
                html.escape(engine), html.escape(artifact["source"]["revision"]), html.escape(artifact["executable_sha256"]), html.escape(artifact["gc_policy"])))
        parts.append('</table>')
    return "\n".join(parts + ['<p>Native DLLs, .NET, external entity processing and general event/canonical-output parity are outside these lanes.</p>', '</body></html>']) + "\n"


def csv_text(rows, delimiter=","):
    output = io.StringIO(newline="")
    writer = csv.writer(output, delimiter=delimiter, lineterminator="\n")
    writer.writerows(rows)
    return output.getvalue()


def replace_text(path, content):
    staged = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent,
                                         prefix=".dual-plot-", suffix=".tmp", delete=False) as stream:
            staged = Path(stream.name)
            stream.write(content)
        staged.replace(path)
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)


def publish_reports(output_dir, state, lane_reports):
    """Publish only completed lane data; the orchestrator owns the fresh directory."""
    output_dir = Path(output_dir)
    clear_reports(output_dir)
    try:
        if not state["build_id"] or not isinstance(state["build_id"], str):
            raise ReportsError("A Jenkins build owner is required")
        if state["status"] not in ("complete", "complete_with_failures", "failed"):
            raise ReportsError("Only terminal campaign states can publish plot values")
        if set(state["lanes"]) != {"catalog", "w3c"} or set(lane_reports) - {"catalog", "w3c"}:
            raise ReportsError("Unknown or missing dual campaign lane")
        plots = []
        for lane, row in state["lanes"].items():
            if row["status"] in ("complete", "complete_with_failures"):
                if lane not in lane_reports or lane_reports[lane]["status"] != row["status"]:
                    raise ReportsError("Completed lane evidence is missing or has a different status")
                plots.extend(catalog_plots(lane_reports[lane]) if lane == "catalog" else w3c_plots(lane_reports[lane]))
            elif lane in lane_reports or row["status"] != "failed":
                raise ReportsError("An incomplete lane cannot supply numeric plot values")
        expected_status = ("failed" if any(row["status"] == "failed" for row in state["lanes"].values())
                           else "complete_with_failures" if any(row["status"] == "complete_with_failures" for row in state["lanes"].values())
                           else "complete")
        if state["status"] != expected_status:
            raise ReportsError("Overall campaign status contradicts lane states")
        manifest = [["sourceFile", "csvFileName", "group", "title", "yaxis"]]
        for spec in plots:
            path = output_dir / (spec["token"] + ".csv")
            replace_text(path, csv_text([LABELS, [format(value, ".17g") for value in spec["values"]]]))
            try:
                source = path.resolve().relative_to(Path.cwd().resolve()).as_posix()
            except ValueError:
                source = path.resolve().as_posix()
            manifest.append([source, "plot-" + spec["token"] + ".csv", spec["group"], spec["title"], spec["yaxis"]])
        replace_text(output_dir / HTML_REPORT, html_report(state, lane_reports, plots))
        # The manifest is the last published file, so a partial export is not consumable.
        replace_text(output_dir / MANIFEST, csv_text(manifest, delimiter="\t"))
        return {"manifest": MANIFEST, "html": HTML_REPORT, "plots": len(plots)}
    except (KeyError, TypeError, IndexError) as error:
        clear_reports(output_dir)
        raise ReportsError("Invalid completed lane report: " + str(error)) from error
    except BaseException:
        clear_reports(output_dir)
        raise
