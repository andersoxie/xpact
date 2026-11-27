"""Compare public UTF-8 namespace traces from two Windows x64 Expat-compatible DLLs.

Usage: python compare_scopes.py --reference PATH/TO/libexpat.dll --dll PATH/TO/xpact.dll
Use the pre-change xpact DLL as the reference to check for a change in previous behavior.
"""

import argparse
import ctypes as C
import json
from collections import Counter
from itertools import product
from pathlib import Path
from xml.etree import ElementTree


POINTER = C.c_void_p
STRING = C.c_char_p
START = C.CFUNCTYPE(None, POINTER, STRING, C.POINTER(STRING))
END = C.CFUNCTYPE(None, POINTER, STRING)
DECLARE = C.CFUNCTYPE(None, POINTER, STRING, STRING)
EXTERNAL = C.CFUNCTYPE(C.c_int, POINTER, STRING, STRING, STRING, STRING)


def load_dll(path):
    dll = C.CDLL(str(Path(path).resolve(strict=True)))
    declarations = {
        "XML_ParserCreateNS": (POINTER, [STRING, C.c_char]),
        "XML_ParserFree": (None, [POINTER]),
        "XML_ParserReset": (C.c_ubyte, [POINTER, STRING]),
        "XML_SetElementHandler": (None, [POINTER, START, END]),
        "XML_SetNamespaceDeclHandler": (None, [POINTER, DECLARE, END]),
        "XML_SetExternalEntityRefHandler": (None, [POINTER, EXTERNAL]),
        "XML_SetReturnNSTriplet": (None, [POINTER, C.c_int]),
        "XML_SetReparseDeferralEnabled": (C.c_ubyte, [POINTER, C.c_ubyte]),
        "XML_Parse": (C.c_int, [POINTER, STRING, C.c_int, C.c_int]),
        "XML_GetBuffer": (POINTER, [POINTER, C.c_int]),
        "XML_ParseBuffer": (C.c_int, [POINTER, C.c_int, C.c_int]),
        "XML_GetErrorCode": (C.c_int, [POINTER]),
        "XML_GetCurrentByteIndex": (C.c_long, [POINTER]),
        "XML_GetCurrentLineNumber": (C.c_ulong, [POINTER]),
        "XML_GetCurrentColumnNumber": (C.c_ulong, [POINTER]),
        "XML_StopParser": (C.c_int, [POINTER, C.c_ubyte]),
        "XML_ResumeParser": (C.c_int, [POINTER]),
        "XML_ExternalEntityParserCreate": (POINTER, [POINTER, STRING, STRING]),
    }
    for name, (result, arguments) in declarations.items():
        function = getattr(dll, name)
        function.restype = result
        function.argtypes = arguments
    return dll


def decode(value):
    return value.decode("utf-8") if value is not None else None


def trace_document(dll, document, *, triplets, chunk_size, deferral, buffered,
                   handlers="all", pause=None, case_name="ordinary"):
    """Collect the ordered callbacks, source positions and parser lifecycle results."""
    parser = dll.XML_ParserCreateNS(None, b"|")
    if not parser:
        raise MemoryError("XML_ParserCreateNS")
    active = parser
    events = []
    lifecycle = []
    stopped = False

    def position():
        return [dll.XML_GetCurrentByteIndex(active), dll.XML_GetCurrentLineNumber(active),
                dll.XML_GetCurrentColumnNumber(active)]

    def stop():
        nonlocal stopped
        if not stopped:
            stopped = True
            lifecycle.append(["stop", dll.XML_StopParser(active, True)])

    @START
    def start(_, name, attributes):
        pairs = []
        index = 0
        while attributes[index]:
            pairs.append([decode(attributes[index]), decode(attributes[index + 1])])
            index += 2
        events.append(["start", decode(name), pairs, position()])
        if case_name == "suspend" and name == b"s":
            stop()

    @END
    def end(_, name):
        events.append(["end", decode(name), position()])
        if pause == "end" and b"inner" in name:
            stop()

    @DECLARE
    def bind(_, prefix, uri):
        events.append(["bind", decode(prefix), decode(uri), position()])
        if pause == "bind" and uri == b"inner":
            stop()

    @END
    def unbind(_, prefix):
        events.append(["unbind", decode(prefix), position()])
        if pause == "unbind" and prefix == b"q":
            stop()

    @EXTERNAL
    def external(parent, context, base, system_id, public_id):
        nonlocal active
        events.append(["external", decode(system_id), position()])
        child = dll.XML_ExternalEntityParserCreate(parent, context, None)
        if not child:
            return 0
        active = child
        try:
            data = b'<p:child><s xmlns:p="child"><p:leaf/></s><p:after/></p:child>'
            status = dll.XML_Parse(child, data, len(data), True)
            lifecycle.append(["child", status, dll.XML_GetErrorCode(child)])
            return status
        finally:
            active = parent
            dll.XML_ParserFree(child)

    def configure():
        dll.XML_SetElementHandler(parser, start if handlers in ("all", "start") else START(),
                                  end if handlers in ("all", "end") else END())
        want_namespaces = handlers in ("all", "ns")
        dll.XML_SetNamespaceDeclHandler(parser, bind if want_namespaces else DECLARE(),
                                        unbind if want_namespaces else END())
        dll.XML_SetExternalEntityRefHandler(parser, external)
        dll.XML_SetReturnNSTriplet(parser, triplets)
        dll.XML_SetReparseDeferralEnabled(parser, deferral)

    def feed(data, final=True):
        step = chunk_size or max(1, len(data))
        parts = [data[i:i + step] for i in range(0, len(data), step)]
        if not parts or (chunk_size and final):
            parts.append(b"")
        for index, part in enumerate(parts):
            last = final and index == len(parts) - 1
            if buffered:
                address = dll.XML_GetBuffer(parser, max(1, len(part)))
                if not address:
                    raise MemoryError("XML_GetBuffer")
                C.memmove(address, part, len(part))
                status = dll.XML_ParseBuffer(parser, len(part), last)
            else:
                status = dll.XML_Parse(parser, part, len(part), last)
            if status == 2:  # XML_STATUS_SUSPENDED
                lifecycle.append(["suspended", status])
                status = dll.XML_ResumeParser(parser)
                lifecycle.append(["resumed", status])
            if status == 0:
                break
        return [status, dll.XML_GetErrorCode(parser), position()]

    def reset():
        lifecycle.append(["reset", dll.XML_ParserReset(parser, None)])
        configure()

    try:
        configure()
        result = feed(document, final=case_name != "reset-open")
        if case_name in ("reset-open", "reset-error"):
            lifecycle.append(["first", result])
            reset()
            lifecycle.append(["unbound-after-reset", feed(b"<q:stale/>")])
            reset()
            result = feed(b'<r xmlns:q="fresh"><q:ok/></r>')
        return dict(verdict=result[0], code=result[1], terminal=result[2],
                    events=events, lifecycle=lifecycle)
    finally:
        dll.XML_ParserFree(parser)


def run_matrix(dll, fixtures):
    rows = {}
    for name, triplets, chunk, deferral, buffered in product(
            fixtures, (0, 1), (0, 1, 17), (0, 1), (0, 1)):
        key = "/".join(map(str, (name, triplets, chunk, deferral, buffered)))
        rows[key] = trace_document(dll, fixtures[name], triplets=triplets, chunk_size=chunk,
                                   deferral=deferral, buffered=buffered, case_name=name)
    subset = ("boundary", "identical-bindings", "default-dtd", "duplicate", "unbound",
              "external", "reset-error")
    for name, handlers, triplets, chunk in product(subset, ("none", "ns", "start", "end"),
                                                   (0, 1), (0, 7)):
        key = "/".join(map(str, (name, handlers, triplets, chunk)))
        rows[key] = trace_document(dll, fixtures[name], triplets=triplets, chunk_size=chunk,
                                   deferral=False, buffered=False, case_name=name, handlers=handlers)
    for event, triplets, chunk in product(("bind", "end", "unbind"), (0, 1), (0, 1, 17)):
        key = f"stop-{event}/{triplets}/{chunk}"
        rows[key] = trace_document(dll, fixtures["boundary"], triplets=triplets, chunk_size=chunk,
                                   deferral=False, buffered=False, pause=event)
    return rows


def run_ns10_catalog(dll, fixtures):
    """Use direct XML_Parse with whole documents, bytewise feeds, and 17-byte feeds."""
    rows = {}
    for name, triplets, chunk in product(fixtures, (0, 1), (0, 1, 17)):
        key = f"{name}/{triplets}/{chunk}"
        rows[key] = trace_document(dll, fixtures[name], triplets=triplets, chunk_size=chunk,
                                   deferral=True, buffered=False)
    return rows


def main():
    arguments = argparse.ArgumentParser(description=__doc__)
    arguments.add_argument("--dll", required=True, type=Path)
    arguments.add_argument("--reference", required=True, type=Path)
    arguments.add_argument("--out", type=Path, help="Write the complete per-case comparison as JSON")
    arguments.add_argument("--ns10-catalog", type=Path,
                           help="Run the W3C rmt-ns10.xml catalogue with namespace processing enabled")
    options = arguments.parse_args()
    if options.ns10_catalog:
        catalogue = options.ns10_catalog
        fixtures = {test.attrib["ID"]: (catalogue.parent / test.attrib["URI"]).read_bytes()
                    for test in ElementTree.parse(catalogue).iterfind("TEST")}
        compare = run_ns10_catalog
    else:
        record = Path(__file__).with_name("namespace-correctness.json")
        fixture_text = json.loads(record.read_text(encoding="utf-8"))["scope_oracle"]["fixture_utf8"]
        fixtures = {name: text.encode("utf-8") for name, text in fixture_text.items()}
        compare = run_matrix
    reference = compare(load_dll(options.reference), fixtures)
    observed = compare(load_dll(options.dll), fixtures)
    fields = Counter()
    for key in reference:
        fields.update(field for field in reference[key] if observed[key][field] != reference[key][field])
    matches = sum(reference[key] == row for key, row in observed.items())
    print(f"{matches} of {len(observed)} cases have identical traces.")
    print(json.dumps(dict(sorted(fields.items()))))
    if options.out:
        options.out.write_text(json.dumps({"reference": reference, "observed": observed}) + "\n",
                               encoding="utf-8")


if __name__ == "__main__":
    main()
