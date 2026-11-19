/* bisect.c <threads> <rounds> <dtd 0/1> <handler 0/1>: which feature makes the MT DLL crash (#304)?
 * dtd=1 parses the threads.c document (internal DTD + entity), dtd=0 a plain document.
 * warm=N (5th argument) parses N times on the main thread first (fills the runtime caches).
 * handler=1 sets user data and a start-element handler, as threads.c does. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "xpact.h"

static const char doc_dtd[] = "<?xml version='1.0'?><!DOCTYPE r [<!ENTITY e 'text'>]><r a='1'><c>&e;</c><c>x &amp; y</c><c/></r>";
static const char doc_plain[] = "<?xml version='1.0'?><r a='1'><c>text</c><c>x &amp; y</c><c/></r>";
static int rounds, use_dtd, use_handler, warm;
static volatile LONG good, bad;

static void XMLCALL on_start(void *u, const XML_Char *n, const XML_Char **a) { (void)n; (void)a; ++*(int *)u; }

static DWORD WINAPI work(LPVOID arg) {
  const char *doc = use_dtd ? doc_dtd : doc_plain;
  (void)arg;
  for (int k = 0; k < rounds; k++) {
    int elements = 0;
    XML_Parser p = XML_ParserCreate(NULL);
    if (use_handler) { XML_SetUserData(p, &elements); XML_SetStartElementHandler(p, on_start); }
    int ok = XML_Parse(p, doc, (int)strlen(doc), 1) == XML_STATUS_OK;
    XML_ParserFree(p);
    if (ok && (!use_handler || elements == 4)) InterlockedIncrement(&good); else InterlockedIncrement(&bad);
  }
  return 0;
}

int main(int argc, char **argv) {
  int n = argc > 1 ? atoi(argv[1]) : 4;
  rounds = argc > 2 ? atoi(argv[2]) : 1000;
  use_dtd = argc > 3 ? atoi(argv[3]) : 1;
  use_handler = argc > 4 ? atoi(argv[4]) : 1;
  warm = argc > 5 ? atoi(argv[5]) : 0;
  if (warm) { int r = rounds; rounds = warm; work(NULL); rounds = r; good = 0; bad = 0; } /* warm-up parses on the main thread */
  HANDLE t[64];
  for (int i = 0; i < n && i < 64; i++) t[i] = CreateThread(NULL, 0, work, NULL, 0, NULL);
  WaitForMultipleObjects(n, t, TRUE, INFINITE);
  printf("threads %d dtd %d handler %d: good %ld bad %ld\n", n, use_dtd, use_handler, good, bad);
  return bad != 0;
}
