"""#209 recheck: elements fed in pieces through xpact.dll (ctypes, Expat API) and pyexpat."""
import ctypes as C, sys, time, json, os, pyexpat

dll_path = sys.argv[1]
os.add_dll_directory(os.path.dirname(dll_path))
lib = C.CDLL(dll_path)
lib.XML_ParserCreate.restype = C.c_void_p
lib.XML_ParserCreate.argtypes = [C.c_char_p]
lib.XML_Parse.argtypes = [C.c_void_p, C.c_char_p, C.c_int, C.c_int]
lib.XML_ParserFree.argtypes = [C.c_void_p]
lib.XML_GetErrorCode.argtypes = [C.c_void_p]
StartH = C.CFUNCTYPE(None, C.c_void_p, C.c_char_p, C.POINTER(C.c_char_p))
lib.XML_SetStartElementHandler.argtypes = [C.c_void_p, StartH]


def doc(size):
    item = b'<e a="1">t</e>'
    n = max(1, (size - 7) // len(item))
    return b"<r>" + item * n + b"</r>", n


def xpact(data, piece):
    p = lib.XML_ParserCreate(None)
    count = [0]
    cb = StartH(lambda u, n, a: count.__setitem__(0, count[0] + 1))
    lib.XML_SetStartElementHandler(p, cb)
    t = time.perf_counter()
    ok = 1
    for i in range(0, len(data), piece):
        chunk = data[i:i + piece]
        ok = lib.XML_Parse(p, chunk, len(chunk), 1 if i + piece >= len(data) else 0)
        if ok != 1:
            break
    ms = (time.perf_counter() - t) * 1000
    lib.XML_ParserFree(p)
    return ok, count[0], ms


def expat(data, piece):
    p = pyexpat.ParserCreate()
    count = [0]
    p.StartElementHandler = lambda n, a: count.__setitem__(0, count[0] + 1)
    t = time.perf_counter()
    for i in range(0, len(data), piece):
        p.Parse(data[i:i + piece], i + piece >= len(data))
    return 1, count[0], (time.perf_counter() - t) * 1000


rows = []
for size in (1024, 8192, 65536):
    data, n = doc(size)
    for piece in (1, 64, 4096):
        xo, xc, xms = xpact(data, piece)
        eo, ec, ems = expat(data, piece)
        rows.append({"bytes": len(data), "piece": piece, "xpact_ok": xo, "xpact_starts": xc, "xpact_ms": round(xms, 1),
                     "expat_starts": ec, "expat_ms": round(ems, 1)})
        print(json.dumps(rows[-1]), flush=True)
