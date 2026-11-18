"""Test 5d: Expat C-API misuse and CVE probes against xpact.dll, each in its own process.

Expected = what Expat 2.8.1 does (documented API behaviour); a crash is always a failure.
Usage: python api_probes.py [--dll path]      (python api_probes.py --child NAME   internal)
"""
import ctypes as C
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))

ERR_INVALID_ARGUMENT, ERR_SUSPENDED, ERR_NOT_SUSPENDED, ERR_FINISHED, ERR_NOT_STARTED = 41, 33, 34, 36, 44


def probes(lib):
    P = C.c_void_p
    for name, res, args in [("XML_StopParser", C.c_int, [P, C.c_ubyte]), ("XML_ResumeParser", C.c_int, [P]),
                            ("XML_ParseBuffer", C.c_int, [P, C.c_int, C.c_int]), ("XML_GetBuffer", P, [P, C.c_int]),
                            ("XML_ParserReset", C.c_ubyte, [P, C.c_char_p]), ("XML_SetEncoding", C.c_int, [P, C.c_char_p]),
                            ("XML_SetHashSalt", C.c_int, [P, C.c_ulong])]:
        f = getattr(lib, name)
        f.restype, f.argtypes = res, args
    new = lambda: lib.XML_ParserCreate(None)  # noqa: E731
    doc = b"<d><e/></d>"

    def neg_len():  # CVE-2024-45490
        p = new()
        return lib.XML_Parse(p, doc, -1, 1), lib.XML_GetErrorCode(p)

    def null_buffer_with_len():
        p = new()
        return lib.XML_Parse(p, None, 5, 1), lib.XML_GetErrorCode(p)

    def parse_buffer_without_get_buffer():
        p = new()
        return lib.XML_ParseBuffer(p, 10, 1), lib.XML_GetErrorCode(p)

    def get_buffer_negative():
        p = new()
        return bool(lib.XML_GetBuffer(p, -1)), lib.XML_GetErrorCode(p)

    def get_buffer_huge():
        p = new()
        return bool(lib.XML_GetBuffer(p, 2**31 - 1)), lib.XML_GetErrorCode(p)

    def resume_not_started():  # CVE-2024-50602 family
        p = new()
        return lib.XML_ResumeParser(p), lib.XML_GetErrorCode(p)

    def resume_after_abort():  # CVE-2024-50602
        p = new()
        lib.XML_Parse(p, b"<d>", 3, 0)
        lib.XML_StopParser(p, 0)
        return lib.XML_ResumeParser(p), lib.XML_GetErrorCode(p)

    def stop_not_started():
        p = new()
        return lib.XML_StopParser(p, 1), lib.XML_GetErrorCode(p)

    def stop_finished():
        p = new()
        lib.XML_Parse(p, doc, len(doc), 1)
        return lib.XML_StopParser(p, 1), lib.XML_GetErrorCode(p)

    def parse_after_finish():
        p = new()
        lib.XML_Parse(p, doc, len(doc), 1)
        return lib.XML_Parse(p, doc, len(doc), 1), lib.XML_GetErrorCode(p)

    def free_null():
        lib.XML_ParserFree(None)
        return "no crash"

    def reset_then_parse():
        p = new()
        lib.XML_Parse(p, b"<bad", 4, 1)
        lib.XML_ParserReset(p, None)
        return lib.XML_Parse(p, doc, len(doc), 1), lib.XML_GetErrorCode(p)

    def set_encoding_after_start():
        p = new()
        lib.XML_Parse(p, b"<d>", 3, 0)
        return lib.XML_SetEncoding(p, b"UTF-16"), "status only"

    def suspend_in_handler_resume():
        p = new()
        log = []
        cb = C.CFUNCTYPE(None, P, C.c_char_p, C.POINTER(C.c_char_p))(
            lambda _, n, a: (log.append(n), lib.XML_StopParser(p, 1)))
        h = lib.XML_SetStartElementHandler
        h.argtypes = [P, type(cb)]
        h(p, cb)
        first = lib.XML_Parse(p, doc, len(doc), 1)
        second = lib.XML_ResumeParser(p)
        third = lib.XML_ResumeParser(p)
        return first, second, third, [x.decode() for x in log]

    return {
        "XML_Parse len = -1 (CVE-2024-45490)": (neg_len, [0, ERR_INVALID_ARGUMENT]),
        "XML_Parse NULL buffer, len 5": (null_buffer_with_len, [0, ERR_INVALID_ARGUMENT]),
        "XML_ParseBuffer without XML_GetBuffer": (parse_buffer_without_get_buffer, [0, 42]),
        "XML_GetBuffer(-1)": (get_buffer_negative, [False, 1]),  # Expat 2.8.1 xmlparse.c:2445: XML_ERROR_NO_MEMORY
        "XML_GetBuffer(2^31-1)": (get_buffer_huge, [False, 1]),
        "XML_ResumeParser before parsing": (resume_not_started, [0, ERR_NOT_SUSPENDED]),
        "XML_ResumeParser after abort (CVE-2024-50602)": (resume_after_abort, [0, ERR_NOT_SUSPENDED]),
        "XML_StopParser before parsing": (stop_not_started, [0, ERR_NOT_STARTED]),
        "XML_StopParser after finish": (stop_finished, [0, ERR_FINISHED]),
        "XML_Parse after the final buffer": (parse_after_finish, [0, ERR_FINISHED]),
        "XML_ParserFree(NULL)": (free_null, "no crash"),
        "XML_ParserReset after an error, parse again": (reset_then_parse, [1, 0]),
        "XML_SetEncoding after parsing started": (set_encoding_after_start, [0, "status only"]),
        "suspend in a handler, resume twice": (suspend_in_handler_resume, [2, 2, 1, ["d", "e"]]),
    }


if len(sys.argv) > 2 and sys.argv[1] == "--child":
    import engines
    result = probes(engines.load())[sys.argv[2]][0]()
    print(json.dumps(result if isinstance(result, str) else list(result)))
    sys.exit(0)

env = dict(os.environ)
if len(sys.argv) > 2 and sys.argv[1] == "--dll":
    env["XPACT_DLL"] = sys.argv[2]
import engines  # noqa: E402

rows = []
for name, (_, expected) in probes(engines.load()).items():
    p = subprocess.run([sys.executable, __file__, "--child", name], capture_output=True, text=True, env=env, timeout=60)
    if p.returncode != 0:
        got, status = f"CRASH 0x{p.returncode & 0xFFFFFFFF:08X}", "FAIL"
    else:
        got = json.loads(p.stdout.strip().splitlines()[-1])
        status = "pass" if got == expected else "differs"
    rows.append({"probe": name, "expected (Expat)": expected, "xpact": got, "status": status})
    print(f"{status:8} {name:48} expected {expected!s:28} xpact {got}")
(HERE / "logs" / "api-probes.json").write_text(json.dumps(rows, indent=1))
