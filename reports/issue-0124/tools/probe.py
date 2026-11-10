"""#124 probe: error code and position for text outside the document element.

    python -I reports/issue-0124/tools/probe.py <xpact dll> <libexpat dll>

Every document runs whole and byte by byte, without and with element callbacks.
Prints (error code, column, byte index) per DLL and counts the rows equal to Expat.
"""
import ctypes as C
import sys

START = C.CFUNCTYPE(None, C.c_void_p, C.c_char_p, C.POINTER(C.c_char_p))
END = C.CFUNCTYPE(None, C.c_void_p, C.c_char_p)

AFTER_ROOT = [b"<root/>junk", b"<root/> junk", b"<root></root>x", b"<root/><!-- c -->junk", b"<root/>]]>", b"<root/> a]]>"]
BEFORE_ROOT = [b"junk<root/>", b" junk<root/>", b"<?xml version='1.0'?>x<r/>", b"<!DOCTYPE r []>x<r/>"]
OTHER = [b"<a/><b/>", b"<root/>&amp;", b"<r>]]></r>"]


def run(dll, parts, callbacks):
    lib = C.CDLL(dll)
    lib.XML_ParserCreate.restype = C.c_void_p
    lib.XML_ParserCreate.argtypes = [C.c_char_p]
    lib.XML_Parse.argtypes = [C.c_void_p, C.c_char_p, C.c_int, C.c_int]
    for f in ("XML_GetErrorCode", "XML_GetCurrentColumnNumber", "XML_GetCurrentByteIndex", "XML_ParserFree"):
        getattr(lib, f).argtypes = [C.c_void_p]
    lib.XML_GetCurrentColumnNumber.restype = C.c_ulong
    lib.XML_GetCurrentByteIndex.restype = C.c_long
    lib.XML_SetElementHandler.argtypes = [C.c_void_p, START, END]
    s, e = START(lambda u, n, a: None), END(lambda u, n: None)
    p = lib.XML_ParserCreate(None)
    if callbacks:
        lib.XML_SetElementHandler(p, s, e)
    status = 1
    for i, part in enumerate(parts):
        status = lib.XML_Parse(p, part, len(part), int(i == len(parts) - 1))
        if not status:
            break
    result = (lib.XML_GetErrorCode(p), lib.XML_GetCurrentColumnNumber(p), lib.XML_GetCurrentByteIndex(p))
    lib.XML_ParserFree(p)
    return result


def main():
    xpact, expat = sys.argv[1], sys.argv[2]
    total = same = 0
    for group, docs in (("after the root", AFTER_ROOT), ("before the root", BEFORE_ROOT), ("other", OTHER)):
        print(f"== {group}")
        for doc in docs:
            for callbacks in (False, True):
                for mode, parts in (("whole", [doc]), ("bytes", [doc[i:i + 1] for i in range(len(doc))])):
                    x, e = run(xpact, parts, callbacks), run(expat, parts, callbacks)
                    total += 1
                    same += x == e
                    cb = "callbacks" if callbacks else "none"
                    print(f"  {'=' if x == e else 'X'} {doc!r:32} {cb:9} {mode:5} xpact {x} expat {e}")
    print(f"same as Expat: {same} / {total}")


if __name__ == "__main__":
    main()
