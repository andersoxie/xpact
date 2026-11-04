/* Stack-walking sampler: sampler2.exe <file> <reps> <out.txt> [split]
   Each line: space-separated RVAs (relative to xpact.dll) of the stack, leaf first; frames outside the DLL are skipped. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include "xpact.h"
static char *data; static long size; static int reps, split; static volatile LONG done;
static DWORD WINAPI work(LPVOID u) {
  for (int r = 0; r < reps; r++) {
    XML_Parser p = XML_ParserCreate(NULL);
    if (split > 0) {
      for (long i = 0; i < size; i += split) {
        long n = size - i < split ? size - i : split;
        if (XML_Parse(p, data + i, (int)n, i + n >= size) != XML_STATUS_OK) { fprintf(stderr, "error\n"); exit(2); }
      }
    } else if (XML_Parse(p, data, (int)size, 1) != XML_STATUS_OK) { fprintf(stderr, "error\n"); exit(2); }
    XML_ParserFree(p);
  }
  InterlockedExchange(&done, 1);
  return 0;
}
int main(int argc, char **argv) {
  FILE *f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); size = ftell(f); fseek(f, 0, SEEK_SET);
  data = malloc(size); fread(data, 1, size, f); fclose(f);
  reps = atoi(argv[2]); split = argc > 4 ? atoi(argv[4]) : 0;
  HMODULE m = GetModuleHandleA("xpact.dll"); ULONG_PTR base = (ULONG_PTR)m;
  FILE *o = fopen(argv[3], "w");
  timeBeginPeriod(1);
  LARGE_INTEGER t0, t1, fr; QueryPerformanceFrequency(&fr); QueryPerformanceCounter(&t0);
  HANDLE th = CreateThread(NULL, 0, work, NULL, 0, NULL);
  long n = 0;
  while (!done) {
    Sleep(1);
    if (SuspendThread(th) == (DWORD)-1) break;
    CONTEXT c; c.ContextFlags = CONTEXT_FULL;
    if (GetThreadContext(th, &c)) {
      for (int d = 0; d < 64 && c.Rip; d++) {
        if (c.Rip >= base && c.Rip < base + 0x10000000) fprintf(o, "%llx ", (unsigned long long)(c.Rip - base));
        DWORD64 ib; PRUNTIME_FUNCTION fn = RtlLookupFunctionEntry(c.Rip, &ib, NULL);
        if (!fn) { c.Rip = *(DWORD64 *)c.Rsp; c.Rsp += 8; continue; }  /* leaf */
        PVOID hd; DWORD64 ef;
        RtlVirtualUnwind(UNW_FLAG_NHANDLER, ib, c.Rip, fn, &c, &hd, &ef, NULL);
      }
      fputc('\n', o); n++;
    }
    ResumeThread(th);
  }
  WaitForSingleObject(th, INFINITE); QueryPerformanceCounter(&t1);
  fclose(o);
  printf("samples %ld, %.2f ms/parse\n", n, (t1.QuadPart - t0.QuadPart) * 1000.0 / fr.QuadPart / reps);
  return 0;
}
