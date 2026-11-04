"""Every split point and byte-by-byte must equal the whole parse. python -I edge11.py <dll>"""
import ctypes as C
import sys

dll = C.CDLL(sys.argv[1])
P = C.c_void_p
for name, res, args in [
    ("XML_ParserCreate", P, [C.c_char_p]), ("XML_ParserFree", None, [P]),
    ("XML_Parse", C.c_int, [P, C.c_char_p, C.c_int, C.c_int]), ("XML_GetErrorCode", C.c_int, [P]),
    ("XML_GetCurrentLineNumber", C.c_ulong, [P]), ("XML_GetCurrentColumnNumber", C.c_ulong, [P]),
    ("XML_SetReparseDeferralEnabled", C.c_ubyte, [P, C.c_ubyte]),
]:
    f = getattr(dll, name)
    f.restype, f.argtypes = res, args
CharH = C.CFUNCTYPE(None, P, C.POINTER(C.c_char), C.c_int)
StartH = C.CFUNCTYPE(None, P, C.c_char_p, C.POINTER(C.c_char_p))
EndH = C.CFUNCTYPE(None, P, C.c_char_p)
for n in ("XML_SetCharacterDataHandler", "XML_SetDefaultHandler"):
    getattr(dll, n).argtypes = [P, CharH]
dll.XML_SetStartElementHandler.argtypes = [P, StartH]
dll.XML_SetEndElementHandler.argtypes = [P, EndH]

jp = "日本語".encode()
DTD = b"<!DOCTYPE a [<!ENTITY e 'ENT<b>in</b>x'><!ENTITY t 'TT'>]>"
docs = {
    "plain": b"<a>hello world, a long run of text</a>",
    "cdata-close": b"<a>xx]]>yy</a>",
    "brackets": b"<a>t]]x]y]]]z]</a>",
    "brackets-end": b"<a>abc]]</a>",
    "amp": b"<a>x&amp;y&lt;z&#65;&#x42;w</a>",
    "general": DTD + b"<a>before &t; mid &e; after &t;</a>",
    "jp": b"<a>" + jp * 5 + b"&amp;" + jp + b"</a>",
    "crlf": b"<a>line1\r\nline2\rline3\r\n\r\nend</a>",
    "nested": b"<a>one<b>two</b>three<c/>four</a>",
    "bad-char": b"<a>abc\x01def</a>",
    "bad-utf8": b"<a>abc\xe6\x97def</a>",
    "unclosed": b"<a>text that never ends",
    "unterminated-ref": b"<a>x &amp y</a>",
    "undefined-ent": b"<a>x &nope; y</a>",
    "after-root": b"<a>x</a>  tail",
    "pi-comment": b"<a>t1<?p d?>t2<!--c-->t3</a>",
}


def run(doc, parts, deferral, default):
    events = []
    keep = [CharH(lambda u, s, n: events.append(("c", C.string_at(s, n)))),
            StartH(lambda u, n, a: events.append(("s", n))),
            EndH(lambda u, n: events.append(("e", n))),
            CharH(lambda u, s, n: events.append(("d", C.string_at(s, n))))]
    p = dll.XML_ParserCreate(None)
    dll.XML_SetReparseDeferralEnabled(p, deferral)
    dll.XML_SetCharacterDataHandler(p, keep[0])
    dll.XML_SetStartElementHandler(p, keep[1])
    dll.XML_SetEndElementHandler(p, keep[2])
    if default:
        dll.XML_SetDefaultHandler(p, keep[3])
    status = 1
    for i, part in enumerate(parts):
        status = dll.XML_Parse(p, part, len(part), 1 if i == len(parts) - 1 else 0)
        if status != 1:
            break
    out = (status, dll.XML_GetErrorCode(p), dll.XML_GetCurrentLineNumber(p), dll.XML_GetCurrentColumnNumber(p))
    dll.XML_ParserFree(p)
    merged = []
    for k, v in events:  # adjacent text pieces form one string, as an application would join them
        if merged and merged[-1][0] == k and k in "cd":
            merged[-1] = (k, merged[-1][1] + v)
        else:
            merged.append((k, v))
    return out, merged


bad = 0
checks = 0
for name, doc in docs.items():
    for deferral in (1, 0):
        for default in (0, 1):
            whole = run(doc, [doc], deferral, default)
            splits = [[doc[:k], doc[k:]] for k in range(1, len(doc))] + [[doc[i:i + 1] for i in range(len(doc))]]
            for parts in splits:
                checks += 1
                got = run(doc, parts, deferral, default)
                if got != whole:
                    bad += 1
                    print("DIFF", name, f"deferral={deferral} default={default}", [len(x) for x in parts][:3], got[0], whole[0])
print(f"{checks} checks, {bad} differ")
