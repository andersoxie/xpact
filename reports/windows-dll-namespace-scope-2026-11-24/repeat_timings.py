"""Repeat the recorded Windows fair_speed runs, including engine order and iterations."""

import argparse
import csv
import ctypes
import hashlib
import json
import runpy
import subprocess
from pathlib import Path


REPORT = Path(__file__).resolve().parent
REPO = REPORT.parents[1]


def wide_document(rebind):
    declarations = "".join(f' xmlns:p{i}="urn:p{i}"' for i in range(32))
    pieces = [f'<?xml version="1.0" encoding="UTF-8"?><root{declarations}>']
    for branch in range(600):
        for depth in range(8):
            change = f' xmlns:p{depth}="urn:shadow{depth}"' if rebind else ""
            pieces.append(f"<p{depth}:branch{change}>")
        for child in range(4):
            pieces.append(f'<p31:item p0:id="{branch}.{child}">caf\u00e9</p31:item>')
        for depth in reversed(range(8)):
            pieces.append(f"</p{depth}:branch>")
    pieces.append("</root>")
    return "".join(pieces).encode("utf-8")


def write_fixtures(folder, expected):
    document = runpy.run_path(str(REPO / "benchmarks/fair_speed/gen_inputs.py"))["document"]
    latin1 = document("elements", 65536).replace("<value>", "<value>\u00e9")
    fixtures = {
        "elements-1MB-utf8": document("elements", 1_000_000).encode("utf-8"),
        "namespaces-1MB-utf8": document("namespaces", 1_000_000).encode("utf-8"),
        "elements-64k-latin1": latin1.replace('encoding="UTF-8"', 'encoding="ISO-8859-1"').encode("latin-1"),
        "inherit-32": wide_document(False),
        "rebind-32": wide_document(True),
    }
    for name, data in fixtures.items():
        if hashlib.sha256(data).hexdigest() != expected[name]["sha256"]:
            raise ValueError(f"Fixture hash differs for {name}")
        (folder / (name + ".xml")).write_bytes(data)


def pin_cpu(index):
    """Propagate the same logical processor to all children."""
    if not 0 <= index < ctypes.sizeof(ctypes.c_size_t) * 8:
        raise ValueError(f"CPU {index} cannot be selected by the process affinity mask")
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = ctypes.c_void_p
    kernel.SetProcessAffinityMask.argtypes = (ctypes.c_void_p, ctypes.c_size_t)
    if not kernel.SetProcessAffinityMask(kernel.GetCurrentProcess(), 1 << index):
        raise ctypes.WinError(ctypes.get_last_error())


def measure(harness, dll, folder, row, iterations):
    fixture = folder / (row["fixture"] + ".xml")
    command = [harness, dll, fixture, row["chunk_bytes"], row["callbacks"], row["namespaces"], str(iterations)]
    run = subprocess.run(command, capture_output=True, text=True, check=True, timeout=120)
    status, error, milliseconds, checksum = run.stdout.split()
    if (status, error, checksum) != ("1", "0", row["checksum"]):
        raise RuntimeError(f"Unexpected parse result for {command}: {run.stdout}")
    return milliseconds


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("harness", "before", "after", "expat", "out"):
        parser.add_argument("--" + key, required=True, type=Path)
    parser.add_argument("--cpu", type=int, help="Windows logical CPU, default from the measurement record")
    args = parser.parse_args()
    record = json.loads((REPORT / "measurements.json").read_text(encoding="utf-8"))
    pin_cpu(record["logical_cpu"] if args.cpu is None else args.cpu)
    harness = args.harness.resolve(strict=True)
    dlls = {name: getattr(args, name).resolve(strict=True) for name in ("before", "after", "expat")}
    args.out.mkdir(parents=True, exist_ok=False)
    write_fixtures(args.out, record["fixtures"])
    with (REPORT / "timings.csv").open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        rows = list(reader)
        fields = reader.fieldnames
    warmups = set()
    for row in rows:
        key = (row["fixture"], row["chunk_bytes"], row["callbacks"], row["namespaces"], row["engine"])
        if key not in warmups:
            measure(harness, dlls[row["engine"]], args.out, row, 1)
            warmups.add(key)
    with (args.out / "timings.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fields)
        writer.writeheader()
        for row in rows:
            row["ms_per_parse"] = measure(harness, dlls[row["engine"]], args.out, row, row["parses"])
            writer.writerow(row)


if __name__ == "__main__":
    main()
