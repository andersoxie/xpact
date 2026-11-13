"""Billion-laughs probe: XPact worker (xpact.dll) vs Expat (pyexpat), with a time cap.

usage: python laughs.py <Xpact.Worker.exe> <xpact.dll> <out-dir>
Writes the documents it used and a results.json to <out-dir>.
"""
import json
import subprocess
import sys
import time
import xml.parsers.expat as expat
from pathlib import Path

worker, dll, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)


def laughs(levels: int) -> bytes:
    """levels nested entities of 10 references each: expands to 10 ** (levels + 1) bytes."""
    names = [chr(ord("a") + i) for i in range(levels + 1)]
    decls = [f'<!ENTITY {names[0]} "aaaaaaaaaa">']
    for prev, name in zip(names, names[1:]):
        decls.append(f'<!ENTITY {name} "{("&" + prev + ";") * 10}">')
    return f'<!DOCTYPE l [{"".join(decls)}]><l>&{names[-1]};</l>'.encode()


rows = []
for levels in (3, 4, 5, 6, 8):
    doc = laughs(levels)
    (out / f"laughs-{levels}.xml").write_bytes(doc)
    expanded = 10 ** (levels + 1)

    t = time.perf_counter()
    try:
        p = subprocess.run([str(worker), "--dll", str(dll), "--build", "production", "--max-events", "0"],
                           input=doc, capture_output=True, timeout=60)
        xp = json.loads(p.stdout) if p.stdout.strip() else {"verdict": f"exit 0x{p.returncode & 0xFFFFFFFF:08X}"}
        xp_verdict = xp["verdict"] + (f" ({xp['error']['message']})" if xp.get("error") else "")
    except subprocess.TimeoutExpired:
        xp_verdict = "still running after 60 s (killed)"
    xp_ms = round((time.perf_counter() - t) * 1000)

    t = time.perf_counter()
    parser = expat.ParserCreate()
    parser.CharacterDataHandler = lambda s: None
    try:
        parser.Parse(doc, True)
        ex_verdict = "accepted"
    except expat.ExpatError as e:
        ex_verdict = f"rejected ({expat.ErrorString(e.code)})"
    ex_ms = round((time.perf_counter() - t) * 1000)

    row = {"levels": levels, "input_bytes": len(doc), "expands_to_bytes": expanded,
           "xpact": xp_verdict, "xpact_ms": xp_ms, "expat": ex_verdict, "expat_ms": ex_ms}
    rows.append(row)
    print(row, flush=True)

(out / "results.json").write_text(json.dumps({"expat_version": expat.EXPAT_VERSION, "rows": rows}, indent=2))
