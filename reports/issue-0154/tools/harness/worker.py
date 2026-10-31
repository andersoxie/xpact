"""Child process for pool.py: one JSON job per stdin line, one JSON result per stdout line."""
import ctypes
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import engines  # noqa: E402


class _Counters(ctypes.Structure):
    _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong)] + [
        (n, ctypes.c_size_t) for n in ("PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                                       "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
                                       "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage")]


def peak_mb():
    """Peak working set of this worker process (Windows), in MB."""
    c = _Counters()
    c.cb = ctypes.sizeof(c)
    proc = ctypes.windll.kernel32.GetCurrentProcess()
    ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(proc), ctypes.byref(c), c.cb)
    return round(c.PeakWorkingSetSize / 2**20, 1)

engine = sys.argv[1]
if engine == "xpact":
    engines.load()
for line in sys.stdin:
    job = json.loads(line)
    data = job["data"].encode("latin-1") if "data" in job else Path(job["file"]).read_bytes()
    kw = {k: job[k] for k in ("entity_root", "namespaces", "split", "encoding", "external", "bare") if job.get(k) is not None}
    if engine == "xpact" and job.get("amplification") is not None:
        kw["amplification"] = job["amplification"]
    if engine == "xpact" and job.get("api"):
        kw["api"] = job["api"]
    if job.get("explain_split"):
        # whole vs one chunking mode: verdicts, error codes and the first differing event
        kw.pop("split", None)
        a = engines.parse(engine, data, path=job.get("file"), **kw)
        b = engines.parse(engine, data, path=job.get("file"), split=job["explain_split"], **kw)
        i = next((k for k, (x, y) in enumerate(zip(a["events"], b["events"])) if x != y),
                 min(len(a["events"]), len(b["events"])))
        result = {"whole": [a["verdict"], a["error"], a["message"]], "split": [b["verdict"], b["error"], b["message"]],
                  "events_equal": a["events"] == b["events"], "n_whole": len(a["events"]), "n_split": len(b["events"]),
                  "at": i, "ev_whole": json.dumps(a["events"][i:i + 2])[:300],
                  "ev_split": json.dumps(b["events"][i:i + 2])[:300]}
        sys.stdout.write(json.dumps(result) + "\n")
        sys.stdout.flush()
        continue
    if job.get("compare_splits"):
        # whole vs byte by byte vs every split point (up to compare_splits bytes), inside this process
        kw.pop("split", None)
        whole = engines.parse(engine, data, path=job.get("file"), **kw)
        key = lambda r: (r["verdict"], r["error"], r["events"])  # noqa: E731
        byte = engines.parse(engine, data, path=job.get("file"), split="byte", **kw)
        bad = []
        if len(data) <= job["compare_splits"]:
            for k in range(1, len(data)):
                if key(engines.parse(engine, data, path=job.get("file"), split=k, **kw)) != key(whole):
                    bad.append(k)
        result = {"verdict": whole["verdict"], "error": whole["error"], "byte_same": key(byte) == key(whole),
                  "byte_verdict": byte["verdict"], "bad_splits": bad, "events": []}
        sys.stdout.write(json.dumps(result) + "\n")
        sys.stdout.flush()
        continue
    started = time.perf_counter()
    try:
        result = engines.parse(engine, data, path=job.get("file"), **kw)
    except Exception as exc:  # pyexpat raises Python errors (e.g. LookupError for an unknown encoding)
        result = {"verdict": "REJECT", "error": -1, "message": f"python {type(exc).__name__}: {exc}"[:200],
                  "line": 0, "column": 0, "events": []}
    result["seconds"] = round(time.perf_counter() - started, 4)
    result["peak_mb"] = peak_mb()
    if job.get("hash_events"):
        import hashlib
        result["events_hash"] = hashlib.sha256(json.dumps(result["events"]).encode()).hexdigest()[:16]
        result["event_count"] = len(result["events"])
        result["events"] = []
    if not job.get("keep_events", True):
        result["event_count"] = len(result["events"])
        result["events"] = []
    sys.stdout.write(json.dumps(result) + "\n")
    sys.stdout.flush()
