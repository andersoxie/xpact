/* steps.c <dll> <step>: find which step of a multi-threaded xpact DLL fails (#304 trial).
 *   1 = load the DLL   2 = + parse on the main thread   3 = + parse on a second thread
 *   4 = + parse on two threads at the same time
 * Prints "step N ok" after each step that passes. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include "expat.h"

typedef XML_Parser (XMLCALL *create_fn)(const XML_Char *);
typedef enum XML_Status (XMLCALL *parse_fn)(XML_Parser, const char *, int, int);
typedef void (XMLCALL *free_fn)(XML_Parser);
static create_fn p_create; static parse_fn p_parse; static free_fn p_free;
static int trace = 1;
static const char doc[] = "<root a='1'><x>text</x><y/></root>";

static int parse_once(void) {
  XML_Parser p; int ok;
  if (trace) { fprintf(stderr, "  create"); fflush(stderr); }
  p = p_create(NULL);
  if (trace) { fprintf(stderr, " -> %p parse", (void *)p); fflush(stderr); }
  ok = p && p_parse(p, doc, (int)sizeof doc - 1, 1) == XML_STATUS_OK;
  if (trace) { fprintf(stderr, " -> %d free", ok); fflush(stderr); }
  if (p) p_free(p);
  if (trace) { fprintf(stderr, " -> done\n"); fflush(stderr); trace = 0; }
  return ok;
}

static DWORD WINAPI worker(LPVOID arg) {
  int i, n = (int)(INT_PTR)arg, ok = 1;
  for (i = 0; i < n; i++) ok &= parse_once();
  return ok ? 0 : 1;
}

int main(int argc, char **argv) {
  int step = argc > 2 ? atoi(argv[2]) : 4;
  HMODULE m = LoadLibraryA(argc > 1 ? argv[1] : "xpact_mt.dll");
  if (!m) { printf("load failed %lu\n", GetLastError()); return 2; }
  p_create = (create_fn)GetProcAddress(m, "XML_ParserCreate");
  p_parse = (parse_fn)GetProcAddress(m, "XML_Parse");
  p_free = (free_fn)GetProcAddress(m, "XML_ParserFree");
  printf("step 1 ok\n"); fflush(stdout);
  if (step < 2) return 0;
  if (!parse_once()) { printf("step 2 wrong result\n"); return 1; }
  printf("step 2 ok\n"); fflush(stdout);
  if (step < 3) return 0;
  {
    HANDLE t = CreateThread(NULL, 0, worker, (LPVOID)(INT_PTR)100, 0, NULL);
    DWORD code; WaitForSingleObject(t, INFINITE); GetExitCodeThread(t, &code);
    if (code) { printf("step 3 wrong result\n"); return 1; }
  }
  printf("step 3 ok\n"); fflush(stdout);
  if (step < 4) return 0;
  {
    HANDLE t[2]; DWORD c0, c1;
    t[0] = CreateThread(NULL, 0, worker, (LPVOID)(INT_PTR)2000, 0, NULL);
    t[1] = CreateThread(NULL, 0, worker, (LPVOID)(INT_PTR)2000, 0, NULL);
    WaitForMultipleObjects(2, t, TRUE, INFINITE);
    GetExitCodeThread(t[0], &c0); GetExitCodeThread(t[1], &c1);
    if (c0 || c1) { printf("step 4 wrong result\n"); return 1; }
  }
  printf("step 4 ok\n");
  return 0;
}
