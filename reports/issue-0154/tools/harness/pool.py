"""Run many parses in a child process, so a crash or hang in xpact.dll costs one case, not the run.

    with Pool("xpact") as pool:
        result = pool.run({"file": "...", "entity_root": "...", "namespaces": False, "split": None})

A crash gives {"verdict": "CRASH", "exit": code}; a timeout gives {"verdict": "TIMEOUT"}.
The child is restarted after either. The job can carry "data" (latin-1 string of bytes)
instead of "file".
"""
from __future__ import annotations

import json
import os
import queue
import subprocess
import sys
import threading
from pathlib import Path

HERE = Path(__file__).resolve().parent


class Pool:
    def __init__(self, engine, timeout=10.0, dll=None):
        # os.add_dll_directory in the worker accepts absolute paths only.
        self.engine, self.timeout, self.dll = engine, timeout, Path(dll).resolve() if dll else None
        self.proc = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def _start(self):
        env = dict(os.environ)
        if self.dll:
            env["XPACT_DLL"] = str(self.dll)
        self.proc = subprocess.Popen([sys.executable, "-u", str(HERE / "worker.py"), self.engine],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                     env=env, text=True, encoding="utf-8", bufsize=1)
        self.lines = queue.Queue()
        threading.Thread(target=self._read, args=(self.proc, self.lines), daemon=True).start()

    @staticmethod
    def _read(proc, lines):
        for line in proc.stdout:
            lines.put(line)
        lines.put(None)

    def close(self):
        if self.proc:
            try:
                self.proc.kill()
            except OSError:
                pass
            self.proc = None

    def run(self, job, timeout=None):
        if self.proc is None or self.proc.poll() is not None:
            self._start()
        try:
            self.proc.stdin.write(json.dumps(job) + "\n")
            self.proc.stdin.flush()
            line = self.lines.get(timeout=timeout or self.timeout)
        except queue.Empty:
            self.close()
            return {"verdict": "TIMEOUT", "events": []}
        except OSError:
            line = None
        if line is None:
            code = self.proc.wait()
            self.proc = None
            return {"verdict": "CRASH", "exit": code, "exit_hex": f"0x{code & 0xFFFFFFFF:08X}", "events": []}
        return json.loads(line)
