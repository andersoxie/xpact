import sys,re
def secs(p):
    d={};cur=None
    for line in open(p,encoding='utf-8',errors='replace'):
        line=line.rstrip('\r\n')
        if line.startswith('== '): cur=line[3:]; d[cur]=[]
        elif cur is not None: d[cur].append(line)
    return d
def ends(s): return [re.sub(r'^END@[^ ]* ','',l) for l in s if l.startswith('END@')]
ex,a,b=secs(sys.argv[1]),secs(sys.argv[2]),secs(sys.argv[3])
ch=[n for n in b if a.get(n)!=b.get(n)]
before=sum(ends(a[n])==ends(ex[n]) for n in ch); after=sum(ends(b[n])==ends(ex[n]) for n in ch)
allb=sum(ends(b[n])==ends(ex.get(n,[])) for n in b); alla=sum(ends(a[n])==ends(ex.get(n,[])) for n in a)
print(f"changed {len(ch)}: end status/error = Expat before {before}, after {after} | all files before {alla}, after {allb} of {len(b)}")
for n in ch:
    if ends(b[n])!=ends(ex[n]): print("   differs:",re.sub(r'.*xmlconf.','',n),ends(ex[n]),ends(b[n]))
