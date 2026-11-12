import json, subprocess, sys, time, xml.parsers.expat as expat
from pathlib import Path
worker, dll, src, out = map(Path, sys.argv[1:5]); out.mkdir(parents=True, exist_ok=True); rows=[]
for f in ["lol_classic.xml","lol_eg.xml","lol_ep.xml","lol_ig_attr.xml","lol_ig_content.xml"]:
    doc=(src/f).read_bytes(); (out/f).write_bytes(doc); t=time.perf_counter()
    try:
        p=subprocess.run([str(worker),"--dll",str(dll),"--build","production","--max-events","0"],input=doc,capture_output=True,timeout=60)
        x=json.loads(p.stdout) if p.stdout.strip() else {"verdict":f"exit 0x{p.returncode&0xFFFFFFFF:08X}"}
        xv=x["verdict"]+(f" ({x['error']['message']})" if x.get("error") else "")
    except subprocess.TimeoutExpired: xv="still running after 60 s (killed)"
    xms=round((time.perf_counter()-t)*1000); t=time.perf_counter(); pe=expat.ParserCreate()
    try: pe.Parse(doc,True); ev="accepted"
    except expat.ExpatError as e: ev=f"rejected ({expat.ErrorString(e.code)})"
    r={"file":f,"xpact":xv,"xpact_ms":xms,"expat":ev,"expat_ms":round((time.perf_counter()-t)*1000)}; rows.append(r); print(r)
(out/"lol-results.json").write_text(json.dumps(rows,indent=1))
