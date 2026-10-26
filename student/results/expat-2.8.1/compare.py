"""Compare the C# DLL test runs (#37) of xpact with the same runs on Expat 2.8.1.

`tests/dotnet/XpactDllTests` runs every input with six callback sets and three
chunkings through the Expat C API. Run once with `--dll` on Expat's own
`libexpat.dll` and once on `xpact.dll`, the two `results.tsv` files can be
compared case by case: verdict, error code, position, the call that failed and
the events. Expat 2.8.1 is the reference (`adapters/libexpat/README.md`).

Usage, from the repository root:
    python -I student/results/expat-2.8.1/compare.py \
        --expat build/w5-121/libexpat --xpact build/w5-121/xpact
Writes `cases.tsv` and `summary.md` next to this script, and the byte-exact
fixtures of every difference to `../C03-chunks/fixtures/` and
`../C10-utf8/fixtures/`.
"""

import argparse
import csv
import re
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESULTS = HERE.parent
TWO_COLUMNS = "|---|---|"

# Each difference that is a finding, with the rule that recognises it and its issue.
FINDINGS = {
    "utf8-position": ("#122", "malformed UTF-8: error reported at 1:0, not at the bad byte"),
    "utf8-no-events": ("#123", "malformed UTF-8: no events before the error"),
    "junk-code": ("#124", "`<root/>junk`: error 4 (invalid token), not 9 (junk after document element); position moves with callbacks and chunks"),
    "default-mismatch": ("#125", "default handler receives the mismatched end tag before the error"),
    "default-cr": ("#126", "default handler receives normalized line ends, not the raw CR"),
}


def read_tsv(path: Path) -> dict[str, dict]:
    with path.open(encoding="utf-8", newline="") as handle:
        return {row["id"]: row for row in csv.DictReader(handle, delimiter="\t")}


def unescape(text: str) -> bytes:
    """The input bytes from the `input_bytes` column (`\\xNN` for everything else)."""
    out = bytearray()
    for piece in re.split(r"(\\x[0-9a-f]{2})", text):
        if piece.startswith("\\x") and len(piece) == 4:
            out.append(int(piece[2:], 16))
        else:
            out += piece.encode("ascii")
    return bytes(out)


def joined_events(events: str) -> list[tuple[str, str]]:
    """Events with adjacent character-data or default pieces joined.

    Expat does not promise how text is divided between calls, so a different
    split is not a difference.
    """
    out: list[tuple[str, str]] = []
    for piece in events.split(" | ") if events else []:
        kind, _, value = piece.partition(":")
        if out and kind in ("text", "default") and out[-1][0] == kind and not value.startswith("<") and not out[-1][1].endswith(">"):
            out[-1] = (kind, out[-1][1] + value)
        else:
            out.append((kind, value))
    return out


def cell(events: str) -> str:
    """Events for a Markdown table cell: ` | ` would end the cell."""
    return events.replace(" | ", " · ") or "-"


def position(row: dict) -> str:
    return f"{row['line']}:{row['column']} (byte {row['byte_index']})"


def classify(e: dict, x: dict) -> list[str]:
    """Which properties differ; `split-only` is a different division of text, not a difference."""
    kinds = []
    if e["verdict"] != x["verdict"]:
        kinds.append("verdict")
    if e["error_code"] != x["error_code"]:
        kinds.append("error-code")
    if e["verdict"] == "REJECT" and position(e) != position(x):
        kinds.append("position")
    if e["events"] != x["events"]:
        kinds.append("events" if joined_events(e["events"]) != joined_events(x["events"]) else "split-only")
    if e["failed_call"] != x["failed_call"]:
        kinds.append("failed-call")
    return kinds


def finding(e: dict, kinds: list[str]) -> list[str]:
    found = []
    if e["group"] == "utf8" and "position" in kinds:
        found.append("utf8-position")
    if e["group"] == "utf8" and "events" in kinds:
        found.append("utf8-no-events")
    if e["input"] == "c02-trailing-junk" and {"error-code", "position"} & set(kinds):
        found.append("junk-code")
    if e["input"] == "c02-mismatched" and "events" in kinds:
        found.append("default-mismatch")
    if e["group"] == "cr" and "events" in kinds:
        found.append("default-cr")
    return found


def compare(expat: dict, xpact: dict) -> list[dict]:
    rows = []
    for case_id, e in expat.items():
        x = xpact[case_id]
        kinds = classify(e, x)
        rows.append({
            "id": case_id, "group": e["group"], "input": e["input"], "callbacks": e["callbacks"],
            "chunks": e["chunks"], "input_bytes": e["input_bytes"], "calls": e["calls"],
            "expat_verdict": e["verdict"], "xpact_verdict": x["verdict"],
            "expat_code": e["error_code"], "xpact_code": x["error_code"],
            "expat_position": position(e), "xpact_position": position(x),
            "expat_failed_call": e["failed_call"], "xpact_failed_call": x["failed_call"],
            "expat_events": e["events"], "xpact_events": x["events"],
            "differences": ",".join(kinds) or "none",
            "findings": ",".join(FINDINGS[f][0] for f in finding(e, kinds)) or "-",
        })
    return rows


def stable_under_chunking(results: dict) -> tuple[int, int, list[str]]:
    """Input/callback pairs whose verdict, code or position depends on the chunking."""
    seen = defaultdict(set)
    for r in results.values():
        seen[(r["input"], r["callbacks"])].add((r["verdict"], r["error_code"], position(r) if r["verdict"] == "REJECT" else ""))
    moving = sorted({f"{k[0]}/{k[1]}" for k, v in seen.items() if len(v) > 1})
    return len(seen), len(moving), moving


def write_fixtures(rows: list[dict]) -> dict[str, list[dict]]:
    """One byte-exact file per input with a finding, plus the C10 inputs."""
    written: dict[str, list[dict]] = {"C03-chunks": [], "C10-utf8": []}
    by_input: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by_input[r["input"]].append(r)
    for name, cases in by_input.items():
        hits = sorted({f for r in cases for f in r["findings"].split(",") if f != "-"})
        folder = "C10-utf8" if cases[0]["group"] == "utf8" else "C03-chunks"
        if not hits and folder != "C10-utf8":
            continue
        target = RESULTS / folder / "fixtures"
        target.mkdir(parents=True, exist_ok=True)
        data = unescape(cases[0]["input_bytes"])
        (target / f"{name}.xml").write_bytes(data)
        whole = {r["callbacks"]: r for r in cases if r["chunks"] == "whole"}
        sample = whole.get("default") if any(r["callbacks"] == "default" and r["findings"] != "-" for r in cases) else whole["none"]
        written[folder].append({
            "file": f"{name}.xml", "bytes": len(data), "input_bytes": cases[0]["input_bytes"],
            "callbacks": sample["callbacks"],
            "expat": f"{sample['expat_verdict']} {sample['expat_code']} at {sample['expat_position']}",
            "xpact": f"{sample['xpact_verdict']} {sample['xpact_code']} at {sample['xpact_position']}",
            "findings": ", ".join(hits) or "-",
        })
    for folder, items in written.items():
        with (RESULTS / folder / "fixtures" / "fixtures.tsv").open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(items[0]), delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows(sorted(items, key=lambda i: i["file"]))
    return written


def table(header: str, separator: str, items, fmt) -> list[str]:
    return [header, separator] + [fmt(k, v) for k, v in items]


def summary_lines(rows: list[dict], expat: dict, xpact: dict, labels: tuple[str, str]) -> list[str]:
    total = len(rows)
    kinds = Counter(k for r in rows for k in r["differences"].split(","))
    by_group = Counter((r["group"], k) for r in rows for k in r["differences"].split(","))
    e_pairs, e_moving, _ = stable_under_chunking(expat)
    x_pairs, x_moving, x_list = stable_under_chunking(xpact)
    lines = [
        "# xpact vs Expat 2.8.1 through the C API",
        "",
        "Generated by [`compare.py`](compare.py); per case: [`cases.tsv`](cases.tsv).",
        "",
        f"Expat: `{labels[0]}` · xpact: `{labels[1]}` · {total:,} cases each.",
        "",
        "## 1. What differs",
        "",
        "| Property | Cases that differ | Judged |",
        "|---|---|---|",
        f"| verdict (accept / reject) | {kinds['verdict']:,} | ✅ the same everywhere |" if not kinds["verdict"] else f"| verdict | {kinds['verdict']:,} | ❌ |",
        f"| error code | {kinds['error-code']:,} | ❌ finding {FINDINGS['junk-code'][0]} |",
        f"| error position (line, column, byte) | {kinds['position']:,} | ❌ findings {FINDINGS['utf8-position'][0]}, {FINDINGS['junk-code'][0]} |",
        f"| events, after joining text pieces | {kinds['events']:,} | ❌ findings {FINDINGS['utf8-no-events'][0]}, {FINDINGS['default-mismatch'][0]}, {FINDINGS['default-cr'][0]} |",
        f"| events, only text divided differently | {kinds['split-only']:,} | ✅ allowed: Expat does not promise how text is divided |",
        f"| the `XML_Parse` call that reports the error | {kinds['failed-call']:,} | ℹ️ information: Expat only promises an error by the final call |",
        f"| nothing | {kinds['none']:,} | ✅ |",
        "",
        "By group:",
        "",
    ]
    groups = sorted({r["group"] for r in rows})
    names = ["verdict", "error-code", "position", "events", "split-only", "failed-call", "none"]
    lines += ["| Group | " + " | ".join(names) + " |", "|---" * (len(names) + 1) + "|"]
    lines += [f"| {g} | " + " | ".join(f"{by_group[(g, n)]:,}" for n in names) + " |" for g in groups]
    lines += [
        "",
        "## 2. Does chunking change the answer? (C03)",
        "",
        "Same input and callback set; whole, split at every byte, byte by byte.",
        "",
        "| Parser | Input/callback pairs | Pairs whose verdict, code or position depends on the chunking |",
        "|---|---|---|",
        f"| Expat 2.8.1 | {e_pairs} | {e_moving} |",
        f"| xpact | {x_pairs} | {x_moving}{': ' + ', '.join(x_list) if x_list else ''} |",
        "",
        "## 3. Findings",
        "",
        "| Issue | What | Cases |",
        "|---|---|---|",
    ]
    hits = Counter(f for r in rows for f in r["findings"].split(",") if f != "-")
    lines += [f"| {issue} | {text} | {hits[issue]:,} |" for issue, text in FINDINGS.values()]
    lines += ["", "## 4. One example per input with a difference (whole document)", "",
              "| Input | Callbacks | Expat | xpact | Differs |", "|---|---|---|---|---|"]
    shown = set()
    for r in rows:
        if r["chunks"] == "whole" and r["differences"] not in ("none", "split-only") and (r["input"], r["differences"]) not in shown:
            shown.add((r["input"], r["differences"]))
            lines.append(
                f"| `{r['input_bytes']}` | {r['callbacks']} | {r['expat_verdict']} {r['expat_code']} at {r['expat_position']}; "
                f"events `{cell(r['expat_events'])}` | {r['xpact_verdict']} {r['xpact_code']} at {r['xpact_position']}; "
                f"events `{cell(r['xpact_events'])}` | {r['differences']} |")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expat", type=Path, required=True, help="output folder of the run on libexpat.dll")
    parser.add_argument("--xpact", type=Path, required=True, help="output folder of the run on xpact.dll")
    args = parser.parse_args()

    expat = read_tsv(args.expat / "results.tsv")
    xpact = read_tsv(args.xpact / "results.tsv")
    if set(expat) != set(xpact):
        raise SystemExit("the two runs do not have the same cases")
    rows = compare(expat, xpact)

    with (HERE / "cases.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    written = write_fixtures(rows)
    lines = summary_lines(rows, expat, xpact, (args.expat.name, args.xpact.name))
    (HERE / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(rows)} cases compared; fixtures: "
          + ", ".join(f"{k} {len(v)}" for k, v in written.items()) + "; see summary.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
