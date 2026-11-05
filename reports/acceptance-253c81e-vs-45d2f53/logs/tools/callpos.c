/* callpos.exe <chunk> < list: for each listed file, parse with NO handlers in <chunk>-byte pieces and print one
   line per XML_Parse call: file index, call number, status, line, column, byte index (acceptance run, #67). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif
int main(int argc, char **argv) {
  int chunk = atoi(argv[1]); char name[4096]; int k = 0;
  while (fgets(name, sizeof name, stdin)) {
    name[strcspn(name, "\r\n")] = 0; if (!*name) continue;
    FILE *f = fopen(name, "rb"); if (!f) continue;
    fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
    char *data = malloc(size + 1); fread(data, 1, size, f); fclose(f); k++;
    XML_Parser p = XML_ParserCreate(NULL); int call = 0;
    long step = chunk > 0 ? chunk : (size > 0 ? size : 1);
    for (long i = 0; i < size || i == 0; i += step) {
      long n = size - i < step ? size - i : step;
      enum XML_Status st = XML_Parse(p, data + i, (int)n, i + n >= size);
      printf("%d\t%d\t%d\t%lu\t%lu\t%ld\n", k, ++call, (int)st, XML_GetCurrentLineNumber(p), XML_GetCurrentColumnNumber(p), XML_GetCurrentByteIndex(p));
      if (st == XML_STATUS_ERROR) break;
    }
    XML_ParserFree(p); free(data);
  }
  return 0;
}
