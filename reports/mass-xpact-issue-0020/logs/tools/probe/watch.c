/* watch.c: like probe.c (mass-xpact #20), plus hardware write watchpoints set in-process.
   A watcher thread finds every committed private read-write address whose low 24 bits are
   %XPACT_WATCH_LOW% (hex, default 38c9be) and arms up to four of them as 1-byte write
   breakpoints in the main thread's debug registers. Each write is logged (value, top frames);
   a write that leaves 0x01 gets a full stack. Access violations are recorded as in probe.c.
   Output goes to %XPACT_CRASH_DIR%. No debugger is attached. */
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile LONG seen;
static HANDLE main_thread;
static DWORD main_tid;
static DWORD64 low_bits = 0x38c9be;
static DWORD64 armed[4];
static int narmed;
static FILE *wlog;
static volatile LONG writes, ones;
static CRITICAL_SECTION lock;

static void where(FILE *o, DWORD64 a) {
  HMODULE m = NULL; char path[MAX_PATH] = "?";
  if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)a, &m) && m) {
    GetModuleFileNameA(m, path, MAX_PATH);
    const char *n = strrchr(path, '\\'); n = n ? n + 1 : path;
    fprintf(o, " %s+%llx", n, (unsigned long long)(a - (DWORD64)m));
  } else fprintf(o, " ?%llx", (unsigned long long)a);
}

static void stack(FILE *o, CONTEXT c, int depth, const char *sep) {
  for (int d = 0; d < depth && c.Rip; d++) {
    where(o, c.Rip); fputs(sep, o);
    DWORD64 base; PVOID data; DWORD64 frame;
    PRUNTIME_FUNCTION f = RtlLookupFunctionEntry(c.Rip, &base, NULL);
    if (!f) { c.Rip = *(DWORD64 *)c.Rsp; c.Rsp += 8; continue; }
    RtlVirtualUnwind(UNW_FLAG_NHANDLER, base, c.Rip, f, &c, &data, &frame, NULL);
  }
}

static void dump_bytes(FILE *o, DWORD64 a) {
  unsigned char *p = (unsigned char *)(a & ~(DWORD64)7) - 16;
  fprintf(o, " bytes at %llx:", (unsigned long long)(DWORD64)p);
  for (int i = 0; i < 40; i++) fprintf(o, "%s%02x", (i % 8) ? "" : " ", p[i]);
  fputc('\n', o);
}

static void on_write(EXCEPTION_POINTERS *e) {
  CONTEXT *c = e->ContextRecord;
  DWORD64 dr6 = c->Dr6;
  for (int i = 0; i < 4; i++) {
    if (!(dr6 & (1ull << i))) continue;
    DWORD64 a = (&c->Dr0)[i];
    unsigned char v = *(unsigned char *)a;
    LONG n = InterlockedIncrement(&writes);
    if (!wlog) continue;
    EnterCriticalSection(&lock);
    if (v == 1) {
      LONG k = InterlockedIncrement(&ones);
      if (k <= 40) {
        fprintf(wlog, "ONE #%ld (write %ld) at %llx value 01, rip", k, n, (unsigned long long)a); where(wlog, c->Rip); fputc('\n', wlog);
        fprintf(wlog, " rax=%llx rbx=%llx rcx=%llx rdx=%llx rsi=%llx rdi=%llx r8=%llx r9=%llx r10=%llx r11=%llx r14=%llx r15=%llx\n",
                c->Rax, c->Rbx, c->Rcx, c->Rdx, c->Rsi, c->Rdi, c->R8, c->R9, c->R10, c->R11, c->R14, c->R15);
        dump_bytes(wlog, a);
        fputs(" stack:\n", wlog); stack(wlog, *c, 40, "\n"); fputs(" end\n", wlog);
      }
    } else if (n <= 400) {
      fprintf(wlog, "w %ld at %llx value %02x:", n, (unsigned long long)a, v); stack(wlog, *c, 4, ""); fputc('\n', wlog);
    }
    fflush(wlog);
    LeaveCriticalSection(&lock);
  }
  c->Dr6 = 0;
}

static LONG CALLBACK on_exception(EXCEPTION_POINTERS *e) {
  EXCEPTION_RECORD *er = e->ExceptionRecord;
  if (er->ExceptionCode == EXCEPTION_SINGLE_STEP && (e->ContextRecord->Dr6 & 0xf)) {
    on_write(e);
    return EXCEPTION_CONTINUE_EXECUTION;
  }
  if (er->ExceptionCode != EXCEPTION_ACCESS_VIOLATION) return EXCEPTION_CONTINUE_SEARCH;
  LONG k = InterlockedIncrement(&seen);
  if (k > 3) return EXCEPTION_CONTINUE_SEARCH;
  char dir[MAX_PATH], name[MAX_PATH];
  if (!GetEnvironmentVariableA("XPACT_CRASH_DIR", dir, MAX_PATH)) return EXCEPTION_CONTINUE_SEARCH;
  snprintf(name, MAX_PATH, "%s\\av-%lu-%ld.txt", dir, GetCurrentProcessId(), k);
  FILE *o = fopen(name, "w");
  if (o) {
    CONTEXT c = *e->ContextRecord;
    fprintf(o, "AV %ld at", k); where(o, (DWORD64)er->ExceptionAddress);
    fprintf(o, "\n %s address %llx, %ld watched writes, %ld of them 0x01\n", er->ExceptionInformation[0] ? "write" : "read",
            (unsigned long long)er->ExceptionInformation[1], writes, ones);
    fprintf(o, " rax=%llx rbx=%llx rcx=%llx rdx=%llx rsi=%llx rdi=%llx\n r8=%llx r9=%llx r10=%llx r11=%llx r12=%llx r13=%llx r14=%llx r15=%llx rsp=%llx rbp=%llx\n armed:",
            c.Rax, c.Rbx, c.Rcx, c.Rdx, c.Rsi, c.Rdi, c.R8, c.R9, c.R10, c.R11, c.R12, c.R13, c.R14, c.R15, c.Rsp, c.Rbp);
    for (int i = 0; i < narmed; i++) fprintf(o, " %llx", (unsigned long long)armed[i]);
    fputs("\nstack:\n", o); stack(o, c, 60, "\n");
    fclose(o);
  }
  snprintf(name, MAX_PATH, "%s\\av-%lu-%ld.dmp", dir, GetCurrentProcessId(), k);
  HANDLE h = CreateFileA(name, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
  if (h != INVALID_HANDLE_VALUE) {
    MINIDUMP_EXCEPTION_INFORMATION mi = { GetCurrentThreadId(), e, FALSE };
    MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), h,
                      MiniDumpWithIndirectlyReferencedMemory | MiniDumpWithDataSegs | MiniDumpWithPrivateReadWriteMemory,
                      &mi, NULL, NULL);
    CloseHandle(h);
  }
  return EXCEPTION_CONTINUE_SEARCH;
}

static int find_candidates(DWORD64 out[4], int *total) {
  int n = 0; *total = 0;
  MEMORY_BASIC_INFORMATION mb;
  for (DWORD64 p = 0x10000; p < 0x7fffffff0000ull && VirtualQuery((LPCVOID)p, &mb, sizeof mb); p = (DWORD64)mb.BaseAddress + mb.RegionSize) {
    if (mb.State != MEM_COMMIT || mb.Type != MEM_PRIVATE || mb.Protect != PAGE_READWRITE) continue;
    DWORD64 b = (DWORD64)mb.BaseAddress, end = b + mb.RegionSize;
    DWORD64 a = (b & ~0xffffffull) | low_bits;
    if (a < b) a += 0x1000000;
    for (; a < end; a += 0x1000000) { if (n < 4) out[n++] = a; (*total)++; }
  }
  return n;
}

static DWORD WINAPI watcher(LPVOID unused) {
  (void)unused;
  for (;;) {
    DWORD64 c[4]; int total;
    int n = find_candidates(c, &total);
    if (n != narmed || memcmp(c, armed, n * sizeof(DWORD64))) {
      if (SuspendThread(main_thread) != (DWORD)-1) {
        CONTEXT x; x.ContextFlags = CONTEXT_DEBUG_REGISTERS;
        if (GetThreadContext(main_thread, &x)) {
          DWORD64 dr7 = 0;
          for (int i = 0; i < 4; i++) {
            (&x.Dr0)[i] = i < n ? c[i] : 0;
            if (i < n) dr7 |= (1ull << (2 * i)) | (1ull << (16 + 4 * i)); /* local enable, RW=01 write, LEN=00 one byte */
          }
          x.Dr7 = dr7;
          SetThreadContext(main_thread, &x);
        }
        ResumeThread(main_thread);
      }
      memcpy(armed, c, sizeof c); narmed = n;
      if (wlog) {
        EnterCriticalSection(&lock);
        fprintf(wlog, "armed %d of %d candidates (tick %lu):", n, total, GetTickCount());
        for (int i = 0; i < n; i++) fprintf(wlog, " %llx", (unsigned long long)c[i]);
        fputc('\n', wlog); fflush(wlog);
        LeaveCriticalSection(&lock);
      }
    }
    Sleep(20);
  }
}

static void __cdecl install(void) {
  char dir[MAX_PATH], name[MAX_PATH], low[32];
  InitializeCriticalSection(&lock);
  AddVectoredExceptionHandler(1, on_exception);
  if (GetEnvironmentVariableA("XPACT_WATCH_LOW", low, sizeof low)) low_bits = strtoull(low, NULL, 16) & 0xffffff;
  if (GetEnvironmentVariableA("XPACT_CRASH_DIR", dir, MAX_PATH)) {
    snprintf(name, MAX_PATH, "%s\\watch-%lu.txt", dir, GetCurrentProcessId());
    wlog = fopen(name, "w");
  }
  if (!GetEnvironmentVariableA("XPACT_WATCH", low, sizeof low)) return; /* parent runner process: no watch */
  main_tid = GetCurrentThreadId();
  DuplicateHandle(GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(), &main_thread, 0, FALSE, DUPLICATE_SAME_ACCESS);
  CreateThread(NULL, 0, watcher, NULL, 0, NULL);
}
#pragma section(".CRT$XCU", read)
__declspec(allocate(".CRT$XCU")) static void (__cdecl *probe_install)(void) = install;
