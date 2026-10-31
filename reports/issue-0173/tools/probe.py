"""#173 probe: declarations delivered before an error inside the internal subset.

    python -I reports/issue-0173/tools/probe.py <xpact dll> <libexpat dll> <ibm51n06.xml>

Records entity declarations, comments and the DOCTYPE start, then the error code,
line and column, for the whole document and byte by byte.
"""
import ctypes as C
import sys

P = C.c_char_p
ENTITY = C.CFUNCTYPE(None, C.c_void_p, P, C.c_int, C.POINTER(C.c_char), C.c_int, P, P, P, P)
COMMENT = C.CFUNCTYPE(None, C.c_void_p, P)
DOCTYPE = C.CFUNCTYPE(None, C.c_void_p, P, P, P, C.c_int)
END_DOCTYPE = C.CFUNCTYPE(None, C.c_void_p)


def run(dll, parts):
    lib = C.CDLL(dll)
    lib.XML_ParserCreate.restype = C.c_void_p
    lib.XML_ParserCreate.argtypes = [P]
    lib.XML_Parse.argtypes = [C.c_void_p, P, C.c_int, C.c_int]
    for f in ("XML_GetErrorCode", "XML_GetCurrentLineNumber", "XML_GetCurrentColumnNumber", "XML_ParserFree"):
        getattr(lib, f).argtypes = [C.c_void_p]
    lib.XML_GetCurrentLineNumber.restype = C.c_ulong
    lib.XML_GetCurrentColumnNumber.restype = C.c_ulong
    lib.XML_SetEntityDeclHandler.argtypes = [C.c_void_p, ENTITY]
    lib.XML_SetCommentHandler.argtypes = [C.c_void_p, COMMENT]
    lib.XML_SetDoctypeDeclHandler.argtypes = [C.c_void_p, DOCTYPE, END_DOCTYPE]
    out = []
    e = ENTITY(lambda u, n, par, v, vl, b, s, pub, no: out.append("entity " + n.decode()))
    c = COMMENT(lambda u, d: out.append("comment " + d.decode().strip()))
    d = DOCTYPE(lambda u, n, s, pub, i: out.append("doctype " + n.decode()))
    ed = END_DOCTYPE(lambda u: out.append("enddoctype"))
    p = lib.XML_ParserCreate(None)
    lib.XML_SetEntityDeclHandler(p, e)
    lib.XML_SetCommentHandler(p, c)
    lib.XML_SetDoctypeDeclHandler(p, d, ed)
    status = 1
    for i, part in enumerate(parts):
        status = lib.XML_Parse(p, part, len(part), int(i == len(parts) - 1))
        if not status:
            break
    err = (lib.XML_GetErrorCode(p), lib.XML_GetCurrentLineNumber(p), lib.XML_GetCurrentColumnNumber(p))
    lib.XML_ParserFree(p)
    return out, err


def main():
    xpact, expat, w3c = sys.argv[1], sys.argv[2], sys.argv[3]
    docs = [
        ("ibm51n06.xml", open(w3c, "rb").read()),
        ("stray ] inside an element declaration", b"<!DOCTYPE r [<!ENTITY a 'x'><!-- c --><!ELEMENT e (#PCDATA | a ]* >]><r/>"),
        ("] then junk", b"<!DOCTYPE r [<!ENTITY a 'x'><!-- c -->] junk ]><r/>"),
        ("] then a name", b"<!DOCTYPE r [<!ENTITY a 'x'>]x><r/>"),
        ("valid (control)", b"<!DOCTYPE r [<!ENTITY a 'x'><!-- c -->]><r/>"),
    ]
    total = same = 0
    for name, doc in docs:
        for mode, parts in (("whole", [doc]), ("bytes", [doc[i:i + 1] for i in range(len(doc))])):
            x, e = run(xpact, parts), run(expat, parts)
            total += 1
            same += x == e
            print(f"{'=' if x == e else 'X'} {name} {mode}\n     xpact {x}\n     expat {e}")
    print(f"same as Expat: {same} / {total}")


if __name__ == "__main__":
    main()
