/* probe.c: linked into a diagnostic copy of the libexpat runner (mass-xpact #20).
   A vectored exception handler, installed before main, records the first access violations of
   the process without a debugger attached: the faulting address, the registers, the stack
   (RtlVirtualUnwind) as module+rva, and a minidump. Output goes to %XPACT_CRASH_DIR%. */
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <string.h>

static volatile LONG seen;

static void where(FILE *o, DWORD64 a) {
  HMODULE m = NULL; char path[MAX_PATH] = "?";
  if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)a, &m) && m) {
    GetModuleFileNameA(m, path, MAX_PATH);
    const char *n = strrchr(path, '\\'); n = n ? n + 1 : path;
    fprintf(o, "  %s+%llx\n", n, (unsigned long long)(a - (DWORD64)m));
  } else fprintf(o, "  ?%llx\n", (unsigned long long)a);
}

static LONG CALLBACK on_exception(EXCEPTION_POINTERS *e) {
  EXCEPTION_RECORD *er = e->ExceptionRecord;
  if (er->ExceptionCode == EXCEPTION_BREAKPOINT || er->ExceptionCode == 0x406D1388 || er->ExceptionCode == 0x40010006) return EXCEPTION_CONTINUE_SEARCH; /* every other exception (mass-xpact #3) */
  LONG k = InterlockedIncrement(&seen);
  if (k > 8) return EXCEPTION_CONTINUE_SEARCH;
  char dir[MAX_PATH], name[MAX_PATH];
  if (!GetEnvironmentVariableA("XPACT_CRASH_DIR", dir, MAX_PATH)) return EXCEPTION_CONTINUE_SEARCH;
  snprintf(name, MAX_PATH, "%s\\ex-%lu-%ld.txt", dir, GetCurrentProcessId(), k);
  FILE *o = fopen(name, "w");
  if (o) {
    CONTEXT c = *e->ContextRecord;
    fprintf(o, "EXCEPTION %ld code 0x%08lx at", k, er->ExceptionCode); where(o, (DWORD64)er->ExceptionAddress);
    fprintf(o, " %s address %llx\n", er->ExceptionInformation[0] ? "write" : "read", (unsigned long long)er->ExceptionInformation[1]);
    fprintf(o, " rax=%llx rbx=%llx rcx=%llx rdx=%llx rsi=%llx rdi=%llx\n r8=%llx r9=%llx r10=%llx r11=%llx r12=%llx r13=%llx r14=%llx r15=%llx rsp=%llx rbp=%llx\nstack:\n",
            c.Rax, c.Rbx, c.Rcx, c.Rdx, c.Rsi, c.Rdi, c.R8, c.R9, c.R10, c.R11, c.R12, c.R13, c.R14, c.R15, c.Rsp, c.Rbp);
    for (int d = 0; d < 60 && c.Rip; d++) {
      where(o, c.Rip);
      DWORD64 base; PVOID data; DWORD64 frame;
      PRUNTIME_FUNCTION f = RtlLookupFunctionEntry(c.Rip, &base, NULL);
      if (!f) { c.Rip = *(DWORD64 *)c.Rsp; c.Rsp += 8; continue; }
      RtlVirtualUnwind(UNW_FLAG_NHANDLER, base, c.Rip, f, &c, &data, &frame, NULL);
    }
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

static void __cdecl install(void) { AddVectoredExceptionHandler(1, on_exception); }
#pragma section(".CRT$XCU", read)
__declspec(allocate(".CRT$XCU")) static void (__cdecl *probe_install)(void) = install;
