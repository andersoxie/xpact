"""Test 5b: where exactly are xpact's built-in limits (src/xp_limits.e), and what error does it report?

Each limit is probed just below and just above the documented value; the large-document
probes are fed in 64 KB chunks, the way an application streams a file.
"""
import csv
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402

dll = sys.argv[1] if len(sys.argv) > 1 else None
MB = 2**20
inputs = HERE / "inputs"
inputs.mkdir(exist_ok=True)

PROBES = [
    ("element depth", "Default_max_element_depth = 256", [255, 256, 257],
     lambda n: "<a>" * n + "</a>" * n, None),
    ("attributes per element", "Default_max_attribute_count = 1024", [1023, 1024, 1025],
     lambda n: "<d " + " ".join(f'a{i}="v"' for i in range(n)) + "/>", None),
    ("namespace declarations per element", "(attribute limit)", [1023, 1024, 1025],
     lambda n: "<d " + " ".join(f'xmlns:p{i}="u"' for i in range(n)) + "/>", "ns"),
    ("name length (bytes)", "set_max_name_length (524288) in the DLL", [524288, 524289],
     lambda n: "<" + "n" * n + "/>", None),
    ("attribute value (bytes)", "Default_max_token_length = 1 MiB?", [MB - 64, MB + 64],
     lambda n: '<d a="' + "v" * n + '"/>', None),
    ("text in one element, streamed (bytes)", "Default_max_input_bytes = 10 MiB?", [9 * MB, 11 * MB],
     lambda n: "<d>" + "t" * n + "</d>", "every:65536"),
    ("document of many small elements, streamed (bytes)", "Default_max_input_bytes = 10 MiB?",
     [9 * MB, 11 * MB, 50 * MB], lambda n: "<d>" + "<e>x</e>" * (n // 8) + "</d>", "every:65536"),
]

rows = []
for name, source, sizes, make, mode in PROBES:
    for n in sizes:
        path = inputs / f"limit-{name.split()[0]}-{n}.xml"
        data = make(n).encode()
        if not path.exists() or path.stat().st_size != len(data):
            path.write_bytes(data)
        job = {"file": str(path), "keep_events": False}
        if mode == "ns":
            job["namespaces"] = True
        elif mode:
            job["split"] = mode
        row = {"limit": name, "source": source, "n": n}
        for engine in ("xpact", "expat"):
            with Pool(engine, timeout=120, dll=dll) as pool:
                r = pool.run(job)
            row[engine] = r["verdict"]
            row[engine + "_message"] = r.get("message") or r.get("exit_hex", "")
            row[engine + "_s"] = r.get("seconds", "")
        rows.append(row)
        print(f"{name:52} n={n:>10}  xpact {row['xpact']:7} {row['xpact_message']:35} {row['xpact_s']!s:>8}s"
              f" | expat {row['expat']:7} {row['expat_s']}s", flush=True)

with open(HERE / "logs" / "limits.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
    w.writeheader()
    w.writerows(rows)
