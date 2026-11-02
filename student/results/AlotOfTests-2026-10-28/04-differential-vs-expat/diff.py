"""Test 4: grammar-based differential testing, xpact.dll vs Expat.

Generates random documents that use most XML features (about 1 in 5 gets one small mutation),
parses each with both engines (whole document) and compares verdict, error code and, when both
accept, the events. Differences are grouped by a signature; the first example of each group is
shrunk (delta debugging) to a minimal input with the same signature.
Usage: python diff.py --seconds 1200 [--seed 1] [--dll path] [--tag xpact]
"""
import argparse
import json
import random
import sys
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402

NAMES = ["d", "e", "f", "item", "x1", "a-b", "a.b", "_u", "é", "ñame", "名前", "Ω"]
WORDS = ["hello", " ", "  two  spaces ", "\n", "\t", "\r\n", "&amp;", "&lt;", "&gt;", "&quot;", "&apos;", "&#65;",
         "&#x20AC;", "&#x1D11E;", "é", "€", "𝄞", "]]", ">", "'", '"']


class Gen:
    def __init__(self, rng, ns):
        self.r, self.ns = rng, ns
        self.entities, self.ids, self.notations, self.declared = [], [], [], {}

    def name(self):
        n = self.r.choice(NAMES)
        if self.ns and self.r.random() < 0.3:
            return "p:" + n
        return n

    def text(self, in_attr=False):
        out = []
        for _ in range(self.r.randint(0, 4)):
            w = self.r.choice(WORDS)
            if in_attr and w in ("'", '"'):
                w = "&quot;" if w == '"' else "&apos;"
            out.append(w)
            if self.entities and self.r.random() < 0.3:
                out.append(f"&{self.r.choice(self.entities)};")
        return "".join(out)

    def dtd(self, root):
        r, parts = self.r, []
        for i in range(r.randint(0, 3)):
            n = f"ent{i}"
            value = self.text()
            if self.entities and r.random() < 0.4:
                value += f"&{r.choice(self.entities)};"
            if r.random() < 0.3:
                value += f"<{root}x>{self.text()}</{root}x>"
            parts.append(f'<!ENTITY {n} "{value}">')
            self.entities.append(n)
        if r.random() < 0.4:
            parts.append('<!ENTITY % pe "<!ENTITY fromPE \'pe-text\'>">%pe;')
            self.entities.append("fromPE")
        for i in range(r.randint(0, 2)):
            parts.append(f"<!NOTATION n{i} {r.choice(['SYSTEM \"s\"', 'PUBLIC \"p  q\"', 'PUBLIC \"p\" \"s\"'])}>")
            self.notations.append(f"n{i}")
        elements = {root, *(r.choice(NAMES) for _ in range(3))}
        for el in elements:
            if r.random() < 0.5:
                parts.append(f"<!ELEMENT {el} {r.choice(['ANY', 'EMPTY', '(#PCDATA)', '(#PCDATA|e|f)*', '(e,f?)+'])}>")
            for _ in range(r.randint(0, 3)):
                att = r.choice(["a", "b", "c", "id", "ref", "tok", "toks", "en", "no"])
                typ = {"id": "ID", "ref": "IDREF", "tok": "NMTOKEN", "toks": "NMTOKENS",
                       "en": "(one|two|three)", "no": f"NOTATION ({'|'.join(self.notations) or 'x'})"}.get(att, "CDATA")
                default = r.choice(["#IMPLIED", "#REQUIRED", f'"{self.text(True) or "v"}"', '"  one  two "',
                                    f'#FIXED "{self.text(True) or "f"}"'])
                parts.append(f"<!ATTLIST {el} {att} {typ} {default}>")
                self.declared.setdefault(el, []).append(att)
        if r.random() < 0.3:
            parts.append("<?pi in subset?><!-- comment in subset -->")
        return "".join(parts)

    def element(self, depth):
        r = self.r
        n = self.name()
        attrs, used = [], set()
        if self.ns and r.random() < 0.4:
            attrs.append(r.choice(['xmlns:p="urn:p"', 'xmlns="urn:d"', 'xmlns=""', 'xmlns:q="urn:q"']))
        for _ in range(r.randint(0, 3)):
            a = r.choice(["a", "b", "c", "id", "tok", "toks", "en", "p:a" if self.ns else "z", "xml:lang", "xml:space"])
            if a in used:
                continue
            used.add(a)
            v = {"id": f"i{r.randint(0, 3)}", "tok": " t1 ", "toks": "  t1   t2 ", "en": r.choice(["one", " two "]),
                 "xml:space": r.choice(["preserve", "default"])}.get(a, self.text(True))
            q = r.choice(['"', "'"])
            v = v.replace(q, "&quot;" if q == '"' else "&apos;")
            attrs.append(f"{a}={q}{v}{q}")
        start = f"<{n}{''.join(' ' + a for a in attrs)}"
        if depth > 4 or r.random() < 0.25:
            return start + "/>"
        body = []
        for _ in range(r.randint(0, 4)):
            k = r.random()
            if k < 0.35:
                body.append(self.text())
            elif k < 0.6:
                body.append(self.element(depth + 1))
            elif k < 0.7:
                body.append(f"<![CDATA[{self.text()}<&>]]>")
            elif k < 0.8:
                body.append(f"<!--{self.text().replace('-', '')}-->")
            elif k < 0.9:
                body.append(f"<?pi{r.randint(0, 9)} {self.text()}?>")
            elif self.entities:
                body.append(f"&{r.choice(self.entities)};")
        return start + ">" + "".join(body) + f"</{n}>"

    def document(self):
        r = self.r
        head = r.choice(["", '<?xml version="1.0"?>', '<?xml version="1.0" encoding="UTF-8"?>',
                         '<?xml version="1.0" standalone="yes"?>', "<?xml version='1.0' encoding='utf-8' standalone='no'?>"])
        root = r.choice(NAMES[:4])
        doctype = ""
        if r.random() < 0.6:
            doctype = f"<!DOCTYPE {root} [{self.dtd(root)}]>"
        body = self.element(0)
        if not body.startswith(f"<{root}"):
            body = f"<{root}>{body}</{root}>"
        tail = r.choice(["", "\n", "<!-- after -->", "<?after pi?>"])
        return head + doctype + body + tail


def mutate(r, s):
    i = r.randrange(len(s))
    return s[:i] + r.choice(["<", "&", "]]>", "'", '"', "", "--", "&#0;", "x"]) + s[i + r.randint(0, 3):]


def signature(x, e):
    if e.get("message", "").startswith("python LookupError"):
        # pyexpat's Python-codec handler; C Expat without a handler reports "unknown encoding"
        e = {**e, "verdict": "REJECT", "error": 18, "message": "unknown encoding"}
    if x["verdict"] != e["verdict"]:
        return f"verdict: xpact {x['verdict']} ({x.get('message', '')}) / expat {e['verdict']} ({e.get('message', '')})"
    if x["verdict"] == "REJECT":
        return None if x["error"] == e["error"] else f"error: xpact {x['message']} / expat {e['message']}"
    if x["events"] == e["events"]:
        return None
    i = next((k for k, (a, b) in enumerate(zip(x["events"], e["events"])) if a != b),
             min(len(x["events"]), len(e["events"])))
    xa = x["events"][i] if i < len(x["events"]) else ["(none)"]
    ea = e["events"][i] if i < len(e["events"]) else ["(none)"]
    detail = ""
    if xa[0] == ea[0] and xa[0] != "start":
        fields = [k for k, (p, q) in enumerate(zip(xa, ea)) if p != q]
        detail = f" field {fields[0] if fields else 'count'}"
    if xa[0] == ea[0] == "start":
        xs, es = dict(zip(xa[2][0::2], xa[2][1::2])), dict(zip(ea[2][0::2], ea[2][1::2]))
        keys = sorted(k for k in set(xs) | set(es) if xs.get(k) != es.get(k))
        detail = " attrs " + ",".join(("missing:" if k not in xs else "extra:" if k not in es else "value:") + k.split("|")[-1]
                                      for k in keys[:3])
    return f"events: xpact {xa[0]} / expat {ea[0]}{detail}"


def run_pair(xp, ex, doc, ns):
    job = {"data": doc.encode("utf-8").decode("latin-1"), "namespaces": ns}
    return xp.run(job), ex.run(job)


def shrink(xp, ex, doc, ns, sig, budget=400):
    """Remove pieces while the signature stays the same (simple delta debugging)."""
    n = 2
    while len(doc) > 1 and budget > 0:
        size = max(1, len(doc) // n)
        reduced = False
        for i in range(0, len(doc), size):
            cand = doc[:i] + doc[i + size:]
            budget -= 1
            x, e = run_pair(xp, ex, cand, ns)
            if x["verdict"] not in ("CRASH", "TIMEOUT") and signature(x, e) == sig:
                doc, n, reduced = cand, max(n - 1, 2), True
                break
        if not reduced:
            if size == 1:
                break
            n = min(n * 2, len(doc))
    return doc


ap = argparse.ArgumentParser()
ap.add_argument("--seconds", type=int, default=600)
ap.add_argument("--seed", type=int, default=1)
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
args = ap.parse_args()
rng = random.Random(args.seed)
groups, examples, stats = Counter(), {}, Counter()
deadline = time.time() + args.seconds
with Pool("xpact", timeout=10, dll=args.dll) as xp, Pool("expat", timeout=10) as ex:
    while time.time() < deadline:
        ns = rng.random() < 0.3
        doc = Gen(rng, ns).document()
        if rng.random() < 0.2:
            doc = mutate(rng, doc)
        x, e = run_pair(xp, ex, doc, ns)
        stats["documents"] += 1
        stats[f"xpact {x['verdict']} / expat {e['verdict']}"] += 1
        if x["verdict"] in ("CRASH", "TIMEOUT"):
            sig = f"xpact {x['verdict']}"
        else:
            sig = signature(x, e)
        if sig:
            groups[sig] += 1
            if sig not in examples:
                examples[sig] = {"namespaces": ns, "original": doc}
    for sig, ex_ in examples.items():
        if not sig.startswith("xpact CRASH") and not sig.startswith("xpact TIMEOUT"):
            ex_["minimal"] = shrink(xp, ex, ex_["original"], ex_["namespaces"], sig,
                                    budget=3000 if sig.startswith(("events", "verdict")) else 300)
            x, e = run_pair(xp, ex, ex_["minimal"], ex_["namespaces"])
            if sig.startswith("events"):
                i = next((k for k, (a, b) in enumerate(zip(x["events"], e["events"])) if a != b), 0)
                ex_["xpact_event"] = x["events"][i] if i < len(x["events"]) else None
                ex_["expat_event"] = e["events"][i] if i < len(e["events"]) else None
out = HERE / "logs"
out.mkdir(exist_ok=True)
report = {"seconds": args.seconds, "seed": args.seed, "stats": stats,
          "groups": [{"signature": s, "count": n, **examples[s]} for s, n in groups.most_common()]}
(out / f"diff-{args.tag}-seed{args.seed}.json").write_text(json.dumps(report, indent=1, ensure_ascii=False), encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8")
print(json.dumps(stats, indent=1))
for g in report["groups"]:
    print(f"{g['count']:6}  {g['signature']}\n        minimal: {g.get('minimal', '')[:200]!r}")
    if "xpact_event" in g:
        print(f"        xpact {g['xpact_event']!r}\n        expat {g['expat_event']!r}")
