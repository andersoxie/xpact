/* minidbg.exe <out.txt> <command line...>
   Runs the command under the Win32 debug API (this process only) and, for every access violation,
   writes the exception address and a stack (StackWalk64) as module!+rva lines. */
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <string.h>

typedef struct { DWORD64 base; DWORD size; char name[64]; } Mod;
static Mod mods[512]; static int nmods;
static HANDLE proc;

static void add_mod(HANDLE file, DWORD64 base) {
  char path[MAX_PATH] = "?";
  if (file && GetFinalPathNameByHandleA(file, path, MAX_PATH, 0) == 0) strcpy(path, "?");
  const char *n = strrchr(path, '\\'); n = n ? n + 1 : path;
  IMAGE_DOS_HEADER dos; IMAGE_NT_HEADERS64 nt; SIZE_T rd;
  DWORD size = 0;
  if (ReadProcessMemory(proc, (LPCVOID)base, &dos, sizeof dos, &rd) &&
      ReadProcessMemory(proc, (LPCVOID)(base + dos.e_lfanew), &nt, sizeof nt, &rd))
    size = nt.OptionalHeader.SizeOfImage;
  if (nmods < 512) { mods[nmods].base = base; mods[nmods].size = size; strncpy(mods[nmods].name, n, 63); nmods++; }
}
static void where(FILE *o, DWORD64 a) {
  for (int i = 0; i < nmods; i++)
    if (a >= mods[i].base && a < mods[i].base + mods[i].size) { fprintf(o, "  %s+%llx\n", mods[i].name, a - mods[i].base); return; }
  fprintf(o, "  ?%llx\n", a);
}

int main(int argc, char **argv) {
  char cmd[32768] = "";
  for (int i = 2; i < argc; i++) { strcat(cmd, "\""); strcat(cmd, argv[i]); strcat(cmd, "\" "); }
  FILE *o = fopen(argv[1], "w");
  STARTUPINFOA si = { sizeof si }; PROCESS_INFORMATION pi;
  if (!CreateProcessA(NULL, cmd, NULL, NULL, FALSE, DEBUG_ONLY_THIS_PROCESS, NULL, NULL, &si, &pi)) { printf("CreateProcess failed %lu\n", GetLastError()); return 2; }
  proc = pi.hProcess;
  SymInitialize(proc, NULL, FALSE);
  HANDLE threads[4096]; DWORD tids[4096]; int nth = 0;
  DEBUG_EVENT ev; int av = 0; DWORD exit_code = 0;
  for (;;) {
    if (!WaitForDebugEvent(&ev, INFINITE)) break;
    DWORD cont = DBG_CONTINUE;
    switch (ev.dwDebugEventCode) {
    case CREATE_PROCESS_DEBUG_EVENT:
      add_mod(ev.u.CreateProcessInfo.hFile, (DWORD64)ev.u.CreateProcessInfo.lpBaseOfImage);
      SymLoadModuleEx(proc, ev.u.CreateProcessInfo.hFile, NULL, NULL, (DWORD64)ev.u.CreateProcessInfo.lpBaseOfImage, 0, NULL, 0);
      threads[nth] = ev.u.CreateProcessInfo.hThread; tids[nth++] = ev.dwThreadId; break;
    case CREATE_THREAD_DEBUG_EVENT:
      if (nth < 4096) { threads[nth] = ev.u.CreateThread.hThread; tids[nth++] = ev.dwThreadId; } break;
    case LOAD_DLL_DEBUG_EVENT:
      add_mod(ev.u.LoadDll.hFile, (DWORD64)ev.u.LoadDll.lpBaseOfDll);
      SymLoadModuleEx(proc, ev.u.LoadDll.hFile, NULL, NULL, (DWORD64)ev.u.LoadDll.lpBaseOfDll, 0, NULL, 0);
      break;
    case EXCEPTION_DEBUG_EVENT: {
      EXCEPTION_RECORD *er = &ev.u.Exception.ExceptionRecord;
      if (er->ExceptionCode == EXCEPTION_BREAKPOINT) break;
      cont = DBG_EXCEPTION_NOT_HANDLED;
      if (er->ExceptionCode != EXCEPTION_ACCESS_VIOLATION) break;
      av++;
      fprintf(o, "AV %d first_chance=%lu at", av, ev.u.Exception.dwFirstChance); where(o, (DWORD64)er->ExceptionAddress);
      fprintf(o, " %s address %llx\n", er->ExceptionInformation[0] ? "write" : "read", (unsigned long long)er->ExceptionInformation[1]);
      HANDLE th = NULL;
      for (int i = 0; i < nth; i++) if (tids[i] == ev.dwThreadId) th = threads[i];
      CONTEXT c; c.ContextFlags = CONTEXT_FULL;
      if (th && GetThreadContext(th, &c)) {
        fprintf(o, " rax=%llx rbx=%llx rcx=%llx rdx=%llx rsi=%llx rdi=%llx r8=%llx r9=%llx\n", c.Rax, c.Rbx, c.Rcx, c.Rdx, c.Rsi, c.Rdi, c.R8, c.R9);
        STACKFRAME64 f = {0};
        f.AddrPC.Offset = c.Rip; f.AddrPC.Mode = AddrModeFlat;
        f.AddrFrame.Offset = c.Rbp; f.AddrFrame.Mode = AddrModeFlat;
        f.AddrStack.Offset = c.Rsp; f.AddrStack.Mode = AddrModeFlat;
        for (int d = 0; d < 40; d++) {
          if (!StackWalk64(IMAGE_FILE_MACHINE_AMD64, proc, th, &f, &c, NULL, SymFunctionTableAccess64, SymGetModuleBase64, NULL)) break;
          if (!f.AddrPC.Offset) break;
          where(o, f.AddrPC.Offset);
        }
      }
      fflush(o);
      break; }
    case EXIT_PROCESS_DEBUG_EVENT:
      exit_code = ev.u.ExitProcess.dwExitCode;
      ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, DBG_CONTINUE);
      fprintf(o, "exit %lx\n", exit_code); fclose(o);
      printf("exit %lx, %d access violations\n", exit_code, av);
      return 0;
    }
    ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, cont);
  }
  return 1;
}
