"""Deep but tiny entity nesting: N levels, each adds 1 byte. Tests the depth limit, not amplification."""
import json, subprocess, sys, xml.parsers.expat as expat
from pathlib import Path
worker, dll, out = map(Path, sys.argv[1:4]); rows=[]
for n in (31, 32, 33, 40, 48):
    d=['<!ENTITY e0 "x">']+[f'<!ENTITY e{i} "&e{i-1};x">' for i in range(1,n)]
    doc=f'<!DOCTYPE r [{"".join(d)}]><r>&e{n-1};</r>'.encode(); (out/f"deep-{n}.xml").write_bytes(doc)
    p=subprocess.run([str(worker),"--dll",str(dll),"--build","production","--max-events","0"],input=doc,capture_output=True,timeout=60)
    x=json.loads(p.stdout); e=x.get("error") or {}
    pe=expat.ParserCreate()
    try: pe.Parse(doc,True); ev="accepted"
    except expat.ExpatError as ex: ev=f"rejected ({expat.ErrorString(ex.code)})"
    r={"levels":n,"xpact":x["verdict"],"xpact_code":e.get("code"),"xpact_msg":e.get("message"),"expat":ev}; rows.append(r); print(r)
(out/"deep-results.json").write_text(json.dumps(rows,indent=1))
