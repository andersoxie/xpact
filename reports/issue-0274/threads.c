/* threads.c <threads> <rounds>: each thread creates its own parser, parses the same document <rounds> times and
   checks the result (status and element count) every time; prints how many parses gave the expected result.
   With <threads> = 1 this is the single-thread control. Built with Expat 2.8.1 compiled in (-DUSE_EXPAT) and
   against xpact.dll (acceptance run, mass-xpact #67). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif

static const char doc[] = "<?xml version='1.0'?><!DOCTYPE r [<!ENTITY e 'text'>]><r a='1'><c>&e;</c><c>x &amp; y</c><c/></r>";
static int rounds;
static volatile LONG good, bad;

static void XMLCALL on_start(void *u, const XML_Char *n, const XML_Char **a) { (void)n; (void)a; ++*(int *)u; }

static DWORD WINAPI work(LPVOID arg) {
  (void)arg;
  for (int k = 0; k < rounds; k++) {
    int elements = 0;
    XML_Parser p = XML_ParserCreate(NULL);
    XML_SetUserData(p, &elements);
    XML_SetStartElementHandler(p, on_start);
    int ok = XML_Parse(p, doc, (int)strlen(doc), 1) == XML_STATUS_OK;
    XML_ParserFree(p);
    if (ok && elements == 4) InterlockedIncrement(&good); else InterlockedIncrement(&bad);
  }
  return 0;
}

int main(int argc, char **argv) {
  int n = argc > 1 ? atoi(argv[1]) : 4; rounds = argc > 2 ? atoi(argv[2]) : 1000;
  HANDLE t[64];
  for (int i = 0; i < n && i < 64; i++) t[i] = CreateThread(NULL, 0, work, NULL, 0, NULL);
  WaitForMultipleObjects(n, t, TRUE, INFINITE);
  printf("threads %d, parses %d: expected result %ld, wrong %ld\n", n, n * rounds, good, bad);
  return bad != 0;
}
