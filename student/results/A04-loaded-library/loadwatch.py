"""Run a command and record every DLL that every process in its tree loads (A04, #168).

The command is started as a debuggee (Windows debug API, DEBUG_PROCESS), so Windows
reports each process it creates, at any depth, and each DLL load with the file's
handle. No admin rights are needed. The debugger never changes what the program does:
the first breakpoint of each process is continued, every other exception is passed
back unhandled, as without a debugger.

Usage:
  python -I loadwatch.py --out watch.json [--timeout 3600] -- <command> [args...]
The command's own output goes to this process's stdout and stderr. The exit status is
the command's. watch.json lists every process (image, exit code, loaded DLLs) and the
size and SHA-256 of each loaded file whose name matches --hash (default: xpact*, expat*,
libexpat*, pyexpat*, plus every process image under the repository).
"""
from __future__ import annotations

import argparse
import ctypes as C
import fnmatch
import hashlib
import json
import subprocess
import sys
import time
from ctypes import wintypes as W
from pathlib import Path

k32 = C.WinDLL("kernel32", use_last_error=True)

DEBUG_PROCESS = 0x00000001
WAIT_MS = 1000  # poll for the timeout between debug events
DBG_CONTINUE = 0x00010002
DBG_EXCEPTION_NOT_HANDLED = 0x80010001
BREAKPOINTS = (0x80000003, 0x4000001F)  # STATUS_BREAKPOINT, STATUS_WX86_BREAKPOINT
EXCEPTION, CREATE_THREAD, CREATE_PROCESS, EXIT_THREAD, EXIT_PROCESS, LOAD_DLL = 1, 2, 3, 4, 5, 6
STARTF_USESTDHANDLES = 0x00000100


class EXCEPTION_RECORD(C.Structure):
    _fields_ = [("ExceptionCode", W.DWORD), ("ExceptionFlags", W.DWORD), ("ExceptionRecord", C.c_void_p),
                ("ExceptionAddress", C.c_void_p), ("NumberParameters", W.DWORD),
                ("ExceptionInformation", C.c_size_t * 15)]


class EXCEPTION_DEBUG_INFO(C.Structure):
    _fields_ = [("ExceptionRecord", EXCEPTION_RECORD), ("dwFirstChance", W.DWORD)]


class CREATE_PROCESS_DEBUG_INFO(C.Structure):
    _fields_ = [("hFile", W.HANDLE), ("hProcess", W.HANDLE), ("hThread", W.HANDLE), ("lpBaseOfImage", C.c_void_p),
                ("dwDebugInfoFileOffset", W.DWORD), ("nDebugInfoSize", W.DWORD), ("lpThreadLocalBase", C.c_void_p),
                ("lpStartAddress", C.c_void_p), ("lpImageName", C.c_void_p), ("fUnicode", W.WORD)]


class EXIT_PROCESS_DEBUG_INFO(C.Structure):
    _fields_ = [("dwExitCode", W.DWORD)]


class LOAD_DLL_DEBUG_INFO(C.Structure):
    _fields_ = [("hFile", W.HANDLE), ("lpBaseOfDll", C.c_void_p), ("dwDebugInfoFileOffset", W.DWORD),
                ("nDebugInfoSize", W.DWORD), ("lpImageName", C.c_void_p), ("fUnicode", W.WORD)]


class _U(C.Union):
    _fields_ = [("Exception", EXCEPTION_DEBUG_INFO), ("CreateProcessInfo", CREATE_PROCESS_DEBUG_INFO),
                ("ExitProcess", EXIT_PROCESS_DEBUG_INFO), ("LoadDll", LOAD_DLL_DEBUG_INFO)]


class DEBUG_EVENT(C.Structure):
    _fields_ = [("dwDebugEventCode", W.DWORD), ("dwProcessId", W.DWORD), ("dwThreadId", W.DWORD), ("u", _U)]


class STARTUPINFOW(C.Structure):
    _fields_ = [("cb", W.DWORD), ("lpReserved", W.LPWSTR), ("lpDesktop", W.LPWSTR), ("lpTitle", W.LPWSTR),
                ("dwX", W.DWORD), ("dwY", W.DWORD), ("dwXSize", W.DWORD), ("dwYSize", W.DWORD),
                ("dwXCountChars", W.DWORD), ("dwYCountChars", W.DWORD), ("dwFillAttribute", W.DWORD),
                ("dwFlags", W.DWORD), ("wShowWindow", W.WORD), ("cbReserved2", W.WORD),
                ("lpReserved2", C.c_void_p), ("hStdInput", W.HANDLE), ("hStdOutput", W.HANDLE),
                ("hStdError", W.HANDLE)]


class PROCESS_INFORMATION(C.Structure):
    _fields_ = [("hProcess", W.HANDLE), ("hThread", W.HANDLE), ("dwProcessId", W.DWORD), ("dwThreadId", W.DWORD)]


k32.WaitForDebugEvent.argtypes = [C.POINTER(DEBUG_EVENT), W.DWORD]
k32.ContinueDebugEvent.argtypes = [W.DWORD, W.DWORD, W.DWORD]
k32.GetFinalPathNameByHandleW.argtypes = [W.HANDLE, W.LPWSTR, W.DWORD, W.DWORD]
k32.CloseHandle.argtypes = [W.HANDLE]
k32.ReadProcessMemory.argtypes = [W.HANDLE, C.c_void_p, C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t)]
k32.TerminateProcess.argtypes = [W.HANDLE, W.UINT]
k32.GetStdHandle.restype = W.HANDLE
k32.CreateProcessW.argtypes = [W.LPCWSTR, W.LPWSTR, C.c_void_p, C.c_void_p, W.BOOL, W.DWORD, C.c_void_p,
                               W.LPCWSTR, C.POINTER(STARTUPINFOW), C.POINTER(PROCESS_INFORMATION)]


def path_of(handle):
    """Full path of an open file handle, without the \\\\?\\ prefix; None if unknown."""
    if not handle:
        return None
    buf = C.create_unicode_buffer(1024)
    n = k32.GetFinalPathNameByHandleW(handle, buf, 1024, 0)
    if not n:
        return None
    p = buf.value
    if p.startswith("\\\\?\\UNC\\"):
        return "\\\\" + p[8:]
    return p[4:] if p.startswith("\\\\?\\") else p


def read_image_name(process, address, unicode):
    """lpImageName is a pointer, in the debuggee, to a pointer to the name (may be NULL)."""
    if not process or not address:
        return None
    ptr, got = C.c_void_p(), C.c_size_t()
    if not k32.ReadProcessMemory(process, address, C.byref(ptr), C.sizeof(ptr), C.byref(got)) or not ptr.value:
        return None
    raw = C.create_string_buffer(1040)
    if not k32.ReadProcessMemory(process, ptr.value, raw, 1040, C.byref(got)):
        return None
    data = raw.raw[:got.value]
    text = data.decode("utf-16-le", "replace") if unicode else data.decode("mbcs", "replace")
    return text.split("\0", 1)[0] or None


def start_debuggee(command):
    """Start the command with this process's standard handles, every descendant debugged by this thread."""
    si = STARTUPINFOW()
    si.cb = C.sizeof(si)
    si.dwFlags = STARTF_USESTDHANDLES
    si.hStdInput, si.hStdOutput, si.hStdError = (k32.GetStdHandle(n) for n in (-10, -11, -12))
    pi = PROCESS_INFORMATION()
    line = C.create_unicode_buffer(subprocess.list2cmdline(command))
    if not k32.CreateProcessW(None, line, None, None, True, DEBUG_PROCESS, None, None, C.byref(si), C.byref(pi)):
        raise OSError(C.get_last_error(), "CreateProcessW failed")
    k32.CloseHandle(pi.hThread)
    return pi.dwProcessId


class Watcher:
    """The debug loop: one handler per event kind; records processes and their DLL loads."""

    def __init__(self):
        self.processes, self.handles = {}, {}
        self.live, self.started, self.timed_out = 0, time.monotonic(), False

    def file_name(self, h_file, process, image_name, unicode):
        name = path_of(h_file) or read_image_name(process, image_name, unicode)
        if h_file:
            k32.CloseHandle(h_file)  # the debugger owns the file handle of these events
        return name

    def on_create(self, pid, ev):
        info = ev.u.CreateProcessInfo
        image = self.file_name(info.hFile, info.hProcess, info.lpImageName, info.fUnicode)
        self.processes[pid] = {"pid": pid, "order": len(self.processes) + 1, "image": image, "dlls": [],
                               "exit_code": None, "started_s": round(time.monotonic() - self.started, 3)}
        self.handles[pid] = info.hProcess  # closed by the system after EXIT_PROCESS is continued
        self.live += 1
        return DBG_CONTINUE

    def on_load(self, pid, ev):
        info = ev.u.LoadDll
        name = self.file_name(info.hFile, self.handles.get(pid), info.lpImageName, info.fUnicode)
        dlls = self.processes.get(pid, {}).get("dlls")
        if dlls is not None and name and name not in dlls:
            dlls.append(name)
        return DBG_CONTINUE

    def on_exit(self, pid, ev):
        if pid in self.processes:
            self.processes[pid]["exit_code"] = ev.u.ExitProcess.dwExitCode
            self.processes[pid]["ended_s"] = round(time.monotonic() - self.started, 3)
        self.handles.pop(pid, None)
        self.live -= 1
        return DBG_CONTINUE

    @staticmethod
    def on_exception(pid, ev):
        # The first breakpoint of each process belongs to the debugger; everything else
        # goes back to the program as if no debugger were attached.
        code = ev.u.Exception.ExceptionRecord.ExceptionCode
        return DBG_CONTINUE if code in BREAKPOINTS else DBG_EXCEPTION_NOT_HANDLED

    def stop_if_late(self, timeout):
        if not self.timed_out and time.monotonic() - self.started > timeout:
            self.timed_out = True
            for h in self.handles.values():
                k32.TerminateProcess(h, 0xDEAD)

    def run(self, command, timeout):
        root = start_debuggee(command)
        handlers = {CREATE_PROCESS: self.on_create, LOAD_DLL: self.on_load, EXIT_PROCESS: self.on_exit,
                    EXCEPTION: self.on_exception}
        ev = DEBUG_EVENT()
        while True:
            if not k32.WaitForDebugEvent(C.byref(ev), WAIT_MS):
                self.stop_if_late(timeout)
                continue
            handler = handlers.get(ev.dwDebugEventCode)
            status = handler(ev.dwProcessId, ev) if handler else DBG_CONTINUE
            k32.ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, status)
            if ev.dwDebugEventCode == EXIT_PROCESS and self.live == 0:
                break
        return {"root_pid": root, "exit_code": self.processes.get(root, {}).get("exit_code"),
                "timed_out": self.timed_out, "seconds": round(time.monotonic() - self.started, 1),
                "processes": sorted(self.processes.values(), key=lambda p: p["order"])}


def hash_files(processes, patterns, repo):
    """Size and SHA-256 of each loaded file that matches a pattern, and of every image under repo."""
    files = {}
    for p in processes:
        wanted = [d for d in p["dlls"] if any(fnmatch.fnmatch(Path(d).name.lower(), pat) for pat in patterns)]
        if p["image"] and p["image"].lower().startswith(repo):
            wanted.append(p["image"])
        for f in wanted:
            if f in files:
                continue
            try:
                data = Path(f).read_bytes()
                files[f] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
            except OSError as exc:
                files[f] = {"error": str(exc)}
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--timeout", type=float, default=3600)
    ap.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[3])
    ap.add_argument("--hash", nargs="*", default=["xpact*", "expat*", "libexpat*", "pyexpat*"])
    ap.add_argument("command", nargs=argparse.REMAINDER)
    args = ap.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        ap.error("no command")
    result = Watcher().run(command, args.timeout)
    result.update({"command": command,
                   "files": hash_files(result["processes"], args.hash, str(args.repo.resolve()).lower())})
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1), encoding="utf-8")
    code = result["exit_code"]
    if code is None:
        return 1
    return code - 2**32 if code >= 2**31 else code  # sys.exit takes a signed int; Windows keeps the 32 bits

if __name__ == "__main__":
    sys.exit(main())
