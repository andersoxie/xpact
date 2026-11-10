"""#125 probe: events the default handler gets before a mismatched end tag, against Expat.

    python -I reports/issue-0125/tools/probe.py <xpact dll> <libexpat dll>

Each document runs whole and byte by byte, with only a default handler and with
element handlers too. Prints the events and (error code, column) per DLL.
"""
import ctypes as C, sys
DEF=C.CFUNCTYPE(None,C.c_void_p,C.POINTER(C.c_char),C.c_int)
START=C.CFUNCTYPE(None,C.c_void_p,C.c_char_p,C.POINTER(C.c_char_p)); END=C.CFUNCTYPE(None,C.c_void_p,C.c_char_p)
def run(dll, parts, with_elem):
    l=C.CDLL(dll); l.XML_ParserCreate.restype=C.c_void_p; l.XML_ParserCreate.argtypes=[C.c_char_p]
    l.XML_Parse.argtypes=[C.c_void_p,C.c_char_p,C.c_int,C.c_int]
    for f in ("XML_GetErrorCode","XML_GetCurrentColumnNumber","XML_ParserFree"): getattr(l,f).argtypes=[C.c_void_p]
    l.XML_GetCurrentColumnNumber.restype=C.c_ulong
    ev=[]; d=DEF(lambda u,p,n: ev.append("d:"+C.string_at(p,n).decode()))
    s=START(lambda u,n,a: ev.append("s:"+n.decode())); e=END(lambda u,n: ev.append("e:"+n.decode()))
    p=l.XML_ParserCreate(None); l.XML_SetDefaultHandler.argtypes=[C.c_void_p,DEF]; l.XML_SetDefaultHandler(p,d)
    if with_elem: l.XML_SetElementHandler.argtypes=[C.c_void_p,START,END]; l.XML_SetElementHandler(p,s,e)
    st=1
    for i,x in enumerate(parts):
        st=l.XML_Parse(p,x,len(x),int(i==len(parts)-1))
        if not st: break
    r=(ev,l.XML_GetErrorCode(p),l.XML_GetCurrentColumnNumber(p)); l.XML_ParserFree(p); return r
same=[]
for doc in (b"<root><child></root>", b"<a></b>", b"<a>t</b>", b"<a><b></a></b>"):
  for we in (False,True):
    for m,parts in (("whole",[doc]),("bytes",[doc[i:i+1] for i in range(len(doc))])):
        x,e=run(sys.argv[1],parts,we),run(sys.argv[2],parts,we)
        same.append(x==e)
        print("=" if x==e else "X", doc, "elem" if we else "dflt", m, "\n   xpact",x,"\n   expat",e)
print(f"same as Expat: {sum(same)} / {len(same)}")
