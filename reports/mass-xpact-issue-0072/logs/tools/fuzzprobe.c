/* fuzzprobe.exe <first> < list: parse each listed file from line <first> on, four ways (whole, 1-byte, 7-byte and
   seeded random pieces), with start/end/character-data/PI/comment handlers. Character data is concatenated, so the
   digest does not depend on how text is split into callbacks. Prints "B <n>" before each file (so a crash or hang
   can be attributed) and then one result line per way: n, way, status, code, line, column, byte index, event digest.
   Built with Expat 2.8.1 compiled in (-DUSE_EXPAT) and against xpact.dll (acceptance run, mass-xpact #67). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif

typedef struct { unsigned long long h; } digest;
static void mix(digest *d, const char *s, int n) { for (int i = 0; i < n; i++) { d->h ^= (unsigned char)s[i]; d->h *= 1099511628211ULL; } }
static void tag(digest *d, char t) { mix(d, &t, 1); }
static void XMLCALL on_start(void *u, const XML_Char *name, const XML_Char **atts) {
  digest *d = u; tag(d, 'S'); mix(d, name, (int)strlen(name));
  for (int i = 0; atts[i]; i += 2) { tag(d, 'A'); mix(d, atts[i], (int)strlen(atts[i])); tag(d, '='); mix(d, atts[i + 1], (int)strlen(atts[i + 1])); }
}
static void XMLCALL on_end(void *u, const XML_Char *name) { digest *d = u; tag(d, 'E'); mix(d, name, (int)strlen(name)); }
static void XMLCALL on_text(void *u, const XML_Char *s, int n) { digest *d = u; mix(d, s, n); }
static void XMLCALL on_pi(void *u, const XML_Char *t, const XML_Char *v) { digest *d = u; tag(d, 'P'); mix(d, t, (int)strlen(t)); tag(d, ' '); mix(d, v, (int)strlen(v)); }
static void XMLCALL on_comment(void *u, const XML_Char *s) { digest *d = u; tag(d, 'C'); mix(d, s, (int)strlen(s)); }

static void run(int n, const char *way, const char *data, long size, int mode, unsigned seed) {
  digest d = { 14695981039346656037ULL };
  XML_Parser p = XML_ParserCreate(NULL);
  XML_SetUserData(p, &d);
  XML_SetElementHandler(p, on_start, on_end);
  XML_SetCharacterDataHandler(p, on_text);
  XML_SetProcessingInstructionHandler(p, on_pi);
  XML_SetCommentHandler(p, on_comment);
  enum XML_Status st = XML_STATUS_OK;
  if (mode == 0) {
    st = XML_Parse(p, data, (int)size, 1);
  } else {
    long i = 0;
    do {
      long step = mode > 0 ? mode : 1 + (long)((seed = seed * 1103515245u + 12345u) >> 16) % 64;
      long k = size - i < step ? size - i : step;
      st = XML_Parse(p, data + i, (int)k, i + k >= size);
      i += k;
    } while (st == XML_STATUS_OK && i < size);
  }
  printf("%d\t%s\t%d\t%d\t%lu\t%lu\t%ld\t%016llx\n", n, way, (int)st, st == XML_STATUS_OK ? 0 : (int)XML_GetErrorCode(p),
         XML_GetCurrentLineNumber(p), XML_GetCurrentColumnNumber(p), XML_GetCurrentByteIndex(p), d.h);
  XML_ParserFree(p);
}

int main(int argc, char **argv) {
  int first = argc > 1 ? atoi(argv[1]) : 1; char name[4096]; int n = 0;
  while (fgets(name, sizeof name, stdin)) {
    name[strcspn(name, "\r\n")] = 0; if (!*name) continue;
    if (++n < first) continue;
    FILE *f = fopen(name, "rb"); if (!f) continue;
    fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
    char *data = malloc(size + 1); fread(data, 1, size, f); fclose(f);
    printf("B %d\n", n); fflush(stdout);
    run(n, "whole", data, size, 0, 0);
    run(n, "bytes", data, size, 1, 0);
    run(n, "seven", data, size, 7, 0);
    run(n, "random", data, size, -1, (unsigned)n * 2654435761u);
    fflush(stdout); free(data);
  }
  printf("DONE\n");
  return 0;
}
