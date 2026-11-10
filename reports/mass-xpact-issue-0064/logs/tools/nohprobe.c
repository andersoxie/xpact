/* nohprobe.exe <chunk> < list: parse each listed file with NO handlers in <chunk>-byte pieces and print, per file,
   the final status, error code and XML_GetCurrentLineNumber / ColumnNumber / ByteIndex, plus the position after
   every call folded into a checksum (mass-xpact #53). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif
int main(int argc, char **argv) {
  int chunk = atoi(argv[1]); char name[4096];
  while (fgets(name, sizeof name, stdin)) {
    name[strcspn(name, "\r\n")] = 0; if (!*name) continue;
    FILE *f = fopen(name, "rb"); if (!f) continue;
    fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
    char *data = malloc(size + 1); fread(data, 1, size, f); fclose(f);
    XML_Parser p = XML_ParserCreate(NULL); enum XML_Status st = XML_STATUS_OK; unsigned long sum = 0;
    long step = chunk > 0 ? chunk : (size > 0 ? size : 1);
    for (long i = 0; i < size || i == 0; i += step) {
      long n = size - i < step ? size - i : step;
      st = XML_Parse(p, data + i, (int)n, i + n >= size);
      sum = sum * 31 + (unsigned long)XML_GetCurrentLineNumber(p) * 7 + (unsigned long)XML_GetCurrentColumnNumber(p) * 3 + (unsigned long)XML_GetCurrentByteIndex(p);
      if (st != XML_STATUS_OK || i + n >= size) break;
    }
    printf("%s\t%d\t%d\t%lu\t%lu\t%ld\t%lu\n", name, (int)st, (int)XML_GetErrorCode(p), (unsigned long)XML_GetCurrentLineNumber(p),
           (unsigned long)XML_GetCurrentColumnNumber(p), (long)XML_GetCurrentByteIndex(p), sum);
    XML_ParserFree(p); free(data);
  }
  return 0;
}
