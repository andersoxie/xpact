"""Events delivered by each XML_Parse call when a small document arrives in pieces.

Usage: python -I reports/issue-0165/chunk_probe.py <path to xpact.dll>
Each callback must arrive exactly once, whatever the pieces (#165).
"""
import ctypes as C
import os
import sys
from pathlib import Path

dll = Path(sys.argv[1]).resolve()
os.add_dll_directory(str(dll.parent))
lib = C.CDLL(str(dll))
P = C.c_void_p
lib.XML_ParserCreate.restype = P
lib.XML_ParserCreate.argtypes = [C.c_char_p]
lib.XML_Parse.argtypes = [P, C.c_char_p, C.c_int, C.c_int]
lib.XML_ParserFree.argtypes = [P]
events = []
XD = C.CFUNCTYPE(None, P, C.c_char_p, C.c_char_p, C.c_int)
SD = C.CFUNCTYPE(None, P, C.c_char_p, C.c_char_p, C.c_char_p, C.c_int)
ED = C.CFUNCTYPE(None, P)
EN = C.CFUNCTYPE(None, P, C.c_char_p, C.c_int, C.c_char_p, C.c_int, C.c_char_p, C.c_char_p, C.c_char_p, C.c_char_p)
SE = C.CFUNCTYPE(None, P, C.c_char_p, C.POINTER(C.c_char_p))
EE = C.CFUNCTYPE(None, P, C.c_char_p)
handlers = (XD(lambda u, v, e, s: events.append("xmldecl")),
            SD(lambda u, n, s, p, h: events.append("startdoctype")),
            ED(lambda u: events.append("enddoctype")),
            EN(lambda u, n, pe, v, l, b, s, p, no: events.append("entitydecl")),
            SE(lambda u, n, a: events.append("start")),
            EE(lambda u, n: events.append("end")))
lib.XML_SetXmlDeclHandler.argtypes = [P, XD]
lib.XML_SetDoctypeDeclHandler.argtypes = [P, SD, ED]
lib.XML_SetEntityDeclHandler.argtypes = [P, EN]
lib.XML_SetElementHandler.argtypes = [P, SE, EE]

DOC = b'<?xml version="1.0"?><!DOCTYPE d [<!ENTITY e "v">]><d/>'
CASES = {
    "whole": [DOC],
    "4 pieces (smallest pattern)": [b'<?xml version="1.0"?', b'><!DOCTYPE d [<!ENTITY e "v">', b']', b'><d/>'],
    "byte by byte": [DOC[i:i + 1] for i in range(len(DOC))],
}
EXPECTED = ["xmldecl", "startdoctype", "entitydecl", "enddoctype", "start", "end"]
bad = 0
for name, pieces in CASES.items():
    p = lib.XML_ParserCreate(b"UTF-8")
    lib.XML_SetXmlDeclHandler(p, handlers[0])
    lib.XML_SetDoctypeDeclHandler(p, handlers[1], handlers[2])
    lib.XML_SetEntityDeclHandler(p, handlers[3])
    lib.XML_SetElementHandler(p, handlers[4], handlers[5])
    per_call, total = [], []
    for i, piece in enumerate(pieces):
        events.clear()
        lib.XML_Parse(p, piece, len(piece), int(i == len(pieces) - 1))
        per_call.append(list(events))
        total += events
    lib.XML_ParserFree(p)
    ok = total == EXPECTED
    bad += not ok
    print(f"{'OK  ' if ok else 'DIFF'} {name}: {total}")
    if len(pieces) <= 4:
        for i, e in enumerate(per_call, 1):
            print(f"       call {i}: {e}")
print(f"{len(CASES) - bad} of {len(CASES)} as expected")
