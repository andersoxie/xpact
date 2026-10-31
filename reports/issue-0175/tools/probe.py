"""#175 probe: is an empty system literal passed as "" (Expat) or as NULL?

    python -I reports/issue-0175/tools/probe.py <xpact dll> <libexpat dll>

Prints the systemId (and publicId) each declaration handler receives, per DLL.
"""
import ctypes as C
import sys

P = C.c_char_p
ENTITY = C.CFUNCTYPE(None, C.c_void_p, P, C.c_int, C.POINTER(C.c_char), C.c_int, P, P, P, P)
NOTATION = C.CFUNCTYPE(None, C.c_void_p, P, P, P, P)
DOCTYPE = C.CFUNCTYPE(None, C.c_void_p, P, P, P, C.c_int)
END_DOCTYPE = C.CFUNCTYPE(None, C.c_void_p)

DOCS = [
    ("general entity SYSTEM ''", b"<!DOCTYPE d [<!ENTITY e SYSTEM ''>]><d/>"),
    ("general entity PUBLIC 'p' ''", b"<!DOCTYPE d [<!ENTITY e PUBLIC 'p' ''>]><d/>"),
    ("parameter entity SYSTEM ''", b"<!DOCTYPE d [<!ENTITY % e SYSTEM ''>]><d/>"),
    ("unparsed entity SYSTEM '' NDATA", b"<!DOCTYPE d [<!NOTATION n SYSTEM 'x'><!ENTITY e SYSTEM '' NDATA n>]><d/>"),
    ("general entity SYSTEM 'x' (control)", b"<!DOCTYPE d [<!ENTITY e SYSTEM 'x'>]><d/>"),
    ("NOTATION SYSTEM ''", b"<!DOCTYPE d [<!NOTATION n SYSTEM ''>]><d/>"),
    ("DOCTYPE SYSTEM ''", b"<!DOCTYPE d SYSTEM ''><d/>"),
]


def show(p):
    return "NULL" if p is None else repr(p.decode())


def run(dll, doc):
    lib = C.CDLL(dll)
    lib.XML_ParserCreate.restype = C.c_void_p
    lib.XML_ParserCreate.argtypes = [P]
    lib.XML_Parse.argtypes = [C.c_void_p, P, C.c_int, C.c_int]
    lib.XML_ParserFree.argtypes = [C.c_void_p]
    lib.XML_GetErrorCode.argtypes = [C.c_void_p]
    lib.XML_SetEntityDeclHandler.argtypes = [C.c_void_p, ENTITY]
    lib.XML_SetNotationDeclHandler.argtypes = [C.c_void_p, NOTATION]
    lib.XML_SetDoctypeDeclHandler.argtypes = [C.c_void_p, DOCTYPE, END_DOCTYPE]
    out = []
    e = ENTITY(lambda u, n, par, v, vl, b, s, pub, no: out.append(
        f"entity {n.decode()} param={par} value={'NULL' if not v else 'set'} system={show(s)} public={show(pub)} notation={show(no)}"))
    nt = NOTATION(lambda u, n, b, s, pub: out.append(f"notation {n.decode()} system={show(s)} public={show(pub)}"))
    dt = DOCTYPE(lambda u, n, s, pub, i: out.append(f"doctype {n.decode()} system={show(s)} public={show(pub)}"))
    edt = END_DOCTYPE(lambda u: None)
    p = lib.XML_ParserCreate(None)
    lib.XML_SetEntityDeclHandler(p, e)
    lib.XML_SetNotationDeclHandler(p, nt)
    lib.XML_SetDoctypeDeclHandler(p, dt, edt)
    status = lib.XML_Parse(p, doc, len(doc), 1)
    err = lib.XML_GetErrorCode(p)
    lib.XML_ParserFree(p)
    return out, status, err


def main():
    xpact, expat = sys.argv[1], sys.argv[2]
    same = 0
    for name, doc in DOCS:
        rx, re_ = run(xpact, doc), run(expat, doc)
        ok = rx == re_
        same += ok
        print(f"{'=' if ok else 'X'} {name}")
        print(f"     xpact {rx}")
        print(f"     expat {re_}")
    print(f"same as Expat: {same} / {len(DOCS)}")


if __name__ == "__main__":
    main()
