"""Run the worker on a billion-laughs document under a Job Object memory cap (default 40 MB)."""
import ctypes, ctypes.wintypes as w, json, subprocess, sys
worker, dll, build = sys.argv[1], sys.argv[2], sys.argv[3]; mb = int(sys.argv[4]) if len(sys.argv) > 4 else 40
doc = '<!DOCTYPE r [<!ENTITY a0 "xxxxxxxxxx">' + "".join(f'<!ENTITY a{i} "{("&a%d;" % (i-1)) * 10}">' for i in range(1, 10)) + ']><r>&a9;</r>'
k = ctypes.WinDLL("kernel32", use_last_error=True)
class B(ctypes.Structure): _fields_=[("a",ctypes.c_int64),("b",ctypes.c_int64),("LimitFlags",w.DWORD),("c",ctypes.c_size_t),("d",ctypes.c_size_t),("e",w.DWORD),("f",ctypes.c_size_t),("g",w.DWORD),("h",w.DWORD)]
class E(ctypes.Structure): _fields_=[("B",B),("io",ctypes.c_uint64*6),("ProcessMemoryLimit",ctypes.c_size_t),("j",ctypes.c_size_t),("k",ctypes.c_size_t),("l",ctypes.c_size_t)]
k.CreateJobObjectW.restype = w.HANDLE; job = k.CreateJobObjectW(None, None)
info = E(); info.B.LimitFlags = 0x100 | 0x2000; info.ProcessMemoryLimit = mb * 1024 * 1024
assert k.SetInformationJobObject(job, 9, ctypes.byref(info), ctypes.sizeof(info))
p = subprocess.Popen([worker, "--dll", dll, "--build", build, "--max-events", "0"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
k.OpenProcess.restype = w.HANDLE; h = k.OpenProcess(0x1F0FFF, False, p.pid); assert k.AssignProcessToJobObject(job, h)
out, err = p.communicate(doc.encode(), timeout=60)
r = json.loads(out) if out.strip() else None
print(f"{build} cap={mb}MB exit=0x{p.returncode & 0xFFFFFFFF:08X} verdict={r and r['verdict']} error={r and r.get('error')} stderr={err.decode(errors='replace').strip()[:1500]}")
