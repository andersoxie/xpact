"""Test 3: mutation fuzzing of xpact.dll. Looks for crashes and hangs; also records verdict
differences with Expat on the same input (counted, the details belong to test 4).

Seeds: every W3C document up to 4 KB. Each input is a seed with 1-8 mutations, fed whole or
in random chunks. Crashing / hanging inputs are saved to findings/.
Usage: python fuzz.py --seconds 1800 [--seed 1] [--dll path] [--tag xpact]
"""
import argparse
import hashlib
import json
import random
import sys
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402
import w3c  # noqa: E402

TOKENS = [b"<", b">", b"/>", b"</", b"&", b";", b"&amp;", b"&#x", b"&#", b"%", b"<!DOCTYPE d [", b"]>", b"<!ENTITY ",
          b"<!ENTITY % p ", b"<!ATTLIST d a CDATA ", b"<!ELEMENT d ANY>", b"<![CDATA[", b"]]>", b"<!--", b"-->", b"<?",
          b"?>", b"<?xml version='1.0'?>", b"encoding='UTF-16'", b"standalone='yes'", b"xmlns:a='u'", b"xmlns=''",
          b"a:", b"'", b'"', b"=", b" ", b"\n", b"\r", b"\t", b"\x00", b"\xff", b"\xfe", b"\xef\xbb\xbf", b"\xc3",
          b"\xe2\x82", b"\xf0\x9d\x84\x9e", b"&e;", b"%p;", b"SYSTEM 'x'", b"PUBLIC 'p' 's'", b"NDATA n", b"#FIXED",
          b"#REQUIRED", b"<![INCLUDE[", b"<![IGNORE[", b"(#PCDATA|a)*", b"EMPTY", b"x" * 300]


def mutate(rng, data, seeds):
    data = bytearray(data)
    for _ in range(rng.randint(1, 8)):
        op = rng.randrange(7)
        pos = rng.randint(0, len(data))
        if op == 0 and data:  # flip a bit
            i = rng.randrange(len(data))
            data[i] ^= 1 << rng.randrange(8)
        elif op == 1 and data:  # delete a range
            del data[pos:pos + rng.randint(1, 16)]
        elif op == 2:  # insert a token
            data[pos:pos] = rng.choice(TOKENS)
        elif op == 3 and data:  # duplicate a range
            a = rng.randrange(len(data))
            data[pos:pos] = data[a:a + rng.randint(1, 64)]
        elif op == 4:  # splice from another seed
            other = rng.choice(seeds)
            a = rng.randrange(max(1, len(other)))
            data[pos:pos] = other[a:a + rng.randint(1, 128)]
        elif op == 5 and data:  # random byte
            data[rng.randrange(len(data))] = rng.randrange(256)
        else:  # repeat a range many times
            a = rng.randrange(max(1, len(data)))
            data[pos:pos] = bytes(data[a:a + rng.randint(1, 8)]) * rng.randint(2, 200)
    return bytes(data)


ap = argparse.ArgumentParser()
ap.add_argument("--seconds", type=int, default=600)
ap.add_argument("--seed", type=int, default=1)
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
args = ap.parse_args()
rng = random.Random(args.seed)
seeds = [c.path.read_bytes() for c, _ in w3c.cases() if c.path.is_file() and c.path.stat().st_size <= 4096]
findings = HERE / "findings"
findings.mkdir(exist_ok=True)
stats, verdicts, saved = Counter(), Counter(), []
deadline = time.time() + args.seconds
with Pool("xpact", timeout=10, dll=args.dll) as xp, Pool("expat", timeout=10) as ex:
    while time.time() < deadline:
        data = mutate(rng, rng.choice(seeds), seeds)
        split = rng.choice([None, None, "byte", f"every:{rng.randint(2, 64)}", rng.randint(1, max(1, len(data) - 1))])
        if split == "byte" and len(data) > 3000:
            split = None
        job = {"data": data.decode("latin-1"), "split": split, "keep_events": False,
               "namespaces": rng.random() < 0.3}
        x = xp.run(job)
        stats["inputs"] += 1
        if x["verdict"] in ("CRASH", "TIMEOUT"):
            # a hang can be the known streaming slowdown (test 5, F05-1): retry whole, 60 s
            again = xp.run({**job, "split": None}, timeout=60)
            kind = f"{x['verdict']}{' ' + x.get('exit_hex', '') if x['verdict'] == 'CRASH' else ''}" \
                   f" (whole: {again['verdict']})"
            stats[kind] += 1
            name = hashlib.sha1(data).hexdigest()[:12]
            (findings / f"{name}.xml").write_bytes(data)
            (findings / f"{name}.json").write_text(json.dumps({"kind": kind, "split": split,
                                                               "namespaces": job["namespaces"]}))
            saved.append((name, kind))
            print(f"[{stats['inputs']}] {kind}: findings/{name}.xml split={split}", flush=True)
            continue
        e = ex.run({**job, "split": None})
        verdicts[f"xpact {x['verdict']} / expat {e['verdict']}"] += 1
print(json.dumps({"stats": stats, "verdicts": verdicts, "saved": saved}, indent=1))
(HERE / "logs").mkdir(exist_ok=True)
(HERE / "logs" / f"fuzz-{args.tag}-seed{args.seed}.json").write_text(
    json.dumps({"seconds": args.seconds, "stats": stats, "verdicts": verdicts, "saved": saved}, indent=1))
