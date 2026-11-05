/* failcall.c: feed a fixed input one byte per XML_Parse call; print the call that fails and the error position. */
#include <stdio.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif
int main(void) {
  const char doc[] = "<r>\xc3(</r>"; int n = sizeof doc - 1, call = 0;
  XML_Parser p = XML_ParserCreate(NULL);
  for (int i = 0; i <= n; i++) {
    call++;
    if (XML_Parse(p, doc + i, i < n ? 1 : 0, i == n) == XML_STATUS_ERROR) {
      printf("failed at call %d: code %d, line %lu col %lu byte %ld\n", call, XML_GetErrorCode(p),
             XML_GetCurrentLineNumber(p), XML_GetCurrentColumnNumber(p), XML_GetCurrentByteIndex(p));
      return 0;
    }
  }
  printf("no error\n"); return 0;
}
