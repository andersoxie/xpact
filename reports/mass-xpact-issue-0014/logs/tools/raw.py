"""Raw ctypes cost without Python handlers: python -I raw.py <dll> <file> <n>"""
import ctypes as C, sys, time
dll = C.CDLL(sys.argv[1]); P = C.c_void_p
dll.XML_ParserCreate.restype = P; dll.XML_ParserCreate.argtypes = [C.c_char_p]
dll.XML_ParserFree.argtypes = [P]
dll.XML_Parse.argtypes = [P, C.c_char_p, C.c_int, C.c_int]
data = open(sys.argv[2], "rb").read() if sys.argv[2] != "-" else b"<a/>"
n = int(sys.argv[3])
def t(label, f):
    f(); s = time.perf_counter()
    for _ in range(n): f()
    print(f"{label:28s} {(time.perf_counter()-s)/n*1e6:9.1f} us")
def cf(): dll.XML_ParserFree(dll.XML_ParserCreate(None))
def whole():
    p = dll.XML_ParserCreate(None); r = dll.XML_Parse(p, data, len(data), 1); dll.XML_ParserFree(p); assert r == 1
def split():
    k = len(data)//2
    p = dll.XML_ParserCreate(None); dll.XML_Parse(p, data[:k], k, 0); r = dll.XML_Parse(p, data[k:], len(data)-k, 1); dll.XML_ParserFree(p); assert r == 1
t("create+free", cf); t("whole", whole); t("split half", split)
