"""External parameter entity included in an entity literal, through the Expat C API of xpact.dll.

Usage: python -I reports/issue-0159/literal_probe.py <path to xpact.dll>

Replays the smoke test's external_value_cases (tests/native/xpact_eiffel_dll_smoke.c): the
document's external DTD declares  <!ENTITY % e1 SYSTEM '004-2.ent'>  <!ENTITY % e2 '%e1;'>  %e1;
and 004-2.ent holds the case text. For each case it prints the error code of every child parse
and the document status, plus the entity value Expat would store for W3C valid-not-sa-031.
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
lib.XML_ExternalEntityParserCreate.restype = P
lib.XML_ExternalEntityParserCreate.argtypes = [P, C.c_char_p, C.c_char_p]
lib.XML_Parse.argtypes = [P, C.c_char_p, C.c_int, C.c_int]
lib.XML_GetErrorCode.argtypes = [P]
lib.XML_ParserFree.argtypes = [P]
lib.XML_SetParamEntityParsing.argtypes = [P, C.c_int]
EXT = C.CFUNCTYPE(C.c_int, P, C.c_char_p, C.c_char_p, C.c_char_p, C.c_char_p)
lib.XML_SetExternalEntityRefHandler.argtypes = [P, EXT]
ENT = C.CFUNCTYPE(None, P, C.c_char_p, C.c_int, C.c_char_p, C.c_int, C.c_char_p, C.c_char_p, C.c_char_p, C.c_char_p)
lib.XML_SetEntityDeclHandler.argtypes = [P, ENT]

OUTER = (b"<!ELEMENT doc EMPTY>\n<!ENTITY % e1 SYSTEM '004-2.ent'>\n"
         b"<!ENTITY % e2 '%e1;'>\n%e1;\n")
DOC = b"<!DOCTYPE doc SYSTEM '004-1.ent'>\n<doc></doc>\n"
CASES = [  # (text, Expat's expected child error)
    (b"<!ATTLIST doc a1 CDATA 'value'>", 0),
    (b"<!ATTLIST $doc a1 CDATA 'value'>", 4),
    (b"'wombat", 5),
    (b"\xE2\x82", 6),
    (b"<?xml version='1.0' encoding='utf-8'?>\n", 0),
    (b"<?xml?>", 30),
    (b"\xEF\xBB\xBF<!ATTLIST doc a1 CDATA 'value'>", 0),
    (b"<?xml version='1.0' encoding='utf-8'?>\n$", 4),
    (b"<?xml version='1.0' encoding='utf-8'?>\n'wombat", 5),
    (b"<?xml version='1.0' encoding='utf-8'?>\n\xE2\x82", 6),
    (b"%e1;", 12),
]


def run(text):
    codes, values = [], []

    @EXT
    def handler(parser, context, base, system_id, public_id):
        if system_id is None:
            return 1
        child = lib.XML_ExternalEntityParserCreate(parser, context, None)
        data = OUTER if system_id == b"004-1.ent" else text
        lib.XML_SetEntityDeclHandler(child, on_entity)
        ok = lib.XML_Parse(child, data, len(data), 1)
        codes.append((system_id.decode(), 0 if ok == 1 else lib.XML_GetErrorCode(child)))
        lib.XML_ParserFree(child)
        return 1  # like the smoke handler when the child's result is the expected one

    @ENT
    def on_entity(_, name, is_pe, value, length, base, system_id, public_id, notation):
        if value is not None:
            values.append((name.decode(), C.string_at(value, length)))

    p = lib.XML_ParserCreate(b"UTF-8")
    lib.XML_SetParamEntityParsing(p, 2)
    lib.XML_SetExternalEntityRefHandler(p, handler)
    status = lib.XML_Parse(p, DOC, len(DOC), 1)
    error = lib.XML_GetErrorCode(p)
    lib.XML_ParserFree(p)
    return status, error, codes, values


bad = 0
for index, (text, expected) in enumerate(CASES):
    status, error, codes, values = run(text)
    literal = [c for s, c in codes if s == "004-2.ent"][:1]
    ok = status == 1 and literal == [expected]
    bad += not ok
    print(f"{'OK  ' if ok else 'DIFF'} case {index:2} {text!r}: doc status={status} err={error}; "
          f"child errors={codes}; expected literal child error={expected}; e2 value={values}")
print(f"{len(CASES) - bad} of {len(CASES)} cases as the smoke test expects")
