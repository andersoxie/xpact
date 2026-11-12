import sys
n=int(sys.argv[2]); row=b'<item id="1">some text &amp; more text here</item>\n'
body=b'<?xml version="1.0"?>\n<root>\n'; tail=b'</root>\n'
k=(n-len(body)-len(tail))//len(row); d=body+row*k+tail
d=d[:-len(tail)]+b' '*(n-len(d))+tail if len(d)<n else d
open(sys.argv[1],'wb').write(d); print(sys.argv[1],len(d))
