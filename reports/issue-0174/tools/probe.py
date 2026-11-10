"""#174 probe: the default and isrequired that AttlistDeclHandler receives, per kind of default.

    python -I reports/issue-0174/tools/probe.py <xpact dll> <libexpat dll>

Expat's expat.h: "isrequired" is true for #REQUIRED and #FIXED; the default is NULL
for #REQUIRED and #IMPLIED and is passed for #FIXED and a plain default.
"""
import ctypes as C
import sys

P = C.c_char_p
ATTLIST = C.CFUNCTYPE(None, C.c_void_p, P, P, P, P, C.c_int)

DOCS = [
    ("#REQUIRED", b"<!DOCTYPE d [<!ATTLIST d a CDATA #REQUIRED>]><d a='x'/>"),
    ("#IMPLIED", b"<!DOCTYPE d [<!ATTLIST d a CDATA #IMPLIED>]><d/>"),
    ("#FIXED", b"<!DOCTYPE d [<!ATTLIST d a CDATA #FIXED 'v'>]><d/>"),
    ("#FIXED, enumerated type", b"<!DOCTYPE d [<!ATTLIST d a (x|y) #FIXED 'x'>]><d/>"),
    ("plain default", b"<!DOCTYPE d [<!ATTLIST d a CDATA 'v'>]><d/>"),
]


def run(dll, doc):
    lib = C.CDLL(dll)
    lib.XML_ParserCreate.restype = C.c_void_p
    lib.XML_ParserCreate.argtypes = [P]
    lib.XML_Parse.argtypes = [C.c_void_p, P, C.c_int, C.c_int]
    lib.XML_ParserFree.argtypes = [C.c_void_p]
    lib.XML_SetAttlistDeclHandler.argtypes = [C.c_void_p, ATTLIST]
    out = []
    h = ATTLIST(lambda u, el, at, ty, dflt, req: out.append(
        f"{el.decode()} {at.decode()} {ty.decode()} default={'NULL' if dflt is None else repr(dflt.decode())} isrequired={req}"))
    p = lib.XML_ParserCreate(None)
    lib.XML_SetAttlistDeclHandler(p, h)
    status = lib.XML_Parse(p, doc, len(doc), 1)
    lib.XML_ParserFree(p)
    return out, status


def main():
    same = 0
    for name, doc in DOCS:
        x, e = run(sys.argv[1], doc), run(sys.argv[2], doc)
        same += x == e
        print(f"{'=' if x == e else 'X'} {name}\n     xpact {x}\n     expat {e}")
    print(f"same as Expat: {same} / {len(DOCS)}")


if __name__ == "__main__":
    main()
