"""Repeat the recorded Windows DLL timings with the stock fair_speed.exe caller."""

import argparse
import csv
import hashlib
import json
import runpy
import subprocess
from pathlib import Path


REPORT = Path(__file__).resolve().parent
ROOT = REPORT.parents[1]


def write_fixture(path, document):
    shape, size, encoding = path.stem.split("-")
    if size == "1MB":
        raw = document(shape, 1_000_000).encode("utf-8")
    else:
        text = document(shape, int(size.rstrip("k")) * 1024)
        text = text.replace("<value>", "<value>\u00e9")
        codec = "ISO-8859-1" if encoding == "latin1" else "UTF-8"
        raw = text.replace('encoding="UTF-8"', f'encoding="{codec}"').encode(codec)
    path.write_bytes(raw)
    return hashlib.sha256(raw).hexdigest()


def measure(harness, dlls, folder, row, iterations):
    fixture = folder / (row["fixture"] + ".xml")
    command = [harness, dlls[row["engine"]], fixture, row["chunk"], row["callbacks"],
               row["namespaces"], str(iterations)]
    process = subprocess.run(command, capture_output=True, text=True, check=True, timeout=120)
    status, error, ms, checksum = process.stdout.splitlines()[-1].split()
    if (status, error, checksum) != ("1", "0", row["checksum"]):
        raise RuntimeError(f"Unexpected parse for {command}: {process.stdout}")
    return ms


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("harness", "before", "after", "expat", "out"):
        parser.add_argument("--" + flag, required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    dlls = {name: getattr(args, name).resolve(strict=True) for name in ("before", "after", "expat")}
    harness = args.harness.resolve(strict=True)
    with (REPORT / "timings.csv").open(newline="") as source:
        reader = csv.DictReader(source)
        records = list(reader)
        fields = reader.fieldnames
    expected = json.loads((REPORT / "measurements.json").read_text(encoding="utf-8"))
    document = runpy.run_path(str(ROOT / "benchmarks/fair_speed/gen_inputs.py"))["document"]
    for name, digest in expected["fixture_sha256"].items():
        if write_fixture(args.out / (name + ".xml"), document) != digest:
            raise RuntimeError(f"Fixture hash differs for {name}")
    seen = set()
    for row in records:
        identity = row["case"], row["engine"]
        if identity not in seen:
            measure(harness, dlls, args.out, row, 1)
            seen.add(identity)
    with (args.out / "timings.csv").open("w", newline="", encoding="utf-8") as dest:
        writer = csv.DictWriter(dest, fields)
        writer.writeheader()
        for row in records:
            row["ms_per_parse"] = measure(harness, dlls, args.out, row, int(row["parses"]))
            writer.writerow(row)


if __name__ == "__main__":
    main()
