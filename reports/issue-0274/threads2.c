/* threads2.c <threads> <rounds>: like threads.c, but each document is fed in 7-byte pieces and the
   handlers call back into xpact (XML_GetCurrentLineNumber, XML_GetCurrentByteIndex) on the same thread,
   which must not deadlock with the call lock (#274). Prints how many parses gave the expected result. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include "xpact.h"

static const char doc[] = "<?xml version='1.0'?>\n<!DOCTYPE r [<!ENTITY e 'text'>]>\n<r a='1'>\n<c>&e;</c>\n<c>x &amp; y</c>\n<c/>\n</r>";
static int rounds;
static volatile LONG good, bad;

typedef struct { XML_Parser p; int elements; long lines; long text; } State;

static void XMLCALL on_start(void *u, const XML_Char *n, const XML_Char **a) {
  State *s = (State *)u; (void)n; (void)a;
  s->elements++;
  s->lines += (long)XML_GetCurrentLineNumber(s->p);   /* re-entrant call from inside a handler */
  if (XML_GetCurrentByteIndex(s->p) < 0) s->elements = -1000;
}
static void XMLCALL on_text(void *u, const XML_Char *t, int len) { (void)t; ((State *)u)->text += len; }

static DWORD WINAPI work(LPVOID arg) {
  (void)arg;
  int n = (int)strlen(doc);
  for (int k = 0; k < rounds; k++) {
    State s = {0};
    s.p = XML_ParserCreate(NULL);
    XML_SetUserData(s.p, &s);
    XML_SetStartElementHandler(s.p, on_start);
    XML_SetCharacterDataHandler(s.p, on_text);
    int ok = 1;
    for (int i = 0; i < n && ok; i += 7) {
      int len = n - i < 7 ? n - i : 7;
      ok = XML_Parse(s.p, doc + i, len, i + len >= n) == XML_STATUS_OK;
    }
    XML_ParserFree(s.p);
    /* 4 elements on lines 3, 4, 5, 6 */
    if (ok && s.elements == 4 && s.lines == 18 && s.text > 0) InterlockedIncrement(&good); else InterlockedIncrement(&bad);
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
