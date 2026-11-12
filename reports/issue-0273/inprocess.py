"""#273 in-process probe: this process caps itself (Job Object), loads xpact.dll, makes a parse fail
with an Eiffel 'No more memory' exception, then checks that the failed parser answers safely and that a
new parser in the same process still works.   usage: python -I inprocess.py <xpact.dll> [cap MB]"""
import ctypes, ctypes.wintypes as w, sys
dll_path = sys.argv[1]; mb = int(sys.argv[2]) if len(sys.argv) > 2 else 40
k = ctypes.WinDLL("kernel32", use_last_error=True)
class B(ctypes.Structure): _fields_=[("a",ctypes.c_int64),("b",ctypes.c_int64),("LimitFlags",w.DWORD),("c",ctypes.c_size_t),("d",ctypes.c_size_t),("e",w.DWORD),("f",ctypes.c_size_t),("g",w.DWORD),("h",w.DWORD)]
class E(ctypes.Structure): _fields_=[("B",B),("io",ctypes.c_uint64*6),("ProcessMemoryLimit",ctypes.c_size_t),("j",ctypes.c_size_t),("k",ctypes.c_size_t),("l",ctypes.c_size_t)]
k.AssignProcessToJobObject.argtypes = [w.HANDLE, w.HANDLE]; k.SetInformationJobObject.argtypes = [w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD]
k.CreateJobObjectW.restype = w.HANDLE; job = k.CreateJobObjectW(None, None)
info = E(); info.B.LimitFlags = 0x100; info.ProcessMemoryLimit = mb * 1024 * 1024
assert k.SetInformationJobObject(job, 9, ctypes.byref(info), ctypes.sizeof(info))
k.GetCurrentProcess.restype = w.HANDLE; assert k.AssignProcessToJobObject(job, k.GetCurrentProcess()), ctypes.get_last_error()
x = ctypes.CDLL(dll_path)
x.XML_ParserCreate.restype = ctypes.c_void_p; x.XML_ParserCreate.argtypes = [ctypes.c_char_p]
for f in ("XML_Parse",): getattr(x, f).argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
for f in ("XML_GetErrorCode", "XML_GetCurrentLineNumber", "XML_GetCurrentColumnNumber", "XML_ParserFree"): getattr(x, f).argtypes = [ctypes.c_void_p]
x.XML_ErrorString.restype = ctypes.c_char_p
doc = ('<!DOCTYPE r [<!ENTITY a0 "xxxxxxxxxx">' + "".join(f'<!ENTITY a{i} "{("&a%d;" % (i-1)) * 10}">' for i in range(1, 10)) + ']><r>&a9;</r>').encode()
CHARS = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int)
text = [0]
def on_text(user, s, n): text[0] += n
on_text_c = CHARS(on_text)
x.XML_SetCharacterDataHandler.argtypes = [ctypes.c_void_p, CHARS]
p = x.XML_ParserCreate(None)
x.XML_SetCharacterDataHandler(p, on_text_c)
st = x.XML_Parse(p, doc, len(doc), 1); code = x.XML_GetErrorCode(p)
print(f"1. laughs under {mb} MB: status={st} code={code} ({x.XML_ErrorString(code).decode()})")
print(f"2. failed parser answers: again status={x.XML_Parse(p, b'<a/>', 4, 1)} code={x.XML_GetErrorCode(p)} line={x.XML_GetCurrentLineNumber(p)} col={x.XML_GetCurrentColumnNumber(p)}")
x.XML_ParserFree(p)
ok = 0
for i in range(200):
    q = x.XML_ParserCreate(None); s = x.XML_Parse(q, b"<a><b>t</b></a>", 15, 1); ok += (s == 1 and x.XML_GetErrorCode(q) == 0); x.XML_ParserFree(q)
print(f"3. new parsers after the failure: {ok}/200 parsed")
print("NOT TRIGGERED (no out-of-memory; lower the cap)" if code != 1 else ("PASS" if st == 0 and ok == 200 else "FAIL"))
