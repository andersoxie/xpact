/* posprobe.exe <file> <chunk>: feed <file> in <chunk>-byte pieces with NO handlers and print, after every
   XML_Parse call, the status and XML_GetCurrentLineNumber / ColumnNumber / ByteIndex (mass-xpact #53).
   Built twice: with Expat 2.8.1 compiled in (-DUSE_EXPAT) and against xpact.dll. */
#include <stdio.h>
#include <stdlib.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif
int main(int argc, char **argv) {
  FILE *f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
  char *data = malloc(size); fread(data, 1, size, f); fclose(f);
  int chunk = atoi(argv[2]);
  XML_Parser p = XML_ParserCreate(NULL);
  for (long i = 0; i < size; i += chunk) {
    long n = size - i < chunk ? size - i : chunk;
    int final = i + n >= size;
    enum XML_Status st = XML_Parse(p, data + i, (int)n, final);
    printf("%ld\t%d\t%lu\t%lu\t%ld\n", i + n, (int)st, (unsigned long)XML_GetCurrentLineNumber(p),
           (unsigned long)XML_GetCurrentColumnNumber(p), (long)XML_GetCurrentByteIndex(p));
    if (st == XML_STATUS_ERROR) { printf("error %d\n", (int)XML_GetErrorCode(p)); break; }
  }
  XML_ParserFree(p);
  return 0;
}
