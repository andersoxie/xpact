"""expat engine for the dual-regression protocol (four-way comparison).

  expat_trace_engine.py --trace FILE [--chunking whole|split@K]
prints one line per chunking:  XPACT_TRACE <tab> chunking <tab> ACCEPT|REJECT <tab> events <tab> error
Events: start:NAME | text:TEXT | end:NAME, adjacent text joined, escaped like DR_TRACE.
Chunkings: whole, split@k, bytes, bytes-final (same meaning as DR_REGRESSION_ROOT). Exit 0.
`--lifecycle` is not supported (the lifecycle inputs live inside the Eiffel harness).
"""
import sys
import xml.parsers.expat as expat


def esc(data: bytes) -> str:
    return "".join(chr(b) if 32 <= b < 127 and b not in (0x5C, 0x7C) else "\\x%02x" % b for b in data)


def trace(data: bytes, chunks):
    events, text = [], []
    def flush():
        if text:
            events.append("text:" + esc("".join(text).encode("utf-8"))); text.clear()
    p = expat.ParserCreate()
    p.StartElementHandler = lambda n, a: (flush(), events.append("start:" + esc(n.encode("utf-8"))))
    p.EndElementHandler = lambda n: (flush(), events.append("end:" + esc(n.encode("utf-8"))))
    p.CharacterDataHandler = lambda t: text.append(t)
    try:
        for i, (part, final) in enumerate(chunks):
            p.Parse(part, final)
        flush()
        return "ACCEPT", " | ".join(events), ""
    except expat.ExpatError as e:
        return "REJECT", "", expat.ErrorString(e.code)


def main(argv):
    if len(argv) < 3 or argv[1] != "--trace":
        print("usage: expat_trace_engine.py --trace FILE [--chunking NAME]", file=sys.stderr); return 2
    data = open(argv[2], "rb").read()
    names = [argv[4]] if len(argv) == 5 and argv[3] == "--chunking" else (
        ["whole"] + ["split@%d" % k for k in range(1, len(data))] + (["bytes"] if data else []) + (["bytes-final"] if len(data) > 1 else []))
    for name in names:
        if name == "whole":
            chunks = [(data, True)]
        elif name == "bytes":          # one non-final call per byte, then an empty final call
            chunks = [(data[i:i + 1], False) for i in range(len(data))] + [(b"", True)]
        elif name == "bytes-final":    # one call per byte, the last byte final
            chunks = [(data[i:i + 1], i == len(data) - 1) for i in range(len(data))]
        else:                          # split@k: bytes 1..k non-final, the rest final
            k = int(name[6:]); chunks = [(data[:k], False), (data[k:], True)]
        verdict, ev, err = trace(data, chunks)
        print("XPACT_TRACE\t%s\t%s\t%s\t%s" % (name, verdict, ev, err))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))