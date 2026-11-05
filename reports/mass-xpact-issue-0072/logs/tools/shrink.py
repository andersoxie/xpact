# shrink.py <probe.exe> <dll dir> <in.xml> <out.xml>: remove bytes while the probe still crashes (non-zero exit).
import os, subprocess, sys, tempfile
exe, dll, src, dst = sys.argv[1:5]
env = dict(os.environ); env['PATH'] = dll + os.pathsep + env['PATH']
tmp = os.path.join(tempfile.gettempdir(), 'shrink-case.xml'); lst = tmp + '.lst'; open(lst, 'w').write(tmp + '\n')
def crashes(d):
    open(tmp, 'wb').write(d)
    with open(lst) as i: return subprocess.run([exe, '1'], stdin=i, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env).returncode != 0
d = open(src, 'rb').read(); assert crashes(d)
n = len(d) // 2
while n >= 1:
    i, changed = 0, False
    while i < len(d):
        t = d[:i] + d[i + n:]
        if crashes(t): d, changed = t, True
        else: i += n
    if not changed: n //= 2
open(dst, 'wb').write(d); print(len(d), repr(d))
