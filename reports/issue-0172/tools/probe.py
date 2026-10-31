"""#172 probe: events before a forbidden character, whole versus split just before it.

    python -I reports/issue-0172/tools/probe.py <xpact.dll> <libexpat.dll>

Prints, per document and per DLL, the events and the error for: the whole
document in one final XML_Parse call, and two calls split right before the
forbidden character (the second final).
"""
import ctypes as C
import sys

START = C.CFUNCTYPE(None, C.c_void_p, C.c_char_p, C.POINTER(C.c_char_p))
END = C.CFUNCTYPE(None, C.c_void_p, C.c_char_p)
CHARS = C.CFUNCTYPE(None, C.c_void_p, C.POINTER(C.c_char), C.c_int)

DOCS = [
    ("bad char in content", b"<doc>abc\x11def</doc>"),
    ("bad char after child", b"<doc><a/>\x01</doc>"),
    ("bad char in attribute", b"<doc a='x\x02'/>"),
    ("bad char in comment", b"<doc><!-- \x03 --></doc>"),
    ("bad char before root", b"\x04<doc/>"),
    ("bad char after root", b"<doc/>\x05"),
    ("UTF-16LE like o-p02fail15", b"\xff\xfe" + "<doc>\x11</doc>".encode("utf-16-le")),
]


def run(dll, parts):
    lib = C.CDLL(dll)
    lib.XML_ParserCreate.restype = C.c_void_p
    lib.XML_ParserCreate.argtypes = [C.c_char_p]
    lib.XML_Parse.argtypes = [C.c_void_p, C.c_char_p, C.c_int, C.c_int]
    lib.XML_GetErrorCode.argtypes = [C.c_void_p]
    lib.XML_GetCurrentLineNumber.argtypes = [C.c_void_p]
    lib.XML_GetCurrentLineNumber.restype = C.c_ulong
    lib.XML_GetCurrentColumnNumber.argtypes = [C.c_void_p]
    lib.XML_GetCurrentColumnNumber.restype = C.c_ulong
    lib.XML_ParserFree.argtypes = [C.c_void_p]
    events = []
    s = START(lambda u, n, a: events.append(("start", n.decode())))
    e = END(lambda u, n: events.append(("end", n.decode())))
    t = CHARS(lambda u, p, n: events.append(("text", C.string_at(p, n).decode("utf-8", "replace"))))
    p = lib.XML_ParserCreate(None)
    lib.XML_SetElementHandler.argtypes = [C.c_void_p, START, END]
    lib.XML_SetCharacterDataHandler.argtypes = [C.c_void_p, CHARS]
    lib.XML_SetElementHandler(p, s, e)
    lib.XML_SetCharacterDataHandler(p, t)
    status = 1
    for i, part in enumerate(parts):
        status = lib.XML_Parse(p, part, len(part), 1 if i == len(parts) - 1 else 0)
        if status == 0:
            break
    err = (lib.XML_GetErrorCode(p), lib.XML_GetCurrentLineNumber(p), lib.XML_GetCurrentColumnNumber(p)) if status == 0 else None
    lib.XML_ParserFree(p)
    merged = []
    for ev in events:
        if ev[0] == "text" and merged and merged[-1][0] == "text":
            merged[-1] = ("text", merged[-1][1] + ev[1])
        else:
            merged.append(ev)
    return merged, err


def split_before_bad(doc):
    body = doc[2:].decode("utf-16-le") if doc.startswith(b"\xff\xfe") else doc.decode("latin-1")
    k = next(i for i, ch in enumerate(body) if ord(ch) < 32 and ch not in "\t\n\r")
    if doc.startswith(b"\xff\xfe"):
        k = 2 + 2 * k
    return [doc[:k], doc[k:]]


def main():
    xpact, expat = sys.argv[1], sys.argv[2]
    for name, doc in DOCS:
        print(f"== {name}: {doc!r}")
        for label, dll in (("xpact", xpact), ("expat", expat)):
            for mode, parts in (("whole", [doc]), ("split", split_before_bad(doc))):
                ev, err = run(dll, parts)
                print(f"   {label:5} {mode:5} events={ev} error={err}")


if __name__ == "__main__":
    main()
