"""Resolve leaf-first sample/module/RVA TSVs with each measured binary's MSVC linker MAP."""
import argparse
import bisect
import collections
import csv
import json
import re
from pathlib import Path


def eiffel_names(root):
    if root is None:
        return {}
    result = {}
    pattern = re.compile(r"/\* (\{[A-Z_0-9]+\}\.[a-z_0-9]+) \*/\s*"
                         r"(?:RTEOMS\([^;\n]+\);\s*)?[^\n;]*?\b(F\d+_\d+)\s*\(")
    for path in root.rglob("*.c"):
        for feature, name in pattern.findall(path.read_text(encoding="latin-1")):
            result[name] = feature
    if not result:
        raise ValueError(f"No generated Eiffel features found under {root}")
    return result


class LinkerMap:
    def __init__(self, path, translations):
        raw = path.read_text(encoding="latin-1")
        base = int(re.search(r"Preferred load address is ([a-fA-F0-9]+)", raw).group(1), 16)
        code = re.findall(r"^\s*([A-Fa-f0-9]+):([A-Fa-f0-9]+)\s+([A-Fa-f0-9]+)H\s+\S+\s+CODE\s*$", raw, re.M)
        # Include public and static functions. /OPT:ICF may give multiple feature
        # names for one instruction address; never pick one arbitrarily.
        symbols = re.findall(r"^\s*([A-Fa-f0-9]+):([A-Fa-f0-9]+)\s+(\S+)\s+([A-Fa-f0-9]+)\s+f\b", raw, re.M)
        segment_base = {}
        names_at = collections.defaultdict(set)
        for segment, offset, name, addr in symbols:
            rva = int(addr, 16) - base
            derived = rva - int(offset, 16)
            if segment_base.setdefault(segment, derived) != derived:
                raise ValueError(f"Inconsistent segment address in {path}: {segment}")
            names_at[rva].add(translations.get(name, name))
        self.sections = []
        for segment, offset, length in code:
            if segment in segment_base and int(length, 16) > 0:
                start = segment_base[segment] + int(offset, 16)
                self.sections.append((start, start + int(length, 16)))
        self.starts = sorted(names_at)
        self.names = {}
        for rva, names in names_at.items():
            if len(names) == 1:
                self.names[rva] = next(iter(names))
            else:
                preview = " | ".join(sorted(names)[:3])
                self.names[rva] = f"[folded RVA {rva:#x}, {len(names)} names: {preview}]"
        if not self.starts or not self.sections:
            raise ValueError(f"No code symbols found in {path}")

    def resolve(self, rva):
        idx = bisect.bisect_right(self.starts, rva) - 1
        if idx >= 0:
            start = self.starts[idx]
            if any(lo <= start <= rva < hi for lo, hi in self.sections):
                return self.names[start]
        return "[unresolved address]"


def summarize(path, maps):
    leaf, inclusive = collections.Counter(), collections.Counter()
    modules = collections.Counter()
    frame_counts = collections.Counter()
    dll_presence = collections.Counter()
    stacks = collections.defaultdict(list)
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = csv.DictReader(handle, delimiter="\t")
        for r in rows:
            module = r["module"].lower()
            rva = int(r["rva"], 0)
            symbol = maps[module].resolve(rva) if module in maps else "[unmapped module]"
            stacks[r["sample_id"]].append((int(r["frame_index"]), module, f"{module}!{symbol}"))
    for key, frames in stacks.items():
        frames.sort()
        if [depth for depth, _, _ in frames] != list(range(len(frames))):
            raise ValueError(f"Missing or duplicate frame in sample {key}")
        _, mod, label = frames[0]
        leaf[label] += 1
        modules[mod] += 1
        frame_counts[len(frames)] += 1
        inclusive.update({symbol for _, _, symbol in frames})
        dll_presence.update({module for _, module, _ in frames})
    if not stacks:
        raise ValueError(f"No samples in {path}")
    return {"sample_file": str(path), "samples": len(stacks), "leaf": leaf,
            "inclusive": inclusive, "leaf_by_module": modules,
            "any_frame_by_module": dll_presence, "stack_depth_counts": frame_counts}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("samples", nargs="+", type=Path)
    ap.add_argument("--map", metavar="MODULE=FILE", action="append", required=True)
    ap.add_argument("--fcode", type=Path, help="F_code for the exact measured build")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--json", type=Path, help="save untruncated counts for all runs")
    args = ap.parse_args()
    names = eiffel_names(args.fcode)
    maps = {}
    for mapping in args.map:
        mod, path = mapping.split("=", 1)
        maps[mod.lower()] = LinkerMap(Path(path), names)
    summaries = []
    for filename in args.samples:
        report = summarize(filename, maps)
        summaries.append(report)
        n = report["samples"]
        print(f"\n{filename.name}: {n} captured stacks")
        for heading in ("leaf_by_module", "any_frame_by_module", "leaf", "inclusive"):
            print(heading)
            for name, count in report[heading].most_common(args.top):
                print(f"  {count:5d}  {100*count/n:5.1f}%  {name}")
    if args.json:
        args.json.write_text(json.dumps(summaries, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
