"""Test 9: does xpact.dll leak memory? Each scenario runs create -> parse -> free many times in a
fresh process and samples the private memory (Windows PagefileUsage) after warm-up and at the end.

A leak shows as memory that keeps growing with the number of rounds; a flat line is no leak.
Expat (pyexpat) runs the same scenarios as a control for the Python harness itself.
Usage: python leak.py [--rounds 20000] [--dll path] [--tag xpact]
       python leak.py --child ENGINE SCENARIO ROUNDS   (internal)
"""
import argparse
import ctypes
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))

DTD = ('<!DOCTYPE d [<!ENTITY e "entity &#38;amp; text"><!ATTLIST d a CDATA "default" t NMTOKENS " x y ">'
       '<!NOTATION n SYSTEM "s"><!ELEMENT d ANY>]>')
SCENARIOS = {
    "small-document": b'<?xml version="1.0"?><d a="1"><e>text &amp; more</e><![CDATA[c]]><!--k--><?p q?></d>',
    "dtd-entities-defaults": (DTD + "<d>&e;&e;<x/></d>").encode(),
    "namespaces": b'<d xmlns="urn:a" xmlns:p="urn:p"><p:e p:a="1"/><e xmlns=""/></d>',
    "error-document": b"<d><e></d>",
    "chunked-byte-by-byte": (DTD + "<d>&e;<x a='1'>text</x></d>").encode(),
    "external-entity": b'<!DOCTYPE d [<!ENTITY x SYSTEM "x.ent">]><d>&x;</d>',
    "parser-reset-reuse": b'<d a="1"><e>reuse</e></d>',
    "billion-laughs-small": ('<!DOCTYPE d [<!ENTITY a "aaaaaaaaaa">' + "".join(
        f'<!ENTITY {c} "' + f"&{p};" * 10 + '">' for p, c in zip("abcd", "bcde")) + "]><d>&e;</d>").encode(),
}


class _Counters(ctypes.Structure):
    _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong)] + [
        (n, ctypes.c_size_t) for n in ("PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                                       "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
                                       "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage")]


def private_mb():
    c = _Counters()
    c.cb = ctypes.sizeof(c)
    ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(ctypes.windll.kernel32.GetCurrentProcess()),
                                             ctypes.byref(c), c.cb)
    return c.PagefileUsage / 2**20


def child(engine, scenario, rounds):
    import engines
    data = SCENARIOS[scenario]
    kw = {}
    if scenario == "namespaces":
        kw["namespaces"] = True
    if scenario == "chunked-byte-by-byte":
        kw["split"] = "byte"
    if scenario == "external-entity":
        (HERE / "x.ent").write_bytes(b"<from-entity a='1'>external</from-entity>")
        kw["entity_root"] = str(HERE)
        kw["path"] = str(HERE / "doc.xml")
    reset = scenario == "parser-reset-reuse" and engine == "xpact"
    if reset:
        lib = engines.load()
        lib.XML_ParserReset.restype, lib.XML_ParserReset.argtypes = ctypes.c_ubyte, [ctypes.c_void_p, ctypes.c_char_p]
        parser = lib.XML_ParserCreate(None)
    samples = []
    for i in range(rounds):
        if reset:
            lib.XML_ParserReset(parser, None)
            lib.XML_Parse(parser, data, len(data), 1)
        else:
            engines.parse(engine, data, **kw)
        if i in (rounds // 10, rounds // 4, rounds // 2, (3 * rounds) // 4, rounds - 1):
            samples.append(round(private_mb(), 1))
    if reset:
        lib.XML_ParserFree(parser)
    print(json.dumps(samples))


if len(sys.argv) > 1 and sys.argv[1] == "--child":
    child(sys.argv[2], sys.argv[3], int(sys.argv[4]))
    sys.exit(0)

ap = argparse.ArgumentParser()
ap.add_argument("--rounds", type=int, default=20000)
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
args = ap.parse_args()
env = None
if args.dll:
    import os
    env = {**os.environ, "XPACT_DLL": args.dll}
results = []
print(f"{'scenario':24} engine  memory (MB) at 10% / 25% / 50% / 75% / 100% of {args.rounds} rounds   growth after warm-up")
for scenario in SCENARIOS:
    for engine in ("xpact", "expat"):
        if engine == "expat" and scenario == "parser-reset-reuse":
            continue
        p = subprocess.run([sys.executable, __file__, "--child", engine, scenario, str(args.rounds)],
                           capture_output=True, text=True, env=env, timeout=3600)
        if p.returncode != 0:
            row = {"scenario": scenario, "engine": engine, "status": f"CRASH exit 0x{p.returncode & 0xFFFFFFFF:08X}",
                   "stderr": p.stderr[-400:]}
        else:
            s = json.loads(p.stdout.strip().splitlines()[-1])
            growth = round(s[-1] - s[0], 1)
            per_1000 = round(growth / (args.rounds * 0.9) * 1000 * 1024, 1)  # KB per 1,000 rounds
            row = {"scenario": scenario, "engine": engine, "samples_mb": s, "growth_mb": growth,
                   "kb_per_1000_rounds": per_1000}
        results.append(row)
        print(f"{scenario:24} {engine:6}  {row.get('samples_mb', row.get('status'))}   "
              f"{row.get('growth_mb', '')} MB ({row.get('kb_per_1000_rounds', '')} KB / 1,000)", flush=True)
(HERE / "logs").mkdir(exist_ok=True)
(HERE / "logs" / f"leak-{args.tag}.json").write_text(json.dumps({"rounds": args.rounds, "results": results}, indent=1))
