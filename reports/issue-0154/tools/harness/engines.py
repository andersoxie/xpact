"""One XML document through xpact (xpact.dll, Expat C API via ctypes) or Expat (pyexpat).

Both engines record the same event list, so results can be compared directly.
External entities are loaded the way xmlwf -p and tests/native/xpact_w3c_case.c
do it: relative system identifiers below `entity_root` only, parsed with
XML_ExternalEntityParserCreate.

Result: {"verdict": "ACCEPT"|"REJECT", "error": code, "message": str,
         "line": int, "column": int, "events": [...]}
Events are lists: ["start", name, [k, v, ...]], ["end", name], ["chars", text], ...
Consecutive "chars" events are merged (Expat splits text arbitrarily).
"""
from __future__ import annotations

import ctypes as C
import os
from pathlib import Path

DEFAULT_DLL = Path(__file__).resolve().parents[4] / "build" / "native-eiffel" / "xpact.dll"
PE_ALWAYS = 2


def _d(b):
    return None if b is None else b.decode("utf-8", "surrogateescape")


class Recorder:
    """Event list; text pieces are collected in a list and joined once (no quadratic string growth)."""

    def __init__(self):
        self._events = []

    def add(self, *event):
        if event[0] == "chars" and self._events and self._events[-1][0] == "chars":
            self._events[-1][1].append(event[1])
        elif event[0] == "chars":
            self._events.append(["chars", [event[1]]])
        else:
            self._events.append(list(event))

    @property
    def events(self):
        return [["chars", "".join(e[1])] if e[0] == "chars" else e for e in self._events]


def resolve(entity_root, base, system_id):
    """Local path for system_id relative to base, or None (outside root / absolute / URL)."""
    if entity_root is None or not system_id or system_id.startswith(("/", "\\")) or ":" in system_id or "#" in system_id:
        return None
    base_dir = Path(base).parent if base else Path(entity_root)
    target = (base_dir / system_id).resolve()
    root = Path(entity_root).resolve()
    if not str(target).lower().startswith(str(root).lower()):
        return None
    return target if target.is_file() else None


def chunks(data: bytes, split):
    if split is None:
        return [data]
    if split == "byte":
        return [data[i:i + 1] for i in range(len(data))]
    if isinstance(split, str) and split.startswith("every:"):
        n = int(split[6:])
        return [data[i:i + n] for i in range(0, len(data), n)] or [b""]
    k = int(split)
    return [data[:k], data[k:]]


# ---------------------------------------------------------------- Expat (pyexpat)

def parse_expat(data: bytes, *, path=None, entity_root=None, namespaces=False, split=None, encoding=None,
                external=True, bare=False):
    import pyexpat as E
    rec = Recorder()

    def configure(p, base, is_root):
        p.buffer_text = False
        p.ordered_attributes = True
        if base:
            p.SetBase(base)
        p.StartElementHandler = lambda n, a: rec.add("start", n, list(a))
        p.EndElementHandler = lambda n: rec.add("end", n)
        p.CharacterDataHandler = lambda s: rec.add("chars", s)
        p.ProcessingInstructionHandler = lambda t, d: rec.add("pi", t, d)
        p.CommentHandler = lambda d: rec.add("comment", d)
        p.StartCdataSectionHandler = lambda: rec.add("startcdata")
        p.EndCdataSectionHandler = lambda: rec.add("endcdata")
        p.XmlDeclHandler = lambda v, e, s: rec.add("xmldecl", v, e, s)
        p.StartDoctypeDeclHandler = lambda n, s, pu, h: rec.add("startdoctype", n, s, pu, int(bool(h)))
        p.EndDoctypeDeclHandler = lambda: rec.add("enddoctype")
        p.EntityDeclHandler = lambda n, pe, v, b, s, pu, no: rec.add("entitydecl", n, int(bool(pe)), v, s, pu, no)
        p.NotationDeclHandler = lambda n, b, s, pu: rec.add("notationdecl", n, s, pu)
        p.AttlistDeclHandler = lambda el, at, ty, df, rq: rec.add("attlistdecl", el, at, ty, df, int(bool(rq)))
        p.ElementDeclHandler = lambda n, m: rec.add("elementdecl", n, _model_py(m))
        p.SkippedEntityHandler = lambda n, pe: rec.add("skipped", n, int(bool(pe)))
        if namespaces:
            p.StartNamespaceDeclHandler = lambda pr, u: rec.add("startns", pr, u)
            p.EndNamespaceDeclHandler = lambda pr: rec.add("endns", pr)
        p.SetParamEntityParsing(PE_ALWAYS)

        def load_external(context, base_, system_id, public_id):
            target = resolve(entity_root, base_, system_id)
            if target is None:
                return 0
            child = p.ExternalEntityParserCreate(context)
            configure(child, str(target), False)
            try:
                child.Parse(target.read_bytes(), True)
            except E.ExpatError:
                return 0
            return 1

        if external:
            p.ExternalEntityRefHandler = load_external

    parser = E.ParserCreate(encoding, "|") if namespaces else E.ParserCreate(encoding)
    if not bare:  # bare: no handlers at all, to time the parser alone
        configure(parser, str(path) if path else None, True)
    try:
        parts = chunks(data, split)
        for part in parts[:-1]:
            parser.Parse(part, False)
        parser.Parse(parts[-1] if parts else b"", True)
        return {"verdict": "ACCEPT", "error": 0, "message": "", "line": 0, "column": 0, "events": rec.events}
    except E.ExpatError as exc:
        return {"verdict": "REJECT", "error": exc.code, "message": E.ErrorString(exc.code),
                "line": exc.lineno, "column": exc.offset, "events": rec.events}


def _model_py(m):
    t, q, name, children = m
    return [t, q, name, [_model_py(c) for c in children]]


# ---------------------------------------------------------------- xpact (ctypes)

class XML_cp(C.Structure):
    pass


XML_cp._fields_ = [("type", C.c_int), ("quant", C.c_int), ("name", C.c_char_p),
                   ("numchildren", C.c_uint), ("children", C.POINTER(XML_cp))]

P = C.c_void_p
S = C.c_char_p
CB = C.CFUNCTYPE
StartH = CB(None, P, S, C.POINTER(S))
EndH = CB(None, P, S)
CharH = CB(None, P, P, C.c_int)
PIH = CB(None, P, S, S)
OneH = CB(None, P, S)
VoidH = CB(None, P)
XmlDeclH = CB(None, P, S, S, C.c_int)
DoctypeH = CB(None, P, S, S, S, C.c_int)
EntityH = CB(None, P, S, C.c_int, P, C.c_int, S, S, S, S)
NotationH = CB(None, P, S, S, S, S)
AttlistH = CB(None, P, S, S, S, S, C.c_int)
ElemDeclH = CB(None, P, S, C.POINTER(XML_cp))
SkippedH = CB(None, P, S, C.c_int)
NsStartH = CB(None, P, S, S)
ExtH = CB(C.c_int, P, S, S, S, S)

_lib = None


def load(dll=None):
    global _lib
    if _lib is None:
        dll = Path(dll or os.environ.get("XPACT_DLL") or DEFAULT_DLL)
        os.add_dll_directory(str(dll.parent))
        lib = C.CDLL(str(dll))
        for name, res, args in [
            ("XML_ParserCreate", P, [S]), ("XML_ParserCreateNS", P, [S, C.c_char]),
            ("XML_ParserFree", None, [P]), ("XML_SetBase", C.c_int, [P, S]),
            ("XML_Parse", C.c_int, [P, P, C.c_int, C.c_int]),
            ("XML_GetErrorCode", C.c_int, [P]), ("XML_ErrorString", S, [C.c_int]),
            ("XML_GetCurrentLineNumber", C.c_ulong, [P]), ("XML_GetCurrentColumnNumber", C.c_ulong, [P]),
            ("XML_SetParamEntityParsing", C.c_int, [P, C.c_int]),
            ("XML_ExternalEntityParserCreate", P, [P, S, S]),
            ("XML_FreeContentModel", None, [P, C.POINTER(XML_cp)]),
            ("XML_SetBillionLaughsAttackProtectionMaximumAmplification", C.c_ubyte, [P, C.c_float]),
            ("XML_SetBillionLaughsAttackProtectionActivationThreshold", C.c_ubyte, [P, C.c_ulonglong]),
        ]:
            f = getattr(lib, name)
            f.restype, f.argtypes = res, args
        for name, typ in [("XML_SetStartElementHandler", StartH), ("XML_SetEndElementHandler", EndH),
                          ("XML_SetCharacterDataHandler", CharH), ("XML_SetProcessingInstructionHandler", PIH),
                          ("XML_SetCommentHandler", OneH), ("XML_SetStartCdataSectionHandler", VoidH),
                          ("XML_SetEndCdataSectionHandler", VoidH), ("XML_SetXmlDeclHandler", XmlDeclH),
                          ("XML_SetStartDoctypeDeclHandler", DoctypeH), ("XML_SetEndDoctypeDeclHandler", VoidH),
                          ("XML_SetEntityDeclHandler", EntityH), ("XML_SetNotationDeclHandler", NotationH),
                          ("XML_SetAttlistDeclHandler", AttlistH), ("XML_SetElementDeclHandler", ElemDeclH),
                          ("XML_SetSkippedEntityHandler", SkippedH), ("XML_SetStartNamespaceDeclHandler", NsStartH),
                          ("XML_SetEndNamespaceDeclHandler", OneH), ("XML_SetExternalEntityRefHandler", ExtH)]:
            f = getattr(lib, name)
            f.restype, f.argtypes = None, [P, typ]
        _lib = lib
    return _lib


def _model_c(cp):
    kids = [_model_c(cp.children[i]) for i in range(cp.numchildren)]
    return [cp.type, cp.quant, _d(cp.name), kids]


def parse_xpact(data: bytes, *, path=None, entity_root=None, namespaces=False, split=None, encoding=None,
                amplification=None, dll=None, external=True, bare=False):
    lib = load(dll)
    rec = Recorder()
    keep = []  # callbacks must outlive the parse

    def configure(p, base, is_root):
        def h(setter, typ, fn):
            cb = typ(fn)
            keep.append(cb)
            getattr(lib, setter)(p, cb)

        if base:
            lib.XML_SetBase(p, base.encode("utf-8"))

        def start(_, name, atts):
            pairs, i = [], 0
            while atts[i] is not None:
                pairs.append(_d(atts[i]))
                i += 1
            rec.add("start", _d(name), pairs)

        h("XML_SetStartElementHandler", StartH, start)
        h("XML_SetEndElementHandler", EndH, lambda _, n: rec.add("end", _d(n)))
        h("XML_SetCharacterDataHandler", CharH, lambda _, s, n: rec.add("chars", _d(C.string_at(s, n))))
        h("XML_SetProcessingInstructionHandler", PIH, lambda _, t, d: rec.add("pi", _d(t), _d(d)))
        h("XML_SetCommentHandler", OneH, lambda _, d: rec.add("comment", _d(d)))
        h("XML_SetStartCdataSectionHandler", VoidH, lambda _: rec.add("startcdata"))
        h("XML_SetEndCdataSectionHandler", VoidH, lambda _: rec.add("endcdata"))
        h("XML_SetXmlDeclHandler", XmlDeclH, lambda _, v, e, s: rec.add("xmldecl", _d(v), _d(e), s))
        h("XML_SetStartDoctypeDeclHandler", DoctypeH,
          lambda _, n, s, pu, hi: rec.add("startdoctype", _d(n), _d(s), _d(pu), int(bool(hi))))
        h("XML_SetEndDoctypeDeclHandler", VoidH, lambda _: rec.add("enddoctype"))
        h("XML_SetEntityDeclHandler", EntityH,
          lambda _, n, pe, v, vl, b, s, pu, no: rec.add("entitydecl", _d(n), int(bool(pe)),
                                                       _d(C.string_at(v, vl)) if v else None, _d(s), _d(pu), _d(no)))
        h("XML_SetNotationDeclHandler", NotationH, lambda _, n, b, s, pu: rec.add("notationdecl", _d(n), _d(s), _d(pu)))
        h("XML_SetAttlistDeclHandler", AttlistH,
          lambda _, el, at, ty, df, rq: rec.add("attlistdecl", _d(el), _d(at), _d(ty), _d(df), int(bool(rq))))

        def eldecl(_, name, model):
            rec.add("elementdecl", _d(name), _model_c(model.contents))
            lib.XML_FreeContentModel(p, model)

        h("XML_SetElementDeclHandler", ElemDeclH, eldecl)
        h("XML_SetSkippedEntityHandler", SkippedH, lambda _, n, pe: rec.add("skipped", _d(n), int(bool(pe))))
        if namespaces:
            h("XML_SetStartNamespaceDeclHandler", NsStartH, lambda _, pr, u: rec.add("startns", _d(pr), _d(u)))
            h("XML_SetEndNamespaceDeclHandler", OneH, lambda _, pr: rec.add("endns", _d(pr)))
        lib.XML_SetParamEntityParsing(p, PE_ALWAYS)

        def load_external(parser, context, base_, system_id, public_id):
            target = resolve(entity_root, _d(base_), _d(system_id))
            if target is None:
                return 0
            child = lib.XML_ExternalEntityParserCreate(parser, context, None)
            if not child:
                return 0
            configure(child, str(target), False)
            body = target.read_bytes()
            ok = lib.XML_Parse(child, body, len(body), 1)
            lib.XML_ParserFree(child)
            return 1 if ok == 1 else 0

        if external:
            h("XML_SetExternalEntityRefHandler", ExtH, load_external)

    enc = encoding.encode() if encoding else None
    parser = lib.XML_ParserCreateNS(enc, b"|") if namespaces else lib.XML_ParserCreate(enc)
    if amplification is not None:
        lib.XML_SetBillionLaughsAttackProtectionMaximumAmplification(parser, amplification)
    if not bare:  # bare: no handlers at all, to time the parser alone
        configure(parser, str(path) if path else None, True)
    ok = 1
    parts = chunks(data, split) or [b""]
    for i, part in enumerate(parts):
        ok = lib.XML_Parse(parser, part, len(part), 1 if i == len(parts) - 1 else 0)
        if ok != 1:
            break
    if ok == 1:
        result = {"verdict": "ACCEPT", "error": 0, "message": "", "line": 0, "column": 0}
    else:
        code = lib.XML_GetErrorCode(parser)
        result = {"verdict": "REJECT", "error": code, "message": _d(lib.XML_ErrorString(code)),
                  "line": lib.XML_GetCurrentLineNumber(parser), "column": lib.XML_GetCurrentColumnNumber(parser)}
    lib.XML_ParserFree(parser)
    result["events"] = rec.events
    return result


def parse(engine, data, **kw):
    return (parse_xpact if engine == "xpact" else parse_expat)(data, **kw)
