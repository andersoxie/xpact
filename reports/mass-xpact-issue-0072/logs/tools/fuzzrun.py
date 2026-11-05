# fuzzrun.py <probe.exe> <dll dir or -> <list> <out.tsv> [timeout seconds]: run the probe over the list and restart
# it after a crash or a hang, recording the file as CRASH (with the exit code) or HANG (acceptance run, #67).
import os, subprocess, sys

exe, dll, lst, out = sys.argv[1:5]
limit = int(sys.argv[5]) if len(sys.argv) > 5 else 60
env = dict(os.environ)
if dll != '-': env['PATH'] = dll + os.pathsep + env['PATH']
total = sum(1 for l in open(lst) if l.strip())
first, rows = 1, open(out, 'w')
while first <= total:
    with open(lst, 'rb') as stdin:
        p = subprocess.Popen([exe, str(first)], stdin=stdin, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env, text=True)
        current, done = None, False
        try:
            text, _ = p.communicate(timeout=limit * 50)
        except subprocess.TimeoutExpired:
            p.kill(); text, _ = p.communicate(); code = 'HANG'
        else:
            code = p.returncode
        for line in text.splitlines():
            if line.startswith('B '): current = int(line[2:])
            elif line == 'DONE': done = True
            else: rows.write(line + '\n')
    if done: break
    bad = current if current is not None else first
    rows.write(f"{bad}\tall\t{'HANG' if code == 'HANG' else 'CRASH'}\t{code}\t0\t0\t0\t0\n"); rows.flush()
    print(f"file {bad}: {'HANG' if code == 'HANG' else f'CRASH exit {code}'}", flush=True)
    first = bad + 1
rows.close()
print("finished", out)
