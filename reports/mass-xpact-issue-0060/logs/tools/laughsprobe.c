/* laughsprobe.exe [-m factor] [-t threshold] <file>...: for each file, XML_ParserCreate(NULL), the optional
   billion-laughs settings, and one final XML_Parse with no handlers; prints status, error code, error string
   and milliseconds (mass-xpact #60, from andersoxie#211). Built with Expat 2.8.1 compiled in (-DUSE_EXPAT)
   and against xpact.dll. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif
int main(int argc, char **argv) {
  LARGE_INTEGER fr, t0, t1; QueryPerformanceFrequency(&fr);
  float factor = 0; unsigned long long threshold = 0; int has_factor = 0, has_threshold = 0;
  for (int k = 1; k < argc; k++) {
    if (strcmp(argv[k], "-m") == 0 && k + 1 < argc) { factor = (float)atof(argv[++k]); has_factor = 1; continue; }
    if (strcmp(argv[k], "-t") == 0 && k + 1 < argc) { threshold = strtoull(argv[++k], NULL, 10); has_threshold = 1; continue; }
    FILE *f = fopen(argv[k], "rb"); fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
    char *data = malloc(size); fread(data, 1, size, f); fclose(f);
    QueryPerformanceCounter(&t0);
    XML_Parser p = XML_ParserCreate(NULL);
    if (has_factor) XML_SetBillionLaughsAttackProtectionMaximumAmplification(p, factor);
    if (has_threshold) XML_SetBillionLaughsAttackProtectionActivationThreshold(p, threshold);
    enum XML_Status st = XML_Parse(p, data, (int)size, 1);
    enum XML_Error e = XML_GetErrorCode(p);
    QueryPerformanceCounter(&t1);
    const char *n = strrchr(argv[k], '\\'); n = n ? n + 1 : argv[k];
    printf("%s\t%ld bytes\t%s\tcode %d\t%s\t%.1f ms\n", n, size, st == XML_STATUS_OK ? "accepted" : "rejected", (int)e,
           st == XML_STATUS_OK ? "-" : (const char *)XML_ErrorString(e), (t1.QuadPart - t0.QuadPart) * 1000.0 / fr.QuadPart);
    XML_ParserFree(p); free(data);
  }
  return 0;
}
