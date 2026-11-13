"""Capture build-owned plot inputs and render every Jenkins plot on one page."""

import argparse
import csv
import hashlib
import html
import json
import math
import os
from pathlib import Path
import sys
from urllib.parse import quote, urlsplit

import dual_jenkins_reports as dual

CHART_DIV = '<div class="chart">'


LANES = {"dual": "Dual implementation comparisons", "windows": "Windows same-machine benchmarks",
         "wsl": "WSL Eiffel and GCC benchmarks", "large": "Large XML benchmarks"}
RESULTS = {"windows": "benchmark-results.tsv", "wsl": "benchmark-results.tsv",
           "large": "large-xml-benchmark-results.tsv"}
COLORS = ("#086b70", "#b34b23", "#5844a3", "#276b35", "#946007", "#2264a3")


def number(value):
    result = float(str(value).replace(",", "."))
    if not math.isfinite(result) or result < 0:
        raise ValueError("Plot values must be finite and nonnegative")
    return result


def read_tsv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def relative_source(path):
    return path.resolve().relative_to(Path.cwd().resolve()).as_posix()


def _dual_lane_plots(lane, row, reports):
    if row["status"] in ("complete", "complete_with_failures"):
        report = reports[lane]
        if report["status"] != row["status"]:
            raise ValueError("Dual report status differs from run state")
        return dual.catalog_plots(report) if lane == "catalog" else dual.w3c_plots(report)
    if row["status"] != "failed" or lane in reports:
        raise ValueError("Incomplete dual lane supplied values")
    return []


def dual_plots(state, reports):
    if state["status"] not in ("complete", "complete_with_failures", "failed") or not state.get("publication"):
        raise ValueError("No terminal dual plot publication")
    if set(state["lanes"]) != {"catalog", "w3c"}:
        raise ValueError("Incomplete dual lane state")
    plots = []
    for lane, row in state["lanes"].items():
        plots.extend(_dual_lane_plots(lane, row, reports))
    statuses = [row["status"] for row in state["lanes"].values()]
    expected = dual.overall_status(statuses)
    if state["status"] != expected or state["publication"]["plots"] != len(plots):
        raise ValueError("Dual publication contradicts campaign state")
    return plots


def _capture_dual(source_dir, build_id):
    """The dual campaign state and the reports it vouches for (by SHA-256)."""
    state = json.loads((source_dir / "run.json").read_text(encoding="utf-8"))
    if state["build_id"] != build_id:
        raise ValueError("Dual results belong to a different build")
    reports = {}
    for name, row in state["lanes"].items():
        if name not in ("catalog", "w3c"):
            raise ValueError("Unknown dual lane")
        if row["status"] in ("complete", "complete_with_failures"):
            reports[name] = _vouched_report(source_dir, name, row)
    dual_plots(state, reports)
    if not (source_dir / dual.MANIFEST).is_file() or not (source_dir / dual.HTML_REPORT).is_file():
        raise ValueError("Dual publication files are missing")
    return {"state": state, "reports": reports}


def _vouched_report(source_dir, name, row):
    data = (source_dir / name / "report.json").read_bytes()
    if row["report"] != name + "/report.json" or hashlib.sha256(data).hexdigest() != row["report_sha256"]:
        raise ValueError("Dual report differs from persisted campaign evidence")
    return json.loads(data)


def _workload(row):
    return row.get("Benchmark") or row.get("CorpusId")


def _capture_benchmarks(lane, source_dir, manifest):
    """Charts checked against the raw measurements, plus the history, for one benchmark lane."""
    if manifest is None:
        raise ValueError("A current plot manifest is required")
    raw = read_tsv(source_dir / RESULTS[lane])
    measured = [row for row in raw if row.get("Engine") and row.get("ElapsedMs", "").strip().lower() not in ("", "not measured")]
    unmeasured = [row for row in raw if row.get("Engine") and row not in measured]
    charts = [_checked_chart(spec, source_dir, measured) for spec in read_tsv(Path(manifest))]
    if not charts or len({c["workload"] for c in charts}) != len(charts):
        raise ValueError("Missing or duplicate current workload plots")
    if {chart["workload"] for chart in charts} != {_workload(row) for row in measured}:
        raise ValueError("Manifest omits a measured workload")
    return {"charts": charts, "history": _read_history(source_dir), "unmeasured": unmeasured}


def _checked_chart(spec, source_dir, measured):
    """One plot CSV, checked: one value per measured engine, equal to the median of its raw samples."""
    path = Path(spec["sourceFile"])
    path.resolve().relative_to(source_dir.resolve())
    with path.open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.reader(stream))
    if len(rows) != 2 or not rows[0] or len(rows[0]) != len(rows[1]) or len(set(rows[0])) != len(rows[0]):
        raise ValueError("Expected one current value for each unique engine")
    workload = spec["title"].removesuffix(" median elapsed time")
    observations = [row for row in measured if _workload(row) == workload]
    values = [number(cell) for cell in rows[1]]
    if not observations or spec["yaxis"] != "Median elapsed ms":
        raise ValueError("Unrecognized elapsed-time plot or missing workload evidence")
    if set(rows[0]) != {row["Engine"] for row in observations}:
        raise ValueError("Plot omits a measured engine")
    for engine, value in zip(rows[0], values):
        samples = sorted(number(row["ElapsedMs"]) for row in observations if row["Engine"] == engine)
        if not samples or not math.isclose(value, samples[(len(samples) - 1) // 2], abs_tol=0.000501):
            raise ValueError("Plot value differs from current raw measurements")
    return {"title": spec["title"], "workload": workload, "labels": rows[0],
            "values": values, "source": relative_source(path), "observations": observations}


def _read_history(source_dir):
    history_path = source_dir / "benchmark-history.tsv"
    history = read_tsv(history_path) if history_path.is_file() else []
    seen = set()
    for row in history:
        key = (row["Build"], row["Benchmark"], row["Engine"])
        if not all(key) or key in seen:
            raise ValueError("Invalid or duplicate history observation")
        seen.add(key)
        row["MedianElapsedMs"] = number(row["MedianElapsedMs"])
    return history


def capture(lane, build_id, source_dir, output, manifest=None):
    """Invalidate the old snapshot first; publish a replacement only after validation."""
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    source_dir = Path(source_dir)
    packet = {"schema_version": 1, "lane": lane, "build_id": build_id,
              "source_dir": relative_source(source_dir)}
    if not build_id or lane not in LANES:
        raise ValueError("A known lane and current build identity are required")
    if lane == "dual":
        packet.update(_capture_dual(source_dir, build_id))
    else:
        packet.update(_capture_benchmarks(lane, source_dir, manifest))
    dual.replace_text(output, json.dumps(packet, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    return packet


def esc(value):
    return html.escape(str(value), quote=True)


def paragraphs(*texts):
    return "\n".join("<p>" + esc(text) + "</p>" for text in texts)


def artifact_url(path, build_url, local_prefix="../../"):
    # Snapshot paths are repository-relative, never arbitrary URLs or filesystem paths.
    parts = path.replace("\\", "/").split("/")
    if not path or any(part in ("", ".", "..") for part in parts) or ":" in path:
        raise ValueError("Invalid artifact path")
    prefix = build_url.rstrip("/") + "/artifact/" if build_url else local_prefix
    return prefix + quote(path, safe="/")


def bar_chart(chart):
    labels, values = chart["labels"], chart["values"]
    maximum = max(values) or 1
    height = 72 * len(labels) + 18
    parts = ['<svg class="bars" viewBox="0 0 1000 {}" role="img" aria-label="{}">'.format(height, esc(chart["title"]))]
    for index, (label, value) in enumerate(zip(labels, values)):
        y = 18 + index * 72
        width = value / maximum * 790
        parts += ['<text x="8" y="{}">{}</text>'.format(y, esc(label)),
                  '<rect x="8" y="{}" width="790" height="22" fill="#edf1f3"/>'.format(y + 10),
                  '<rect x="8" y="{}" width="{:.3f}" height="22" fill="{}"/>'.format(y + 10, width, COLORS[index % len(COLORS)]),
                  '<text x="812" y="{}">{} ms</text>'.format(y + 27, format(value, ".6g"))]
    return "\n".join(parts + ["</svg>"])


def observation_table(chart):
    parts = ['<details><summary>Engine settings and measured values</summary><div class="table-scroll"><table>',
             '<tr><th>Engine</th><th>Elapsed ms</th><th>Repetitions</th><th>Iterations per repetition</th><th>Bytes per document</th><th>Version and timing notes</th></tr>']
    for engine, value in zip(chart["labels"], chart["values"]):
        rows = [row for row in chart["observations"] if row["Engine"] == engine]
        def joined(field):
            return "; ".join(sorted({row.get(field, "") for row in rows if row.get(field, "")}))
        parts.append("<tr>" + "".join("<td>" + esc(v) + "</td>" for v in
                     (engine, format(value, ".6g"), len(rows), joined("Iterations"), joined("DocumentBytes") or joined("FileBytes"), joined("Version") + "; " + joined("Notes"))) + "</tr>")
    return "\n".join(parts + ["</table></div></details>"])


def current_explanation(lane, chart):
    observations = chart["observations"]
    iterations = sorted({row["Iterations"] for row in observations})
    sizes = sorted({row.get("DocumentBytes") or row.get("FileBytes", "unknown") for row in observations})
    texts = [
        'This plot compares engines on "{}". Each bar is the elapsed time for a complete repetition, in milliseconds; a shorter bar means less time for that workload. The current inputs record {} iterations per repetition and {} bytes per document. These elapsed values are not normalized to one document.'.format(chart["workload"], ", ".join(iterations), ", ".join(sizes)),
        "The publisher sorts each engine's measured repetitions and uses the middle observation, or the lower of the two middle observations when the count is even. This preserves the existing Jenkins CSV statistic. It reduces the influence of one slow repetition but shows no variability or confidence interval; small differences alone do not establish a performance change."]
    if lane == "windows":
        texts += ["Elapsed time is measured around the complete launched process on Windows. It includes startup, workload preparation and teardown as well as parsing. Any C/libexpat rows launched through WSL also include wsl.exe startup. Compilation is outside these measurements.",
                  "Engine labels describe different amounts of work. Direct Eiffel reuses a parser with a no-op handler; CPython pyexpat creates a parser per document, and its callback variant calls Python. Native DLL callback rows cross the C and Eiffel boundary; tokenizer rows omit callbacks. Explicit parser-reuse rows include XML_ParserReset. Compare like-for-like assertion, callback, reuse and garbage-collection settings before attributing a difference to the parser."]
    elif lane == "wsl":
        texts += ["The WSL runner performs an untimed full-workload warmup, then measures each complete Linux child process. Linux process startup is included; compilation and the outer Windows-to-WSL launch are excluded. These timing boundaries and iteration counts differ from the Windows lane, so raw bar heights across the two sections are not a compiler speed ratio.",
                  "EiffelStudio and Gobo use the same parser and harness sources but different runtimes. Gobo uses the Boehm collector and has no GC-suspended row. A Gobo label saying assertions requested is not equivalent to EiffelStudio's executed assertion coverage. Compare matching runtime options and inspect the version and notes for each engine."]
    else:
        texts += ["Each repetition launches a process that loads and parses the complete caller-supplied, already decompressed XML file. The elapsed time includes process startup and file loading. Download and decompression are excluded. This is a whole-file macro-benchmark, not a streaming-memory measurement.",
                  "The corpus identity, byte count and iteration count define the workload. A smaller file or changed corpus can lower elapsed time without a parser improvement. Callback, parser and garbage-collection settings still affect the work; compare the engine notes and raw observations before drawing conclusions."]
    texts.append("Every chart starts its bars at zero and scales to its own largest value. Use the printed numbers to compare different charts. A timing result is not evidence that every XML conformance case passed.")
    return paragraphs(*texts)


def _engine_history_svg(index, engine, rows, builds):
    """SVG parts for one engine's small chart: label, band, then points joined where builds are adjacent."""
    series = {row["Build"]: number(row["MedianElapsedMs"]) for row in rows if row["Engine"] == engine}
    ordered = [(build, series[build]) for build in builds if build in series]
    low, high = min(series.values()), max(series.values())
    y = index * 98 + 19
    first, last = ordered[0], ordered[-1]
    delta = "" if first[1] == 0 else " ({:+.1f}%)".format((last[1] / first[1] - 1) * 100)
    label = "#{} {:.6g} ms → #{} {:.6g} ms{}".format(*first, *last, delta)
    parts = ['<text x="8" y="{}">{}</text>'.format(y, esc(engine)),
             '<rect x="8" y="{}" width="460" height="38" fill="#edf1f3"/>'.format(y + 12),
             '<text x="490" y="{}">{}</text>'.format(y + 38, esc(label))]
    color = COLORS[index % len(COLORS)]
    previous = None
    for build_index, build in enumerate(builds):
        if build not in series:
            previous = None  # a gap, never a zero
            continue
        x = 8 + build_index / (len(builds) - 1) * 460
        py = y + 50 - ((series[build] - low) / (high - low) * 38 if high > low else 19)
        if previous:
            parts.append('<line x1="{:.2f}" y1="{:.2f}" x2="{:.2f}" y2="{:.2f}" stroke="{}" stroke-width="2"/>'.format(*previous, x, py, color))
        parts.append('<circle cx="{:.2f}" cy="{:.2f}" r="3" fill="{}"><title>Build {}: {:.6g} ms</title></circle>'.format(x, py, color, esc(build), series[build]))
        previous = (x, py)
    return parts


def history_chart(chart, history):
    rows = [row for row in history if row["Benchmark"] == chart["workload"]]
    builds = sorted({row["Build"] for row in rows}, key=lambda b: (0, int(b)) if b.isdigit() else (1, b))
    if len(builds) < 2:
        return paragraphs("History trend: fewer than two build observations are available for this workload. No trend is inferred from a single build.")
    parts = ['<h4>Elapsed time across builds</h4>', paragraphs(
        "Each line shows one engine's stored elapsed-time statistic across available builds. Left to right follows build order with equal spacing per recorded build; it is not a calendar-time axis. Missing engine observations are gaps, never zero measurements.",
        "Each engine's small chart has its own vertical range, from its minimum to maximum recorded time. A downward movement means less elapsed time, but equal slopes across engines do not mean equal millisecond changes. The endpoint label reports the first and last measurements and their percentage change; a negative percentage means less time.",
        "The history publisher retains up to 30 build identifiers and imports available history from earlier successful builds. It may omit failed builds. Compare trends only when the machine, input bytes, iteration count and runtime settings stayed comparable; the historical four-column file does not establish that they did. A toolchain or workload change can create a jump unrelated to parser code.")]
    engines = sorted({row["Engine"] for row in rows})
    parts.append('<svg viewBox="0 0 1000 {}" role="img" aria-label="{} elapsed time across builds">'.format(98 * len(engines), esc(chart["workload"])))
    for index, engine in enumerate(engines):
        parts += _engine_history_svg(index, engine, rows, builds)
    parts += ['</svg>', '<details><summary>History values</summary><div class="table-scroll"><table><tr><th>Build</th><th>Engine</th><th>Elapsed ms</th></tr>']
    parts += ["<tr><td>{}</td><td>{}</td><td>{}</td></tr>".format(esc(build), esc(row["Engine"]), esc(row["MedianElapsedMs"]))
              for build in builds for row in rows if row["Build"] == build]
    return "\n".join(parts + ["</table></div></details>"])


STYLE = """
body{margin:0;background:#f5f7fa;color:#172b3a;font:16px/1.6 system-ui,sans-serif}
main{max-width:1120px;margin:auto;padding:36px 24px}h1{font-size:2.3rem;line-height:1.2}
h2{font-size:1.7rem;margin-top:0}h3{font-size:1.3rem}h4{font-size:1.1rem}a{color:#075c9e}
nav{display:flex;flex-wrap:wrap;gap:12px 24px;margin:24px 0}section.lane{background:white;padding:28px;margin:28px 0;border:1px solid #dbe3e9;border-radius:12px}
article,section.lane section{border-top:1px solid #dbe3e9;margin-top:28px;padding-top:20px}
svg{display:block;width:100%;height:auto;margin:20px 0}svg text{font:14px system-ui,sans-serif;fill:#172b3a}
table{border-collapse:collapse;width:100%;font-size:.9rem;margin:16px 0}td,th{border:1px solid #dbe3e9;padding:9px;text-align:left;vertical-align:top;overflow-wrap:anywhere}
th{background:#eff4f7}code{overflow-wrap:anywhere}details{margin:18px 0}summary{cursor:pointer;font-weight:600}.table-scroll{overflow-x:auto}
.notice{padding:16px;background:#fff4d9;border-left:4px solid #b87900}.eyebrow{font-size:.85rem;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#4e6577}
@media(max-width:650px){main{padding:20px 12px}section.lane{padding:16px}svg{min-width:720px}.chart{overflow-x:auto}}
@media print{body{background:white}section.lane{break-inside:auto;border:0}details{display:block}nav{display:none}}
"""


def _load_packets(input_dir, build_id, disabled, url_for):
    """Snapshots of this build, one per enabled lane."""
    packets = {}
    for path in sorted(Path(input_dir).glob("*.json")):
        packet = json.loads(path.read_text(encoding="utf-8"))
        lane = packet["lane"]
        if packet.get("schema_version") != 1 or packet["build_id"] != build_id or lane not in LANES or lane in packets:
            raise ValueError("Snapshot has a different build identity, duplicate lane or unsupported schema")
        if lane in disabled:
            raise ValueError("A disabled lane supplied a snapshot")
        url_for(packet["source_dir"])
        if lane == "dual" and packet["state"]["build_id"] != build_id:
            raise ValueError("Dual campaign and snapshot have different build identities")
        packets[lane] = packet
    return packets


def _benchmark_section(lane, packet, url_for):
    """HTML parts for one benchmark lane: links, unmeasured engines, then each chart."""
    source = packet["source_dir"]
    raw_url = url_for(source + "/" + RESULTS[lane])
    history_link = (' · <a href="{}">Stored build history</a>'.format(esc(url_for(source + "/benchmark-history.tsv")))
                    if packet["history"] else "")
    parts = ['<p><a href="{}">Raw measurements</a>{}</p>'.format(esc(raw_url), history_link)]
    parts += ['<p class="notice">Not measured: {}. {} No numeric value is plotted.</p>'.format(esc(row["Engine"]), esc(row.get("Notes", "")))
              for row in packet.get("unmeasured", [])]
    if not packet["charts"] or len({chart["workload"] for chart in packet["charts"]}) != len(packet["charts"]):
        raise ValueError("Snapshot has missing or duplicate charts")
    for chart in packet["charts"]:
        # Validate the snapshot at consumption too, before making SVG geometry.
        chart["values"] = [number(value) for value in chart["values"]]
        if not chart["labels"] or len(set(chart["labels"])) != len(chart["labels"]) or len(chart["labels"]) != len(chart["values"]):
            raise ValueError("Snapshot has mismatched or duplicate engine values")
        parts += ['<article><h3>{}</h3>'.format(esc(chart["title"])), CHART_DIV + bar_chart(chart) + '</div>',
                  current_explanation(lane, chart), observation_table(chart),
                  '<p><a href="{}">Exact Jenkins plot CSV</a></p>'.format(esc(url_for(chart["source"]))),
                  CHART_DIV + history_chart(chart, packet["history"]) + '</div></article>']
    return parts


def render(build_id, input_dir, output, build_url="", disabled=()):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    if not build_id:
        raise ValueError("A current build identity is required")
    if build_url and (urlsplit(build_url).scheme not in ("http", "https") or not urlsplit(build_url).netloc):
        raise ValueError("Build URL must be HTTP or HTTPS")
    local_prefix = Path(os.path.relpath(Path.cwd(), output.resolve().parent)).as_posix() + "/"
    def url_for(path):
        return artifact_url(path, build_url, local_prefix)
    packets = _load_packets(input_dir, build_id, disabled, url_for)
    parts = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
             '<title>All Benchmark Plots</title><style>' + STYLE + '</style></head><body><main>',
             '<div class="eyebrow">xpact measurement report</div><h1>All Benchmark Plots</h1>',
             '<p>Build <strong>{}</strong>. Current comparisons and available elapsed-time history, with an explanation beside every plot.</p>'.format(esc(build_id)),
             paragraphs("Start with correctness in the dual implementation section, then compare timing within a matching workload and runtime configuration. Each section states its units and measurement boundaries. Missing measurements are shown explicitly and are never plotted as zero."),
             '<nav aria-label="Plot families">' + "".join('<a href="#{}">{}</a>'.format(lane, title) for lane, title in LANES.items()) + '</nav>']
    for lane, title in LANES.items():
        parts.append('<section class="lane" id="{}"><h2>{}</h2>'.format(lane, title))
        if lane not in packets:
            message = "Disabled or not configured for this build." if lane in disabled else "No captured results for this build. This stage may have failed, been skipped, or failed to publish. Consult the build log; no earlier build's values are substituted."
            parts.append('<p class="notice">' + esc(message) + '</p></section>')
            continue
        packet = packets[lane]
        if lane == "dual":
            plots = dual_plots(packet["state"], packet["reports"])
            parts.append(CHART_DIV + dual.report_body(packet["state"], packet["reports"], plots,
                         link_prefix=url_for(packet["source_dir"]) + "/") + '</div>')
        else:
            parts += _benchmark_section(lane, packet, url_for)
        parts.append('</section>')
    parts += [paragraphs("The Jenkins Plot plugin retains its existing trend series. This page consolidates their current values and the available benchmark history without changing the build's test verdicts. The recorded source reports remain the evidence for each measurement."), '</main></body></html>']
    dual.replace_text(output, "\n".join(parts) + "\n")
    return output


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    collect = commands.add_parser("capture")
    collect.add_argument("--lane", choices=LANES, required=True)
    collect.add_argument("--source-dir", type=Path, required=True)
    collect.add_argument("--manifest", type=Path)
    write = commands.add_parser("render")
    write.add_argument("--input-dir", type=Path, required=True)
    write.add_argument("--build-url", default="")
    write.add_argument("--disabled", choices=LANES, action="append", default=[])
    for command in (collect, write):
        command.add_argument("--build-id", required=True)
        command.add_argument("--output", type=Path, required=True)
    args = vars(parser.parse_args(argv))
    command = args.pop("command")
    try:
        (capture if command == "capture" else render)(**args)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Plot report could not be published: " + str(error), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
